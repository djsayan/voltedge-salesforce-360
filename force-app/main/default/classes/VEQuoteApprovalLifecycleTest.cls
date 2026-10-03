@IsTest
private class VEQuoteApprovalLifecycleTest {

    @TestSetup
    static void setupUsers() {
    Id profileId = UserInfo.getProfileId();
    String stamp = String.valueOf(System.now().getTime());

    User director = new User(
        FirstName = 'VE',
        LastName = 'Commercial Director',
        Alias = 'vedir',
        Email = 'director@test.example',
        Username = 've.lifecycle.director.' + stamp + '@example.com',
        ProfileId = profileId,
        TimeZoneSidKey = 'Europe/Warsaw',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert director;

    User manager = new User(
        FirstName = 'VE',
        LastName = 'Sales Manager',
        Alias = 'vemgr',
        Email = 'manager@test.example',
        Username = 've.lifecycle.manager.' + stamp + '@example.com',
        ProfileId = profileId,
        ManagerId = director.Id,
        TimeZoneSidKey = 'Europe/Warsaw',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert manager;

    User salesRep = new User(
        FirstName = 'VE',
        LastName = 'Sales Rep',
        Alias = 'vesales',
        Email = 'sales@test.example',
        Username = 've.lifecycle.sales.' + stamp + '@example.com',
        ProfileId = profileId,
        ManagerId = manager.Id,
        TimeZoneSidKey = 'Europe/Warsaw',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert salesRep;

User noManagerSalesRep = new User(
    FirstName = 'VE',
    LastName = 'Sales No Manager',
    Alias = 'venomgr',
    Email = 'nomgr@test.example',
    Username = 've.lifecycle.nomgr.' + stamp + '@example.com',
    ProfileId = profileId,
    TimeZoneSidKey = 'Europe/Warsaw',
    LocaleSidKey = 'en_US',
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US'
);
insert noManagerSalesRep;

    User inactiveManager = new User(
        FirstName = 'VE',
        LastName = 'Inactive Manager',
        Alias = 'veimgr',
        Email = 'inactive.manager@test.example',
        Username = 've.lifecycle.inactive.manager.' + stamp + '@example.com',
        ProfileId = profileId,
        ManagerId = director.Id,
        TimeZoneSidKey = 'Europe/Warsaw',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert inactiveManager;

    User inactiveManagerSalesRep = new User(
        FirstName = 'VE',
        LastName = 'Sales Inactive Manager',
        Alias = 'veisales',
        Email = 'inactive.sales@test.example',
        Username = 've.lifecycle.inactive.sales.' + stamp + '@example.com',
        ProfileId = profileId,
        ManagerId = inactiveManager.Id,
        TimeZoneSidKey = 'Europe/Warsaw',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert inactiveManagerSalesRep;

    Id salesPermissionSetId = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'VE_Sales_User'
    WITH SYSTEM_MODE
    LIMIT 1
].Id;

Id approverPermissionSetId = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'VE_Commercial_Approver'
    WITH SYSTEM_MODE
    LIMIT 1
].Id;

insert as system new List<PermissionSetAssignment>{
    new PermissionSetAssignment(
        AssigneeId = salesRep.Id,
        PermissionSetId = salesPermissionSetId
    ),
    new PermissionSetAssignment(
        AssigneeId = noManagerSalesRep.Id,
        PermissionSetId = salesPermissionSetId
    ),
    new PermissionSetAssignment(
        AssigneeId = inactiveManagerSalesRep.Id,
        PermissionSetId = salesPermissionSetId
    ),
    new PermissionSetAssignment(
        AssigneeId = manager.Id,
        PermissionSetId = approverPermissionSetId
    ),
    new PermissionSetAssignment(
        AssigneeId = director.Id,
        PermissionSetId = approverPermissionSetId
    )
};

    update new User(
        Id = inactiveManager.Id,
        IsActive = false
    );
}

    @IsTest
    static void shouldApproveInvalidateAndResubmit() {

        User salesRep = [
            SELECT Id, ManagerId
            FROM User
            WHERE Alias = 'vesales'
            LIMIT 1
        ];

        User manager = [
            SELECT Id
            FROM User
            WHERE Alias = 'vemgr'
            LIMIT 1
        ];

        Id quoteId;
        Id quoteLineId;

        // ========================================
        // CREATE REAL COMMERCIAL DATA
        // ========================================

        System.runAs(salesRep) {

            Product2 product = new Product2(
                Name = 'Approval Lifecycle Product',
                ProductCode = 'TEST-APPROVAL-LIFECYCLE',
                IsActive = true,
                Revenue_Type__c = 'One-Time'
            );
            insert as system product;

            Id pricebookId =
                Test.getStandardPricebookId();

            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = pricebookId,
                Product2Id = product.Id,
                UnitPrice = 1000,
                CurrencyIsoCode = 'PLN',
                IsActive = true
            );
            insert as system pbe;

            Account accountRecord = new Account(
                Name = 'Approval Lifecycle Account'
            );
            insert accountRecord;

            Opportunity opportunity = new Opportunity(
                Name = 'Approval Lifecycle Opportunity',
                AccountId = accountRecord.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = pricebookId,
                CurrencyIsoCode = 'PLN'
            );
            insert opportunity;

            Quote quoteRecord = new Quote(
                Name = 'Approval Lifecycle Quote',
                OpportunityId = opportunity.Id,
                Pricebook2Id = pricebookId,
                ExpirationDate = Date.today().addDays(30),
                CurrencyIsoCode = 'PLN'
            );
            insert quoteRecord;

            // 15% effective discount -> Sales Manager
            QuoteLineItem line = new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 850,
                Discount = 0,
                Discount_Reason__c = 'Other'
            );
            insert line;

            quoteId = quoteRecord.Id;
            quoteLineId = line.Id;

            Quote routed = [
                SELECT
                    Status,
                    Approval_Status__c,
                    Approval_Required__c,
                    Maximum_Line_Discount__c,
                    Discount_Approver__c,
                    Commercial_Revision__c
                FROM Quote
                WHERE Id = :quoteId
                WITH SYSTEM_MODE
            ];

            System.assertEquals(
                15,
                routed.Maximum_Line_Discount__c
            );

            System.assertEquals(
                true,
                routed.Approval_Required__c
            );

            System.assertEquals(
                'Required',
                routed.Approval_Status__c
            );

            System.assertEquals(
                manager.Id,
                routed.Discount_Approver__c
            );

            // Entry criteria require Needs Review.
            update new Quote(
                Id = quoteId,
                Status = 'Needs Review',
                Discount_Justification__c =
                    'Lifecycle automated test'
            );

            // ========================================
            // REAL SUBMIT FOR APPROVAL
            // ========================================

            Approval.ProcessSubmitRequest submitRequest =
                new Approval.ProcessSubmitRequest();

            submitRequest.setObjectId(quoteId);
            submitRequest.setProcessDefinitionNameOrId(
                'VE_Quote_Discount_Approval'
            );
            submitRequest.setComments(
                'Automated lifecycle submission'
            );

            Approval.ProcessResult submitResult =
                Approval.process(submitRequest);

            System.assert(
                submitResult.isSuccess(),
                'Quote submission must succeed.'
            );
        }

        Quote pending = [
            SELECT
                Status,
                Approval_Status__c,
                Discount_Approver__c,
                Commercial_Revision__c
            FROM Quote
            WHERE Id = :quoteId
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            'In Review',
            pending.Status
        );

        System.assertEquals(
            'Pending',
            pending.Approval_Status__c
        );

        Decimal revisionBeforeApproval =
            pending.Commercial_Revision__c;

        // ========================================
        // VERIFY ROUTING TO REAL MANAGER
        // ========================================

        ProcessInstanceWorkitem workItem = [
            SELECT
                Id,
                ActorId,
                ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :quoteId
            LIMIT 1
        ];

        System.assertEquals(
            manager.Id,
            workItem.ActorId,
            '15% discount must route to Sales Manager.'
        );

        // ========================================
        // REAL APPROVAL
        // ========================================

        System.runAs(manager) {

            Approval.ProcessWorkitemRequest approvalRequest =
                new Approval.ProcessWorkitemRequest();

            approvalRequest.setWorkitemId(workItem.Id);
            approvalRequest.setAction('Approve');
            approvalRequest.setComments(
                'Automated manager approval'
            );

            Approval.ProcessResult approvalResult =
                Approval.process(approvalRequest);

            System.assert(
                approvalResult.isSuccess(),
                'Manager approval must succeed.'
            );
        }

        Quote approved = [
            SELECT
                Status,
                Approval_Status__c,
                Commercial_Revision__c
            FROM Quote
            WHERE Id = :quoteId
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            'Approved',
            approved.Status
        );

        System.assertEquals(
            'Approved',
            approved.Approval_Status__c
        );

        // ========================================
        // COMMERCIAL CHANGE AFTER APPROVAL
        // ========================================

        System.runAs(salesRep) {
            update new QuoteLineItem(
                Id = quoteLineId,
                UnitPrice = 800
            );
        }

        Quote reopened = [
            SELECT
                Status,
                Approval_Status__c,
                Maximum_Line_Discount__c,
                Commercial_Revision__c,
                Discount_Approver__c
            FROM Quote
            WHERE Id = :quoteId
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            'Draft',
            reopened.Status,
            'Commercial edit must reopen approved Quote.'
        );

        System.assertEquals(
            'Required',
            reopened.Approval_Status__c
        );

        System.assertEquals(
            20,
            reopened.Maximum_Line_Discount__c
        );

        System.assertEquals(
            revisionBeforeApproval + 1,
            reopened.Commercial_Revision__c
        );

        // ========================================
        // RESUBMIT
        // ========================================

        System.runAs(salesRep) {

            update new Quote(
                Id = quoteId,
                Status = 'Needs Review',
                Discount_Justification__c =
                    'Reapproval after commercial change'
            );

            Approval.ProcessSubmitRequest resubmitRequest =
                new Approval.ProcessSubmitRequest();

            resubmitRequest.setObjectId(quoteId);
            resubmitRequest.setProcessDefinitionNameOrId(
                'VE_Quote_Discount_Approval'
            );

            Approval.ProcessResult resubmitResult =
                Approval.process(resubmitRequest);

            System.assert(
                resubmitResult.isSuccess(),
                'Re-submission after commercial change must succeed.'
            );
        }

        Quote resubmitted = [
            SELECT
                Status,
                Approval_Status__c
            FROM Quote
            WHERE Id = :quoteId
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            'In Review',
            resubmitted.Status
        );

        System.assertEquals(
            'Pending',
            resubmitted.Approval_Status__c
        );
    }
    private static User getLifecycleUser(String aliasValue) {
    return [
        SELECT Id, ManagerId, IsActive
        FROM User
        WHERE Alias = :aliasValue
        LIMIT 1
    ];
}

private static Quote createRoutedQuote(
    Decimal salesPrice,
    String suffix
) {
    Product2 product = new Product2(
        Name = 'Lifecycle Product ' + suffix,
        ProductCode = 'TEST-LIFECYCLE-' + suffix,
        IsActive = true,
        Revenue_Type__c = 'One-Time'
    );
    insert as system product;

    Id pricebookId =
        Test.getStandardPricebookId();

    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = pricebookId,
        Product2Id = product.Id,
        UnitPrice = 1000,
        CurrencyIsoCode = 'PLN',
        IsActive = true
    );
    insert as system pbe;

    Account accountRecord = new Account(
        Name = 'Lifecycle Account ' + suffix
    );
    insert accountRecord;

    Opportunity opportunity = new Opportunity(
        Name = 'Lifecycle Opportunity ' + suffix,
        AccountId = accountRecord.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Pricebook2Id = pricebookId,
        CurrencyIsoCode = 'PLN'
    );
    insert opportunity;

    Quote quoteRecord = new Quote(
        Name = 'Lifecycle Quote ' + suffix,
        OpportunityId = opportunity.Id,
        Pricebook2Id = pricebookId,
        ExpirationDate = Date.today().addDays(30),
        CurrencyIsoCode = 'PLN'
    );
    insert quoteRecord;

    insert new QuoteLineItem(
        QuoteId = quoteRecord.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = salesPrice,
        Discount = 0,
        Discount_Reason__c = 'Other'
    );

    return [
        SELECT
            Id,
            Status,
            Approval_Status__c,
            Approval_Required__c,
            Maximum_Line_Discount__c,
            Discount_Approver__c
        FROM Quote
        WHERE Id = :quoteRecord.Id
        WITH SYSTEM_MODE
    ];
}


private static Quote createApprovalReadyQuote(
    Decimal salesPrice,
    String suffix
) {
    Quote quoteRecord =
        createRoutedQuote(salesPrice, suffix);

    update new Quote(
        Id = quoteRecord.Id,
        Status = 'Needs Review',
        Discount_Justification__c =
            'Automated lifecycle test ' + suffix
    );

    return [
        SELECT
            Id,
            Status,
            Approval_Status__c,
            Approval_Required__c,
            Maximum_Line_Discount__c,
            Discount_Approver__c
        FROM Quote
        WHERE Id = :quoteRecord.Id
        WITH SYSTEM_MODE
    ];
}

