@IsTest
private class VECommercialSummaryControllerTest {
    @IsTest
    static void returnsOpportunityMetricsAndLatestQuote() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Account accountRecord = new Account(Name = 'VE Commercial Summary Account');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'VE Commercial Summary Opportunity',
            AccountId = accountRecord.Id,
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
        insert opportunityRecord;

        Quote quoteRecord = new Quote(
            Name = 'VE Commercial Summary Quote',
            OpportunityId = opportunityRecord.Id,
            Pricebook2Id = standardPricebookId,
            ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'USD'
        );
        insert quoteRecord;

        Test.startTest();
        VECommercialSummaryController.CommercialSummary result =
            VECommercialSummaryController.getSummary(opportunityRecord.Id);
        Test.stopTest();

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
        Account accountRecord = new Account(Name = 'VE No Quote Account');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'VE No Quote Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            CurrencyIsoCode = 'USD'
        );
        insert opportunityRecord;

        Test.startTest();
        VECommercialSummaryController.CommercialSummary result =
            VECommercialSummaryController.getSummary(opportunityRecord.Id);
        Test.stopTest();

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
