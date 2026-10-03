@IsTest
private class VEQuotePricingIntegrityTest {

    @TestSetup
    static void setupData() {
    Product2 product = new Product2(
        Name = 'Pricing Integrity Product',
        ProductCode = 'TEST-PRICING-INTEGRITY',
        IsActive = true,
        Revenue_Type__c = 'One-Time'
    );
    insert product;

    // Standard price is required before a product can be
    // added to a custom Price Book.
    insert new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = product.Id,
        UnitPrice = 1000,
        CurrencyIsoCode = 'PLN',
        IsActive = true
    );

    Pricebook2 testPricebook = new Pricebook2(
        Name = 'VE Pricing Integrity Test Price Book',
        IsActive = true
    );
    insert testPricebook;

    insert new PricebookEntry(
        Pricebook2Id = testPricebook.Id,
        Product2Id = product.Id,
        UnitPrice = 1000,
        CurrencyIsoCode = 'PLN',
        IsActive = true
    );
    }

    @IsTest
    static void shouldCaptureAndFreezeApprovalBasis() {
        Quote quoteRecord = createQuote();
        PricebookEntry pbe = getPricebookEntry();

        QuoteLineItem line = new QuoteLineItem(
            QuoteId = quoteRecord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 800,
            Discount = 0,
            Discount_Reason__c = 'Other'
        );

        insert line;

        line = [
            SELECT
                Approval_Basis_Unit_Price__c,
                Effective_Discount__c,
                PricebookEntry.UnitPrice
            FROM QuoteLineItem
            WHERE Id = :line.Id
        ];

        System.assertEquals(
            1000,
            line.Approval_Basis_Unit_Price__c,
            'Approval basis must snapshot the list price.'
        );

        System.assertEquals(
            20,
            line.Effective_Discount__c,
            '800 against a 1000 approval basis must equal 20%.'
        );

        update as system new PricebookEntry(
        Id = pbe.Id,
        UnitPrice = 1200
    );

        line = [
            SELECT
                Approval_Basis_Unit_Price__c,
                Effective_Discount__c,
                PricebookEntry.UnitPrice
            FROM QuoteLineItem
            WHERE Id = :line.Id
        ];

        System.assertEquals(
            1200,
            line.PricebookEntry.UnitPrice,
            'Current price book value should change.'
        );

        System.assertEquals(
            1000,
            line.Approval_Basis_Unit_Price__c,
            'Historical approval basis must remain frozen.'
        );

        System.assertEquals(
            20,
            line.Effective_Discount__c,
            'A later price book change must not change historical effective discount.'
        );
    }

    @IsTest
    static void shouldRequireReasonForSalesPriceReduction() {
        Quote quoteRecord = createQuote();
        PricebookEntry pbe = getPricebookEntry();

        Test.startTest();

        Database.SaveResult withoutReason = Database.insert(
            new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 800,
                Discount = 0
            ),
            false
        );

        System.assertEquals(false, withoutReason.isSuccess());
        assertErrorContains(
            withoutReason.getErrors(),
            'Discount Reason'
        );

        Database.SaveResult fullPrice = Database.insert(
            new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 1000,
                Discount = 0
            ),
            false
        );

        System.assertEquals(
            true,
            fullPrice.isSuccess(),
            'No reason should be required when effective discount is zero.'
        );

        Database.SaveResult withReason = Database.insert(
            new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 800,
                Discount = 0,
                Discount_Reason__c = 'Other'
            ),
            false
        );

        System.assertEquals(
            true,
            withReason.isSuccess(),
            'Sales Price reduction should be allowed when a reason is supplied.'
        );

        Test.stopTest();
    }

    @IsTest
    static void shouldEnforceUnroundedThirtyPercentLimit() {
        Quote quoteRecord = createQuote();
        PricebookEntry pbe = getPricebookEntry();

        Test.startTest();

        Database.SaveResult exactlyThirty = Database.insert(
            new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 700,
                Discount = 0,
                Discount_Reason__c = 'Other'
            ),
            false
        );

        System.assertEquals(
            true,
            exactlyThirty.isSuccess(),
            'Exactly 30% effective discount must be allowed.'
        );

        Database.SaveResult aboveThirty = Database.insert(
            new QuoteLineItem(
                QuoteId = quoteRecord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 699.99,
                Discount = 0,
                Discount_Reason__c = 'Other'
            ),
            false
        );

        System.assertEquals(
            false,
            aboveThirty.isSuccess(),
            '30.001% effective discount must be blocked.'
        );

        assertErrorContains(
            aboveThirty.getErrors(),
            'cannot exceed 30%'
        );

        Test.stopTest();
    }

    @IsTest
    static void shouldCaptureApprovalBasisInBulk() {
        Quote quoteRecord = createQuote();
        PricebookEntry pbe = getPricebookEntry();

        List<QuoteLineItem> lines =
            new List<QuoteLineItem>();

        for (Integer i = 0; i < 200; i++) {
            lines.add(
                new QuoteLineItem(
                    QuoteId = quoteRecord.Id,
                    PricebookEntryId = pbe.Id,
                    Quantity = 1,
                    UnitPrice = 1000,
                    Discount = 0
                )
            );
        }

        Test.startTest();
        insert lines;
        Test.stopTest();

        List<QuoteLineItem> actualLines = [
            SELECT Approval_Basis_Unit_Price__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteRecord.Id
        ];

        System.assertEquals(200, actualLines.size());

        for (QuoteLineItem line : actualLines) {
            System.assertEquals(
                1000,
                line.Approval_Basis_Unit_Price__c,
                'Every bulk-inserted line must receive a pricing basis snapshot.'
            );
        }
    }

    private static Quote createQuote() {
        Account accountRecord = new Account(
            Name = 'Pricing Integrity Account'
        );
        insert accountRecord;

        Id pricebookId = [
        SELECT Id
        FROM Pricebook2
        WHERE Name = 'VE Pricing Integrity Test Price Book'
        LIMIT 1
        ].Id;

        Opportunity opportunity = new Opportunity(
            Name = 'Pricing Integrity Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pricebookId,
            CurrencyIsoCode = 'PLN'
        );
        insert opportunity;

        Quote quoteRecord = new Quote(
            Name = 'Pricing Integrity Quote',
            OpportunityId = opportunity.Id,
            Pricebook2Id = pricebookId,
            ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'PLN'
        );
        insert quoteRecord;

        return quoteRecord;
    }

    private static PricebookEntry getPricebookEntry() {
    return [
        SELECT
             Id,
            UnitPrice
        FROM PricebookEntry
        WHERE Product2.ProductCode = 'TEST-PRICING-INTEGRITY'
        AND Pricebook2.Name = 'VE Pricing Integrity Test Price Book'
        LIMIT 1
        ];
    }

    private static void assertErrorContains(
        Database.Error[] errors,
        String expectedText
    ) {
        Boolean found = false;

        for (Database.Error error : errors) {
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
static void shouldKeepApprovalBasisImmutable() {
    Quote quoteRecord = createQuote();
    PricebookEntry pbe = getPricebookEntry();

    QuoteLineItem line = new QuoteLineItem(
        QuoteId = quoteRecord.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 800,
        Discount = 0,
        Discount_Reason__c = 'Other'
    );
    insert line;

    line = [
        SELECT
            Id,
            Approval_Basis_Unit_Price__c,
            Effective_Discount__c
        FROM QuoteLineItem
        WHERE Id = :line.Id
    ];

    System.assertEquals(
        1000,
        line.Approval_Basis_Unit_Price__c
    );

    Test.startTest();

    update new QuoteLineItem(
        Id = line.Id,
        Approval_Basis_Unit_Price__c = 2000
    );

    Test.stopTest();

    line = [
        SELECT
            Approval_Basis_Unit_Price__c,
            Effective_Discount__c
        FROM QuoteLineItem
        WHERE Id = :line.Id
    ];

    System.assertEquals(
        1000,
        line.Approval_Basis_Unit_Price__c,
        'Approval basis must be immutable after capture.'
    );

    System.assertEquals(
        20,
        line.Effective_Discount__c,
        'Changing the snapshot directly must not change effective discount.'
    );
}
}