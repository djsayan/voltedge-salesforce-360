public without sharing class VEQuoteDiscountRollupService {

    public static void recalculate(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> maxDiscountByQuote = new Map<Id, Decimal>();

        // Seed every Quote with zero.
        // Important when the last discounted line is deleted.
        for (Id quoteId : quoteIds) {
            maxDiscountByQuote.put(quoteId, 0);
        }

        for (AggregateResult result : [
            SELECT
                QuoteId quoteId,
                MAX(Discount) maxDiscount
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            GROUP BY QuoteId
        ]) {
            Id quoteId = (Id) result.get('quoteId');
            Decimal maxDiscount = (Decimal) result.get('maxDiscount');

            maxDiscountByQuote.put(
                quoteId,
                maxDiscount == null ? 0 : maxDiscount
            );
        }

        List<Quote> quotesToUpdate = new List<Quote>();

        for (Id quoteId : maxDiscountByQuote.keySet()) {
            quotesToUpdate.add(
                new Quote(
                    Id = quoteId,
                    Maximum_Line_Discount__c =
                        maxDiscountByQuote.get(quoteId)
                )
            );
        }

        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
}