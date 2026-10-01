@IsTest
private class VEOpportunityRevenueRollupServiceTest {

    @TestSetup
    static void setupData() {
        List<Product2> products = new List<Product2>{
            new Product2(
                Name = 'Test One-Time Product',
                ProductCode = 'TEST-ONE',
                IsActive = true,
                Revenue_Type__c = 'One-Time'
            ),
            new Product2(
                Name = 'Test Monthly Product',
                ProductCode = 'TEST-MONTHLY',
                IsActive = true,
                Revenue_Type__c = 'Monthly Recurring',
                Default_Term_Months__c = 36
            ),
            new Product2(
                Name = 'Test Annual Product',
                ProductCode = 'TEST-ANNUAL',
                IsActive = true,
                Revenue_Type__c = 'Annual Recurring',
                Default_Term_Months__c = 36
            )
        };

        insert products;

        Id standardPricebookId = Test.getStandardPricebookId();

        update new Pricebook2(
            Id = standardPricebookId,
            IsActive = true
        );

        Map<String, Product2> productsByCode = new Map<String, Product2>();

        for (Product2 product : products) {
            productsByCode.put(product.ProductCode, product);
        }

        List<PricebookEntry> entries = new List<PricebookEntry>{
            // PLN
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-ONE').Id,
                UnitPrice = 6500,
                IsActive = true,
                CurrencyIsoCode = 'PLN'
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-MONTHLY').Id,
                UnitPrice = 65,
                IsActive = true,
                CurrencyIsoCode = 'PLN'
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-ANNUAL').Id,
                UnitPrice = 1200,
                IsActive = true,
                CurrencyIsoCode = 'PLN'
            ),

            // EUR
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-ONE').Id,
                UnitPrice = 1590,
                IsActive = true,
                CurrencyIsoCode = 'EUR'
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-MONTHLY').Id,
                UnitPrice = 17,
                IsActive = true,
                CurrencyIsoCode = 'EUR'
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productsByCode.get('TEST-ANNUAL').Id,
                UnitPrice = 300,
                IsActive = true,
                CurrencyIsoCode = 'EUR'
            )
        };

        insert entries;
    }

    @IsTest
    static void shouldRollUpMixedRevenueTypes() {
        Opportunity opp = createOpportunity(
            'Mixed Revenue Test',
            'PLN'
        );

        PricebookEntry oneTimePbe =
            getPricebookEntry('TEST-ONE', 'PLN');

        PricebookEntry monthlyPbe =
            getPricebookEntry('TEST-MONTHLY', 'PLN');

        PricebookEntry annualPbe =
            getPricebookEntry('TEST-ANNUAL', 'PLN');

        List<OpportunityLineItem> lines =
            new List<OpportunityLineItem>{
                new OpportunityLineItem(
                    OpportunityId = opp.Id,
                    PricebookEntryId = oneTimePbe.Id,
                    Quantity = 2,
                    UnitPrice = oneTimePbe.UnitPrice
                ),
                new OpportunityLineItem(
                    OpportunityId = opp.Id,
                    PricebookEntryId = monthlyPbe.Id,
                    Quantity = 10,
                    UnitPrice = monthlyPbe.UnitPrice
                ),
                new OpportunityLineItem(
                    OpportunityId = opp.Id,
                    PricebookEntryId = annualPbe.Id,
                    Quantity = 10,
                    UnitPrice = annualPbe.UnitPrice
                )
            };

        Test.startTest();
        insert lines;
        Test.stopTest();

        Opportunity actual = getOpportunityMetrics(opp.Id);

        System.assertEquals(
            13000,
            actual.One_Time_Revenue__c,
            'One-Time Revenue should equal hardware revenue.'
        );

        System.assertEquals(
            1650,
            actual.MRR__c,
            'MRR should include monthly and annual recurring products.'
        );

        System.assertEquals(
            19800,
            actual.ARR__c,
            'ARR should include all recurring products.'
        );

        System.assertEquals(
            59400,
            actual.Recurring_TCV__c,
            'Recurring TCV should include full contract value.'
        );

        System.assertEquals(
            72400,
            actual.Total_Contract_Value__c,
            'TCV should include one-time and recurring revenue.'
        );
    }

    @IsTest
    static void shouldRecalculateAfterQuantityChangeAndDelete() {
        Opportunity opp = createOpportunity(
            'Update Delete Test',
            'PLN'
        );

        PricebookEntry monthlyPbe =
            getPricebookEntry('TEST-MONTHLY', 'PLN');

        OpportunityLineItem line =
            new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = monthlyPbe.Id,
                Quantity = 10,
                UnitPrice = monthlyPbe.UnitPrice
            );

        insert line;

        // Change quantity: 10 -> 20.
        // Use a clean SObject stub so API 67 doesn't try to update
        // non-updateable relationship fields such as OpportunityId
        // and PricebookEntryId.
        OpportunityLineItem lineToUpdate = new OpportunityLineItem(
        Id = line.Id,
        Quantity = 20,
        UnitPrice = monthlyPbe.UnitPrice
        );

        Test.startTest();
        update lineToUpdate;
        Test.stopTest();

        Opportunity afterUpdate =
            getOpportunityMetrics(opp.Id);

        System.assertEquals(
            1300,
            afterUpdate.MRR__c
        );

        System.assertEquals(
            15600,
            afterUpdate.ARR__c
        );

        System.assertEquals(
            46800,
            afterUpdate.Recurring_TCV__c
        );

        System.assertEquals(
            46800,
            afterUpdate.Total_Contract_Value__c
        );

        // Delete last line.
        delete new OpportunityLineItem(
        Id = line.Id
        );

        Opportunity afterDelete =
            getOpportunityMetrics(opp.Id);

        System.assertEquals(
            0,
            afterDelete.One_Time_Revenue__c
        );

        System.assertEquals(
            0,
            afterDelete.MRR__c
        );

        System.assertEquals(
            0,
            afterDelete.ARR__c
        );

        System.assertEquals(
            0,
            afterDelete.Recurring_TCV__c
        );

        System.assertEquals(
            0,
            afterDelete.Total_Contract_Value__c
        );

        // Test undelete if supported by the object.
        if (
            OpportunityLineItem.SObjectType
                .getDescribe()
                .isUndeletable()
        ) {
            undelete line;

            Opportunity afterUndelete =
                getOpportunityMetrics(opp.Id);

            System.assertEquals(
                1300,
                afterUndelete.MRR__c
            );

            System.assertEquals(
                46800,
                afterUndelete.Total_Contract_Value__c
            );
        }
    }

    @IsTest
    static void shouldHandleMultipleOpportunitiesAndCurrencies() {
        Opportunity plnOpp = createOpportunity(
            'Bulk PLN Test',
            'PLN'
        );

        Opportunity eurOpp = createOpportunity(
            'Bulk EUR Test',
            'EUR'
        );

        PricebookEntry plnHardware =
            getPricebookEntry('TEST-ONE', 'PLN');

        PricebookEntry plnMonthly =
            getPricebookEntry('TEST-MONTHLY', 'PLN');

        PricebookEntry eurHardware =
            getPricebookEntry('TEST-ONE', 'EUR');

        PricebookEntry eurMonthly =
            getPricebookEntry('TEST-MONTHLY', 'EUR');

        List<OpportunityLineItem> lines =
            new List<OpportunityLineItem>{
                new OpportunityLineItem(
                    OpportunityId = plnOpp.Id,
                    PricebookEntryId = plnHardware.Id,
                    Quantity = 2,
                    UnitPrice = plnHardware.UnitPrice
                ),
                new OpportunityLineItem(
                    OpportunityId = plnOpp.Id,
                    PricebookEntryId = plnMonthly.Id,
                    Quantity = 10,
                    UnitPrice = plnMonthly.UnitPrice
                ),
                new OpportunityLineItem(
                    OpportunityId = eurOpp.Id,
                    PricebookEntryId = eurHardware.Id,
                    Quantity = 2,
                    UnitPrice = eurHardware.UnitPrice
                ),
                new OpportunityLineItem(
                    OpportunityId = eurOpp.Id,
                    PricebookEntryId = eurMonthly.Id,
                    Quantity = 10,
                    UnitPrice = eurMonthly.UnitPrice
                )
            };

        Test.startTest();
        insert lines;
        Test.stopTest();

        Opportunity plnActual =
            getOpportunityMetrics(plnOpp.Id);

        Opportunity eurActual =
            getOpportunityMetrics(eurOpp.Id);

        // PLN
        System.assertEquals(
            13000,
            plnActual.One_Time_Revenue__c
        );

        System.assertEquals(
            650,
            plnActual.MRR__c
        );

        System.assertEquals(
            7800,
            plnActual.ARR__c
        );

        System.assertEquals(
            23400,
            plnActual.Recurring_TCV__c
        );

        System.assertEquals(
            36400,
            plnActual.Total_Contract_Value__c
        );

        // EUR
        System.assertEquals(
            3180,
            eurActual.One_Time_Revenue__c
        );

        System.assertEquals(
            170,
            eurActual.MRR__c
        );

        System.assertEquals(
            2040,
            eurActual.ARR__c
        );

        System.assertEquals(
            6120,
            eurActual.Recurring_TCV__c
        );

        System.assertEquals(
            9300,
            eurActual.Total_Contract_Value__c
        );
    }

    @IsTest
    static void shouldHandleEmptyInput() {
        Test.startTest();

        VEOpportunityRevenueRollupService.recalculate(null);
        VEOpportunityRevenueRollupService.recalculate(
            new Set<Id>()
        );

        Test.stopTest();

        System.assert(true);
    }

    private static Opportunity createOpportunity(
        String name,
        String currencyIsoCode
    ) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            CurrencyIsoCode = currencyIsoCode
        );

        insert opp;

        return opp;
    }

    private static PricebookEntry getPricebookEntry(
        String productCode,
        String currencyIsoCode
    ) {
        return [
            SELECT
                Id,
                UnitPrice,
                Product2Id,
                CurrencyIsoCode
            FROM PricebookEntry
            WHERE
                Pricebook2Id = :Test.getStandardPricebookId()
                AND Product2.ProductCode = :productCode
                AND CurrencyIsoCode = :currencyIsoCode
            LIMIT 1
        ];
    }

    private static Opportunity getOpportunityMetrics(
        Id opportunityId
    ) {
        return [
            SELECT
                Id,
                CurrencyIsoCode,
                One_Time_Revenue__c,
                MRR__c,
                ARR__c,
                Recurring_TCV__c,
                Total_Contract_Value__c
            FROM Opportunity
            WHERE Id = :opportunityId
        ];
    }
}