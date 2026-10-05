@IsTest
private class VECommercialSummaryControllerTest {
    @TestSetup
    static void setupSummaryUser() {
        String stamp = String.valueOf(System.now().getTime());

        User summaryUser = new User(
            FirstName = 'VE',
            LastName = 'Commercial Summary',
            Alias = 'vecsum',
            Email = 've.summary@test.example',
            Username = 've.summary.' + stamp + '@example.com',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'Europe/Warsaw',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert summaryUser;

        Id permissionSetId = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'VE_Commercial_Summary_User'
            WITH SYSTEM_MODE
            LIMIT 1
        ].Id;

        insert as system new PermissionSetAssignment(
            AssigneeId = summaryUser.Id,
            PermissionSetId = permissionSetId
        );
    }

    @IsTest
    static void returnsOpportunityMetricsAndLatestQuote() {
        User summaryUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'vecsum'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Id standardPricebookId = Test.getStandardPricebookId();

        Account accountRecord = new Account(
            Name = 'VE Commercial Summary Account',
            OwnerId = summaryUser.Id
        );
        insert as system accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'VE Commercial Summary Opportunity',
            AccountId = accountRecord.Id,
            OwnerId = summaryUser.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            CurrencyIsoCode = 'USD',
            Total_Contract_Value__c = 125000,
            Recurring_TCV__c = 45000,
            ARR__c = 18000,
            MRR__c = 1500,
            One_Time_Revenue__c = 80000
        );
        insert as system opportunityRecord;

        Quote quoteRecord = new Quote(
            Name = 'VE Commercial Summary Quote',
            OpportunityId = opportunityRecord.Id,
            Pricebook2Id = standardPricebookId,
            ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'USD'
        );
        insert as system quoteRecord;

        VECommercialSummaryController.CommercialSummary result;
        System.runAs(summaryUser) {
            Test.startTest();
            result = VECommercialSummaryController.getSummary(opportunityRecord.Id);
            Test.stopTest();
        }

        System.assertEquals('VE Commercial Summary Opportunity', result.opportunityName);
        System.assertEquals('USD', result.currencyIsoCode);
        System.assertEquals(125000, result.totalContractValue);
        System.assertEquals(45000, result.recurringTcv);
        System.assertEquals(18000, result.arr);
        System.assertEquals(1500, result.mrr);
        System.assertEquals(80000, result.oneTimeRevenue);
        System.assertEquals(true, result.hasQuote);
        System.assertEquals(quoteRecord.Id, result.quoteId);
        System.assertEquals('VE Commercial Summary Quote', result.quoteName);
    }

    @IsTest
    static void returnsGracefulNoQuoteState() {
        User summaryUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'vecsum'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Account accountRecord = new Account(
            Name = 'VE No Quote Account',
            OwnerId = summaryUser.Id
        );
        insert as system accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'VE No Quote Opportunity',
            AccountId = accountRecord.Id,
            OwnerId = summaryUser.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            CurrencyIsoCode = 'USD'
        );
        insert as system opportunityRecord;

        VECommercialSummaryController.CommercialSummary result;
        System.runAs(summaryUser) {
            Test.startTest();
            result = VECommercialSummaryController.getSummary(opportunityRecord.Id);
            Test.stopTest();
        }

        System.assertEquals(false, result.hasQuote);
        System.assertEquals(null, result.quoteId);
        System.assertEquals(null, result.quoteName);
    }

    @IsTest
    static void rejectsMissingOpportunityId() {
        Test.startTest();
        try {
            VECommercialSummaryController.getSummary(null);
            System.assert(false, 'Expected AuraHandledException for null Opportunity Id.');
        } catch (AuraHandledException expectedException) {
            System.assertNotEquals(null, expectedException);
        }
        Test.stopTest();
    }
}
