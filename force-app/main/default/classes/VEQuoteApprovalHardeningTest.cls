@IsTest
private class VEQuoteApprovalHardeningTest {
    @TestSetup
    static void setupData() {
        Product2 product = new Product2(
            Name = 'Approval Hardening Product',
            ProductCode = 'TEST-APPROVAL-HARDENING',
            IsActive = true,
            Revenue_Type__c = 'One-Time'
        );
        insert as system product;
        Id pricebookId = Test.getStandardPricebookId();
        insert as system new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            CurrencyIsoCode = 'PLN',
            IsActive = true
        );
    }

    @IsTest
    static void shouldInvalidateWhenMaximumDiscountIsUnchanged() {
        Quote quoteRecord = createQuotes(1)[0];
        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            makeLine(quoteRecord.Id, 25), makeLine(quoteRecord.Id, 5)
        };
        insert as system lines;
        setApprovedFixture(new List<Quote>{quoteRecord});
        Decimal revision = getQuote(quoteRecord.Id).Commercial_Revision__c;

        Test.startTest();
        update as system new QuoteLineItem(Id = lines[1].Id, Discount = 24);
        Test.stopTest();

        assertReopened(quoteRecord.Id, 25, revision + 1, 'Required');
    }

    @IsTest
    static void shouldInvalidateAfterQuantityOrPriceChange() {
    List<Quote> quotes = createQuotes(2);

    List<QuoteLineItem> lines = new List<QuoteLineItem>{
        makeLine(quotes[0].Id, 25),
        makeLine(quotes[1].Id, 25)
    };

    insert as system lines;

    setApprovedFixture(quotes);

    Decimal revisionA =
        getQuote(quotes[0].Id).Commercial_Revision__c;

    Decimal revisionB =
        getQuote(quotes[1].Id).Commercial_Revision__c;

    QuoteLineItem priceLine = [
        SELECT
            Id,
            PricebookEntry.UnitPrice
        FROM QuoteLineItem
        WHERE Id = :lines[1].Id
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Decimal listPrice =
        priceLine.PricebookEntry.UnitPrice;

    Test.startTest();

    update as system new List<QuoteLineItem>{
        new QuoteLineItem(
            Id = lines[0].Id,
            Quantity = 2
        ),
        new QuoteLineItem(
            Id = lines[1].Id,
            UnitPrice = listPrice * 0.95
        )
    };

    Test.stopTest();

    assertReopened(
        quotes[0].Id,
        25,
        revisionA + 1,
        'Required'
    );

    assertReopened(
        quotes[1].Id,
        28.75,
        revisionB + 1,
        'Required'
    );
}
    @IsTest
    static void shouldInvalidateAfterReasonOrServiceDateChange() {
        List<Quote> quotes = createQuotes(2);
        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            makeLine(quotes[0].Id, 25), makeLine(quotes[1].Id, 25)
        };
        insert as system lines;
        setApprovedFixture(quotes);
        Decimal revisionA = getQuote(quotes[0].Id).Commercial_Revision__c;
        Decimal revisionB = getQuote(quotes[1].Id).Commercial_Revision__c;

        Test.startTest();
        update as system new List<QuoteLineItem>{
            new QuoteLineItem(Id = lines[0].Id, Discount_Reason__c = 'Other'),
            new QuoteLineItem(Id = lines[1].Id, ServiceDate = Date.today().addDays(7))
        };
        Test.stopTest();

        assertReopened(quotes[0].Id, 25, revisionA + 1, 'Required');
        assertReopened(quotes[1].Id, 25, revisionB + 1, 'Required');
    }

    @IsTest
    static void shouldPreserveApprovalForDescriptionOnly() {
        Quote quoteRecord = createQuotes(1)[0];
        QuoteLineItem line = makeLine(quoteRecord.Id, 25);
        insert as system line;
        setApprovedFixture(new List<Quote>{quoteRecord});
        Quote beforeUpdate = getQuote(quoteRecord.Id);

        Test.startTest();
        update as system new QuoteLineItem(Id = line.Id, Description = 'Internal note');
        Test.stopTest();

        Quote actual = getQuote(quoteRecord.Id);
        System.assertEquals('Approved', actual.Status);
        System.assertEquals('Approved', actual.Approval_Status__c);
        System.assertEquals(beforeUpdate.Commercial_Revision__c, actual.Commercial_Revision__c);
        System.assertEquals(25, actual.Maximum_Line_Discount__c);
    }

    @IsTest
    static void shouldReopenPresentedQuoteBelowApprovalThreshold() {
        Quote quoteRecord = createQuotes(1)[0];
        QuoteLineItem line = makeLine(quoteRecord.Id, 5);
        insert as system line;
        update as system new Quote(Id = quoteRecord.Id, Status = 'Presented');
        Decimal revision = getQuote(quoteRecord.Id).Commercial_Revision__c;

        Test.startTest();
        update as system new QuoteLineItem(Id = line.Id, Quantity = 2, UnitPrice = 1000);
        Test.stopTest();

        assertReopened(quoteRecord.Id, 5, revision + 1, 'Not Required');
    }

    @IsTest
    static void shouldInvalidateAfterInsertDeleteAndRestore() {
        Quote quoteRecord = createQuotes(1)[0];
        QuoteLineItem initialLine = makeLine(quoteRecord.Id, 25);
        insert as system initialLine;
        setApprovedFixture(new List<Quote>{quoteRecord});
        Decimal revision = getQuote(quoteRecord.Id).Commercial_Revision__c;
        QuoteLineItem extraLine = makeLine(quoteRecord.Id, 5);

        Test.startTest();
        insert as system extraLine;
        revision += 1;
        assertReopened(quoteRecord.Id, 25, revision, 'Required');

        setApprovedFixture(new List<Quote>{quoteRecord});
        delete as system new QuoteLineItem(Id = extraLine.Id);
        revision += 1;
        assertReopened(quoteRecord.Id, 25, revision, 'Required');

        if (QuoteLineItem.SObjectType.getDescribe().isUndeletable()) {
            setApprovedFixture(new List<Quote>{quoteRecord});
            QuoteLineItem deletedLine = new QuoteLineItem(Id = extraLine.Id);
            undelete as system deletedLine;
            revision += 1;
            assertReopened(quoteRecord.Id, 25, revision, 'Required');
            delete as system deletedLine;
            revision += 1;
        }

        setApprovedFixture(new List<Quote>{quoteRecord});
        delete as system new QuoteLineItem(Id = initialLine.Id);
        Test.stopTest();

        assertReopened(quoteRecord.Id, 0, revision + 1, 'Not Required');
    }

    @IsTest
    static void shouldBlockWritesWhilePendingAndAllowAfterExit() {
        Quote quoteRecord = createQuotes(1)[0];
        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            makeLine(quoteRecord.Id, 25), makeLine(quoteRecord.Id, 5)
        };
        insert as system lines;
        delete as system new QuoteLineItem(Id = lines[1].Id);
        // State fixture only. Real submission/recall is covered by manual UAT.
        update as system new Quote(
            Id = quoteRecord.Id, Status = 'In Review', Approval_Status__c = 'Pending'
        );
        Decimal revision = getQuote(quoteRecord.Id).Commercial_Revision__c;

        Test.startTest();
        Database.SaveResult insertResult = Database.insert(makeLine(quoteRecord.Id, 5), false,AccessLevel.SYSTEM_MODE);
        System.assertEquals(false, insertResult.isSuccess());
        assertGuardError(insertResult.getErrors());

        Database.SaveResult updateResult = Database.update(
            new QuoteLineItem(Id = lines[0].Id, Description = 'Blocked note'), false,AccessLevel.SYSTEM_MODE
        );
        System.assertEquals(false, updateResult.isSuccess());
        assertGuardError(updateResult.getErrors());

        Database.DeleteResult deleteResult = Database.delete(
            new QuoteLineItem(Id = lines[0].Id), false,AccessLevel.SYSTEM_MODE
        );
        System.assertEquals(false, deleteResult.isSuccess());
        assertGuardError(deleteResult.getErrors());

        if (QuoteLineItem.SObjectType.getDescribe().isUndeletable()) {
            Database.UndeleteResult restoreResult = Database.undelete(
                new QuoteLineItem(Id = lines[1].Id), false
            );
            System.assertEquals(false, restoreResult.isSuccess());
        }

        Quote stillPending = getQuote(quoteRecord.Id);
        System.assertEquals('Pending', stillPending.Approval_Status__c);
        System.assertEquals('In Review', stillPending.Status);
        System.assertEquals(revision, stillPending.Commercial_Revision__c);
        System.assertEquals(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteRecord.Id]);

        // No real ProcessInstance exists in this fixture, so unlock by state.
        update as system new Quote(Id = quoteRecord.Id, Status = 'Draft', Approval_Status__c = 'Required');
        update as system new QuoteLineItem(Id = lines[0].Id, Quantity = 2, UnitPrice = 1000);
        Test.stopTest();

        assertReopened(quoteRecord.Id, 25, revision + 1, 'Required');
    }

    @IsTest
    static void shouldBlockEitherPendingIndicator() {
        List<Quote> quotes = createQuotes(2);
        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            makeLine(quotes[0].Id, 25), makeLine(quotes[1].Id, 25)
        };
        insert as system lines;
        // Test each status independently, including inconsistent legacy states.
        update as system new List<Quote>{
            new Quote(Id = quotes[0].Id, Status = 'Draft', Approval_Status__c = 'Pending'),
            new Quote(Id = quotes[1].Id, Status = 'In Review', Approval_Status__c = 'Required')
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.update(new List<QuoteLineItem>{
            new QuoteLineItem(Id = lines[0].Id, Discount = 24),
            new QuoteLineItem(Id = lines[1].Id, Discount = 24)
        }, false);
        Test.stopTest();

        for (Database.SaveResult result : results) {
            System.assertEquals(false, result.isSuccess());
            assertGuardError(result.getErrors());
        }
    }

    @IsTest
    static void shouldAllowPartialSuccessAcrossQuotes() {
        List<Quote> quotes = createQuotes(2);
        List<QuoteLineItem> lines = new List<QuoteLineItem>{
            makeLine(quotes[0].Id, 25), makeLine(quotes[1].Id, 25)
        };
        insert as system lines;
        update as system new Quote(Id = quotes[0].Id, Status = 'In Review', Approval_Status__c = 'Pending');
        Decimal revisionA = getQuote(quotes[0].Id).Commercial_Revision__c;
        Decimal revisionB = getQuote(quotes[1].Id).Commercial_Revision__c;

        Test.startTest();
        List<Database.SaveResult> results = Database.update(new List<QuoteLineItem>{
            new QuoteLineItem(Id = lines[0].Id, Discount = 24),
            new QuoteLineItem(Id = lines[1].Id, Discount = 24)
        }, false);
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess());
        assertGuardError(results[0].getErrors());
        System.assertEquals(true, results[1].isSuccess());
        Quote unchanged = getQuote(quotes[0].Id);
        System.assertEquals('Pending', unchanged.Approval_Status__c);
        System.assertEquals(25, unchanged.Maximum_Line_Discount__c);
        System.assertEquals(revisionA, unchanged.Commercial_Revision__c);
        assertReopened(quotes[1].Id, 24, revisionB + 1, 'Required');
    }

    @IsTest
    static void shouldHandleTwoHundredLinesAcrossTenQuotes() {
        List<Quote> quotes = createQuotes(10);
        Id pbeId = getPricebookEntryId();
        List<QuoteLineItem> lines = new List<QuoteLineItem>();
        for (Quote quoteRecord : quotes) {
            for (Integer i = 0; i < 20; i++) {
                lines.add(new QuoteLineItem(
                    QuoteId = quoteRecord.Id, PricebookEntryId = pbeId,
                    Quantity = 1, UnitPrice = 1000,
                    Discount = i == 0 ? 25 : 5,
                    Discount_Reason__c = 'Volume Discount'
                ));
            }
        }
        insert as system lines;
        setApprovedFixture(quotes);
        Set<Id> quoteIds = new Map<Id, Quote>(quotes).keySet();
        Map<Id, Quote> beforeUpdate = new Map<Id, Quote>([
        SELECT Id, Commercial_Revision__c
        FROM Quote
        WHERE Id IN :quoteIds
        WITH SYSTEM_MODE
    ]);
        List<QuoteLineItem> updates = new List<QuoteLineItem>();
        for (QuoteLineItem line : lines) {
            updates.add(new QuoteLineItem(
                Id = line.Id, Quantity = 2, UnitPrice = 1000,
                Discount = line.Discount == 25 ? 25 : 24
            ));
        }

        Test.startTest();
        update as system updates;
        Test.stopTest();

        List<Quote> actualQuotes = [
        SELECT
            Id,
            Status,
            Approval_Status__c,
            Maximum_Line_Discount__c,
            Commercial_Revision__c
        FROM Quote
        WHERE Id IN :quoteIds
        WITH SYSTEM_MODE
    ];
        System.assertEquals(10, actualQuotes.size());
        for (Quote actual : actualQuotes) {
            System.assertEquals(25, actual.Maximum_Line_Discount__c);
            System.assertEquals('Draft', actual.Status);
            System.assertEquals('Required', actual.Approval_Status__c);
            System.assertEquals(
                beforeUpdate.get(actual.Id).Commercial_Revision__c + 1,
                actual.Commercial_Revision__c,
                'Increment once per quote in this 200-line trigger batch.'
            );
        }
    }

    @IsTest
    static void shouldPreserveApprovalDuringUnchangedMetricsRefresh() {
        Quote quoteRecord = createQuotes(1)[0];
        insert as system makeLine(quoteRecord.Id, 25);
        setApprovedFixture(new List<Quote>{quoteRecord});
        Decimal revision = getQuote(quoteRecord.Id).Commercial_Revision__c;

        Test.startTest();
        VEQuoteDiscountRollupService.recalculate(new Set<Id>{quoteRecord.Id});
        Test.stopTest();

        Quote actual = getQuote(quoteRecord.Id);
        System.assertEquals('Approved', actual.Status);
        System.assertEquals('Approved', actual.Approval_Status__c);
        System.assertEquals(revision, actual.Commercial_Revision__c);
    }

    private static List<Quote> createQuotes(Integer count) {
        Opportunity opp = new Opportunity(
            Name = 'Approval Hardening Opportunity', StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(), CurrencyIsoCode = 'PLN'
        );
        insert as system opp;
        List<Quote> quotes = new List<Quote>();
        for (Integer i = 0; i < count; i++) {
            quotes.add(new Quote(
                Name = 'Approval Hardening ' + i, OpportunityId = opp.Id,
                Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft',
                ExpirationDate = Date.today().addDays(30)
            ));
        }
        insert as system quotes;
        return quotes;
    }

    private static Id getPricebookEntryId() {
        return [
            SELECT Id FROM PricebookEntry
            WHERE Product2.ProductCode = 'TEST-APPROVAL-HARDENING'
                AND Pricebook2Id = :Test.getStandardPricebookId()
                AND CurrencyIsoCode = 'PLN'
                WITH SYSTEM_MODE
            LIMIT 1
        ].Id;
    }

    private static QuoteLineItem makeLine(Id quoteId, Decimal discount) {
        return new QuoteLineItem(
            QuoteId = quoteId, PricebookEntryId = getPricebookEntryId(),
            Quantity = 1, UnitPrice = 1000, Discount = discount,
            Discount_Reason__c = 'Volume Discount'
        );
    }

    private static void setApprovedFixture(List<Quote> quotes) {
        // Deliberately sets a state fixture; does not simulate approval history.
        List<Quote> updates = new List<Quote>();
        for (Quote quoteRecord : quotes) {
            updates.add(new Quote(Id = quoteRecord.Id, Status = 'Approved', Approval_Status__c = 'Approved'));
        }
        update as system updates;
    }

    private static Quote getQuote(Id quoteId) {
        return [
            SELECT Id, Status, Approval_Status__c, Maximum_Line_Discount__c, Commercial_Revision__c
            FROM Quote WHERE Id = :quoteId
            WITH SYSTEM_MODE
        ];
    }

    private static void assertReopened(Id quoteId, Decimal maxDiscount, Decimal revision, String approvalStatus) {
        Quote actual = getQuote(quoteId);
        System.assertEquals('Draft', actual.Status, 'Commercial edits must reopen the quote.');
        System.assertEquals(approvalStatus, actual.Approval_Status__c);
        System.assertEquals(maxDiscount, actual.Maximum_Line_Discount__c);
        System.assertEquals(revision, actual.Commercial_Revision__c);
    }

    private static void assertGuardError(Database.Error[] errors) {
        Boolean found = false;
        for (Database.Error error : errors) {
            if (error.getMessage().contains('This quote is under approval.')) {
                found = true;
            }
        }
        System.assert(found, 'Expected the quote-line approval guard error.');
    }
}
