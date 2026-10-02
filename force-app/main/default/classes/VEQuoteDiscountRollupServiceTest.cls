@IsTest
private class VEQuoteDiscountRollupServiceTest {

    @TestSetup
    static void setupData() {
        Product2 product = new Product2(
            Name = 'Test Quote Product',
            ProductCode = 'TEST-QUOTE-PRODUCT',
            IsActive = true,
            Revenue_Type__c = 'One-Time'
        );

        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        update new Pricebook2(
            Id = standardPricebookId,
            IsActive = true
        );

        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true,
            CurrencyIsoCode = 'PLN'
        );
    }

    @IsTest
    static void shouldRollUpMaximumDiscount() {
        Quote quote = createQuote('Max Discount Test');

        PricebookEntry pbe = getPricebookEntry();

        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            createQuoteLine(
                quote.Id,
                pbe.Id,
                1,
                1000,
                5
            ),
            createQuoteLine(
                quote.Id,
                pbe.Id,
                1,
                1000,
                12
            ),
            createQuoteLine(
                quote.Id,
                pbe.Id,
                1,
                1000,
                25
            )
        };

        Test.startTest();
        insert lines;
        Test.stopTest();

        Quote actual = getQuoteMetrics(quote.Id);

        System.assertEquals(
            25,
            actual.Maximum_Line_Discount__c,
            'Maximum line discount should be 25%.'
        );

        System.assertEquals(
            true,
            actual.Approval_Required__c,
            '25% discount should require approval.'
        );

        System.assertEquals(
            'Commercial Director',
            actual.Discount_Approval_Level__c
        );
    }

    @IsTest
    static void shouldRecalculateAfterUpdateAndDelete() {
        Quote quote = createQuote('Update Delete Test');

        PricebookEntry pbe = getPricebookEntry();

        QuoteLineItem line12 =
            createQuoteLine(
                quote.Id,
                pbe.Id,
                1,
                1000,
                12
            );

        QuoteLineItem line25 =
            createQuoteLine(
                quote.Id,
                pbe.Id,
                1,
                1000,
                25
            );

        insert new List<QuoteLineItem>{
            line12,
            line25
        };

        // 25% -> 8%.
        // Use a clean stub and update only the field
        // that actually changed.
        QuoteLineItem lineToUpdate =
            new QuoteLineItem(
                Id = line25.Id,
                Discount = 8
            );

        Test.startTest();
        update lineToUpdate;
        Test.stopTest();

        Quote afterUpdate = getQuoteMetrics(quote.Id);

        System.assertEquals(
            12,
            afterUpdate.Maximum_Line_Discount__c
        );

        System.assertEquals(
            true,
            afterUpdate.Approval_Required__c
        );

        System.assertEquals(
            'Sales Manager',
            afterUpdate.Discount_Approval_Level__c
        );

        // Remove the 12% line.
        delete new QuoteLineItem(
            Id = line12.Id
        );

        Quote afterFirstDelete =
            getQuoteMetrics(quote.Id);

        System.assertEquals(
            8,
            afterFirstDelete.Maximum_Line_Discount__c
        );

        System.assertEquals(
            false,
            afterFirstDelete.Approval_Required__c
        );

        System.assertEquals(
            'No Approval',
            afterFirstDelete.Discount_Approval_Level__c
        );

        // Remove the last remaining line.
        delete new QuoteLineItem(
            Id = line25.Id
        );

        Quote afterLastDelete =
            getQuoteMetrics(quote.Id);

        System.assertEquals(
            0,
            afterLastDelete.Maximum_Line_Discount__c
        );

        System.assertEquals(
            false,
            afterLastDelete.Approval_Required__c
        );

        System.assertEquals(
            'No Approval',
            afterLastDelete.Discount_Approval_Level__c
        );
    }

    @IsTest
    static void shouldHandleMultipleQuotesInBulk() {
        Quote quoteA = createQuote('Bulk Quote A');
        Quote quoteB = createQuote('Bulk Quote B');

        PricebookEntry pbe = getPricebookEntry();

        List<QuoteLineItem> lines =
            new List<QuoteLineItem>{
                createQuoteLine(
                    quoteA.Id,
                    pbe.Id,
                    1,
                    1000,
                    5
                ),
                createQuoteLine(
                    quoteA.Id,
                    pbe.Id,
                    1,
                    1000,
                    15
                ),
                createQuoteLine(
                    quoteB.Id,
                    pbe.Id,
                    1,
                    1000,
                    20
                ),
                createQuoteLine(
                    quoteB.Id,
                    pbe.Id,
                    1,
                    1000,
                    30
                )
            };

        Test.startTest();
        insert lines;
        Test.stopTest();

        Quote actualA = getQuoteMetrics(quoteA.Id);
        Quote actualB = getQuoteMetrics(quoteB.Id);

        System.assertEquals(
            15,
            actualA.Maximum_Line_Discount__c
        );

        System.assertEquals(
            'Sales Manager',
            actualA.Discount_Approval_Level__c
        );

        System.assertEquals(
            30,
            actualB.Maximum_Line_Discount__c
        );

        System.assertEquals(
            'Commercial Director',
            actualB.Discount_Approval_Level__c
        );
    }

    @IsTest
    static void shouldHandleEmptyInput() {
        Test.startTest();

        VEQuoteDiscountRollupService.recalculate(null);
        VEQuoteDiscountRollupService.recalculate(
            new Set<Id>()
        );

        Test.stopTest();

        System.assert(true);
    }

    private static Quote createQuote(String quoteName) {
        Opportunity opp = new Opportunity(
            Name = quoteName + ' Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            CurrencyIsoCode = 'PLN'
        );

        insert opp;

        Quote quote = new Quote(
            Name = quoteName,
            OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(30)
        );

        insert quote;

        return quote;
    }

    private static QuoteLineItem createQuoteLine(
        Id quoteId,
        Id pricebookEntryId,
        Decimal quantity,
        Decimal unitPrice,
        Decimal discount
    ) {
        return new QuoteLineItem(
            QuoteId = quoteId,
            PricebookEntryId = pricebookEntryId,
            Quantity = quantity,
            UnitPrice = unitPrice,
            Discount = discount,
            Discount_Reason__c = 'Volume Discount'
        );
    }

    private static PricebookEntry getPricebookEntry() {
        return [
            SELECT
                Id,
                UnitPrice
            FROM PricebookEntry
            WHERE
                Pricebook2Id = :Test.getStandardPricebookId()
                AND Product2.ProductCode = 'TEST-QUOTE-PRODUCT'
                AND CurrencyIsoCode = 'PLN'
            LIMIT 1
        ];
    }

    private static Quote getQuoteMetrics(Id quoteId) {
        return [
            SELECT
                Id,
                Maximum_Line_Discount__c,
                Approval_Required__c,
                Discount_Approval_Level__c
            FROM Quote
            WHERE Id = :quoteId
        ];
    }
}