    private static Approval.ProcessResult submitQuote(Id quoteId) {
        Approval.ProcessSubmitRequest request =
            new Approval.ProcessSubmitRequest();

        request.setObjectId(quoteId);
        request.setProcessDefinitionNameOrId(
            'VE_Quote_Discount_Approval'
        );
        request.setComments('Automated lifecycle test');

        return Approval.process(request);
    }

    private static ProcessInstanceWorkitem getWorkItem(Id quoteId) {
        return [
            SELECT
                Id,
                ActorId,
                ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :quoteId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }
    @IsTest
static void shouldRejectQuote() {
    User salesRep = getLifecycleUser('vesales');
    User manager = getLifecycleUser('vemgr');

    Id quoteId;

    System.runAs(salesRep) {
        Quote quoteRecord =
            createApprovalReadyQuote(850, 'REJECT');

        quoteId = quoteRecord.Id;

        Approval.ProcessResult submitResult =
            submitQuote(quoteId);

        System.assert(
            submitResult.isSuccess(),
            'Submission must succeed.'
        );
    }

    ProcessInstanceWorkitem workItem =
        getWorkItem(quoteId);

    System.assertEquals(
        manager.Id,
        workItem.ActorId
    );

    System.runAs(manager) {
        Approval.ProcessWorkitemRequest request =
            new Approval.ProcessWorkitemRequest();

        request.setWorkitemId(workItem.Id);
        request.setAction('Reject');
        request.setComments('Rejected by automated test');

        Approval.ProcessResult result =
            Approval.process(request);

        System.assert(
            result.isSuccess(),
            'Rejection must succeed.'
        );
    }

    Quote rejected = [
        SELECT Status, Approval_Status__c
        FROM Quote
        WHERE Id = :quoteId
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Rejected',
        rejected.Status
    );

    System.assertEquals(
        'Rejected',
        rejected.Approval_Status__c
    );
}
    @IsTest
    static void shouldRecallQuote() {
    User salesRep = getLifecycleUser('vesales');

    Id quoteId;

    System.runAs(salesRep) {
        Quote quoteRecord =
            createApprovalReadyQuote(850, 'RECALL');

        quoteId = quoteRecord.Id;

        Approval.ProcessResult submitResult =
            submitQuote(quoteId);

        System.assert(
            submitResult.isSuccess(),
            'Submission must succeed.'
        );
    }

    ProcessInstanceWorkitem workItem =
        getWorkItem(quoteId);

    System.runAs(salesRep) {
        Approval.ProcessWorkitemRequest request =
            new Approval.ProcessWorkitemRequest();

        request.setWorkitemId(workItem.Id);
        request.setAction('Removed');
        request.setComments(
            'Recalled by automated test'
        );

        Approval.ProcessResult result =
            Approval.process(request);

        System.assert(
            result.isSuccess(),
            'Recall must succeed.'
        );
    }

    Quote recalled = [
        SELECT Status, Approval_Status__c
        FROM Quote
        WHERE Id = :quoteId
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Needs Review',
        recalled.Status
    );

    System.assertEquals(
        'Required',
        recalled.Approval_Status__c
    );
}
@IsTest
static void shouldRouteTwentyFivePercentToCommercialDirector() {
    User salesRep = getLifecycleUser('vesales');
    User director = getLifecycleUser('vedir');

    Id quoteId;

    System.runAs(salesRep) {
        // List = 1000
        // Sales Price = 750
        // Effective Discount = 25%
        Quote quoteRecord =
            createApprovalReadyQuote(750, 'DIRECTOR');

        quoteId = quoteRecord.Id;

        System.assertEquals(
            25,
            quoteRecord.Maximum_Line_Discount__c
        );

        System.assertEquals(
            director.Id,
            quoteRecord.Discount_Approver__c,
            '25% must route to Commercial Director.'
        );

        Approval.ProcessResult submitResult =
            submitQuote(quoteId);

        System.assert(
            submitResult.isSuccess(),
            'Submission must succeed.'
        );
    }

    ProcessInstanceWorkitem workItem =
        getWorkItem(quoteId);

    System.assertEquals(
        director.Id,
        workItem.ActorId,
        'Approval work item must belong to Commercial Director.'
    );

    System.runAs(director) {
        Approval.ProcessWorkitemRequest request =
            new Approval.ProcessWorkitemRequest();

        request.setWorkitemId(workItem.Id);
        request.setAction('Approve');
        request.setComments(
            'Commercial Director approval'
        );

        Approval.ProcessResult result =
            Approval.process(request);

        System.assert(
            result.isSuccess(),
            'Director approval must succeed.'
        );
    }

    Quote approved = [
        SELECT Status, Approval_Status__c
        FROM Quote
        WHERE Id = :quoteId
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Approved',
        approved.Status
    );

    System.assertEquals(
        'Approved',
        approved.Approval_Status__c
    );
}
@IsTest
static void shouldRouteExactDiscountBoundariesCorrectly() {
    User salesRep = getLifecycleUser('vesales');
    User manager = getLifecycleUser('vemgr');
    User director = getLifecycleUser('vedir');

    Id quote10Id;
    Id quote20Id;
    Id quote30Id;

    System.runAs(salesRep) {

        // 10% - no approval
        Quote quote10 =
            createApprovalReadyQuote(900, 'BOUNDARY10');

        quote10Id = quote10.Id;

        // 20% - Sales Manager
        Quote quote20 =
            createApprovalReadyQuote(800, 'BOUNDARY20');

        quote20Id = quote20.Id;

        // 30% - Commercial Director
        Quote quote30 =
            createApprovalReadyQuote(700, 'BOUNDARY30');

        quote30Id = quote30.Id;
    }

    Quote quote10 = [
        SELECT
            Maximum_Line_Discount__c,
            Approval_Required__c,
            Approval_Status__c,
            Discount_Approver__c
        FROM Quote
        WHERE Id = :quote10Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        10,
        quote10.Maximum_Line_Discount__c
    );

    System.assertEquals(
        false,
        quote10.Approval_Required__c,
        'Exactly 10% must not require approval.'
    );

    System.assertEquals(
        'Not Required',
        quote10.Approval_Status__c
    );

    System.assertEquals(
        null,
        quote10.Discount_Approver__c
    );


    Quote quote20 = [
        SELECT
            Maximum_Line_Discount__c,
            Approval_Required__c,
            Approval_Status__c,
            Discount_Approver__c
        FROM Quote
        WHERE Id = :quote20Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        20,
        quote20.Maximum_Line_Discount__c
    );

    System.assertEquals(
        true,
        quote20.Approval_Required__c
    );

    System.assertEquals(
        'Required',
        quote20.Approval_Status__c
    );

    System.assertEquals(
        manager.Id,
        quote20.Discount_Approver__c,
        'Exactly 20% must route to Sales Manager.'
    );


    Quote quote30 = [
        SELECT
            Maximum_Line_Discount__c,
            Approval_Required__c,
            Approval_Status__c,
            Discount_Approver__c
        FROM Quote
        WHERE Id = :quote30Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        30,
        quote30.Maximum_Line_Discount__c
    );

    System.assertEquals(
        true,
        quote30.Approval_Required__c
    );

    System.assertEquals(
        'Required',
        quote30.Approval_Status__c
    );

    System.assertEquals(
        director.Id,
        quote30.Discount_Approver__c,
        'Exactly 30% must route to Commercial Director.'
    );
}
private static void assertSaveErrorContains(
    Database.SaveResult result,
    String expectedText
) {
    System.assertEquals(
        false,
        result.isSuccess(),
        'Expected DML operation to be blocked.'
    );

    Boolean found = false;

    for (Database.Error error : result.getErrors()) {
        if (
            error.getMessage() != null &&
            error.getMessage().contains(expectedText)
        ) {
            found = true;
            break;
        }
    }

    System.assert(
        found,
        'Expected error containing: ' + expectedText
    );
}
@IsTest
static void shouldBlockReviewWhenManagerIsMissing() {
    User salesRep =
        getLifecycleUser('venomgr');

    System.assertEquals(
        null,
        salesRep.ManagerId,
        'Test fixture must not have a Manager.'
    );

    System.runAs(salesRep) {
        Quote quoteRecord =
            createRoutedQuote(850, 'NO-MANAGER');

        System.assertEquals(
            15,
            quoteRecord.Maximum_Line_Discount__c
        );

        System.assertEquals(
            true,
            quoteRecord.Approval_Required__c
        );

        System.assertEquals(
            'Required',
            quoteRecord.Approval_Status__c
        );

        System.assertEquals(
            null,
            quoteRecord.Discount_Approver__c,
            'No Manager must mean no approver.'
        );

        Database.SaveResult result =
            Database.update(
                new Quote(
                    Id = quoteRecord.Id,
                    Status = 'Needs Review',
                    Discount_Justification__c =
                        'Missing manager test'
                ),
                false
            );

        assertSaveErrorContains(
            result,
            'active assigned approver'
        );
    }
}
@IsTest
static void shouldBlockReviewWhenManagerIsInactive() {
    User salesRep =
        getLifecycleUser('veisales');

    User inactiveManager =
        getLifecycleUser('veimgr');

    System.assertEquals(
        false,
        inactiveManager.IsActive,
        'Test Manager must be inactive.'
    );

    System.assertEquals(
        inactiveManager.Id,
        salesRep.ManagerId
    );

    System.runAs(salesRep) {
        Quote quoteRecord =
            createRoutedQuote(850, 'INACTIVE-MANAGER');

        System.assertEquals(
            15,
            quoteRecord.Maximum_Line_Discount__c
        );

        System.assertEquals(
            true,
            quoteRecord.Approval_Required__c
        );

        System.assertEquals(
            inactiveManager.Id,
            quoteRecord.Discount_Approver__c,
            'Routing should expose the inactive Manager condition.'
        );

        Database.SaveResult result =
            Database.update(
                new Quote(
                    Id = quoteRecord.Id,
                    Status = 'Needs Review',
                    Discount_Justification__c =
                        'Inactive manager test'
                ),
                false
            );

        assertSaveErrorContains(
            result,
            'active assigned approver'
        );
    }
}
}