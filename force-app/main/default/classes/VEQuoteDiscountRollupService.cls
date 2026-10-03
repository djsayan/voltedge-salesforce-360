/** Recalculates Quote metrics in system context, including all child lines. */
public without sharing class VEQuoteDiscountRollupService {

    // Compatibility entry point: a metrics refresh is not a commercial edit.
    public static void recalculate(Set<Id> quoteIds) {
        recalculate(quoteIds, new Set<Id>());
    }

    public static void recalculate(
        Set<Id> quoteIds,
        Set<Id> commerciallyChangedQuoteIds
    ) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return;
        }

        // Read the revision while holding a parent lock to avoid lost increments.
        List<Quote> quotes = [
            SELECT
                Id,
                Maximum_Line_Discount__c,
                Commercial_Revision__c
            FROM Quote
            WHERE Id IN :quoteIds
            WITH SYSTEM_MODE
            FOR UPDATE
        ];

        if (quotes.isEmpty()) {
            return;
        }

        Map<Id, Decimal> maxDiscountByQuote =
            new Map<Id, Decimal>();

        for (Quote quoteRecord : quotes) {
            maxDiscountByQuote.put(
                quoteRecord.Id,
                0
            );
        }

        for (AggregateResult result : [
            SELECT
                QuoteId,
                MAX(Effective_Discount__c) maxDiscount
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            WITH SYSTEM_MODE
            GROUP BY QuoteId
        ]) {
            Decimal maxDiscount =
                (Decimal) result.get('maxDiscount');

            maxDiscountByQuote.put(
                (Id) result.get('quoteId'),
                maxDiscount == null ? 0 : maxDiscount
            );
        }

        List<Quote> quotesToUpdate =
            new List<Quote>();

        for (Quote quoteRecord : quotes) {

            Decimal maxDiscount =
                maxDiscountByQuote.get(
                    quoteRecord.Id
                );

            Boolean commercialChange =
                commerciallyChangedQuoteIds != null &&
                commerciallyChangedQuoteIds.contains(
                    quoteRecord.Id
                );

            if (
                !commercialChange &&
                quoteRecord.Maximum_Line_Discount__c ==
                    maxDiscount
            ) {
                continue;
            }

            Quote updateRecord = new Quote(
                Id = quoteRecord.Id,
                Maximum_Line_Discount__c =
                    maxDiscount
            );

            if (commercialChange) {
                Decimal currentRevision =
                    quoteRecord
                        .Commercial_Revision__c;

                updateRecord
                    .Commercial_Revision__c =
                    (
                        currentRevision == null
                            ? 0
                            : currentRevision
                    ) + 1;
            }

            quotesToUpdate.add(updateRecord);
        }

        // The Quote before-save Flow owns status reset
        // and approver routing.
        if (!quotesToUpdate.isEmpty()) {
            update as system quotesToUpdate;
        }
    }
}