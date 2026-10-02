/**
 * Enforces quote approval integrity for every QuoteLineItem write channel.
 * System context is intentional: users must not bypass the guard or rollup
 * through record sharing or lack of edit access to the derived Quote fields.
 */
public without sharing class VEQuoteLineItemHandler {
    private static final String APPROVAL_ERROR =
        'This quote is under approval. Recall the approval request before changing quote lines.';

    public static void validateEditable(
        List<QuoteLineItem> lines,
        Map<Id, QuoteLineItem> oldMap
    ) {
        Set<Id> quoteIds = collectQuoteIds(lines, oldMap);
        if (quoteIds.isEmpty()) {
            return;
        }

        // Lock parents before checking their state; keep the lock through DML.
        Map<Id, Quote> quotes = new Map<Id, Quote>([
            SELECT Id, Status, Approval_Status__c
            FROM Quote
            WHERE Id IN :quoteIds
            FOR UPDATE
        ]);

        for (QuoteLineItem line : lines) {
            QuoteLineItem oldLine = oldMap == null ? null : oldMap.get(line.Id);
            if (
                isPending(quotes.get(line.QuoteId)) ||
                (oldLine != null && isPending(quotes.get(oldLine.QuoteId)))
            ) {
                line.addError(APPROVAL_ERROR);
            }
        }
    }

    public static void afterChange(
        List<QuoteLineItem> lines,
        Map<Id, QuoteLineItem> oldMap
    ) {
        Set<Id> changedQuoteIds = new Set<Id>();
        for (QuoteLineItem line : lines) {
            // Also handles errors added by the after-undelete guard.
            if (line.hasErrors()) {
                continue;
            }
            QuoteLineItem oldLine = oldMap == null ? null : oldMap.get(line.Id);
            if (oldLine != null && !commercialTermsChanged(line, oldLine)) {
                continue;
            }
            if (line.QuoteId != null) {
                changedQuoteIds.add(line.QuoteId);
            }
            if (oldLine != null && oldLine.QuoteId != null) {
                changedQuoteIds.add(oldLine.QuoteId);
            }
        }

        VEQuoteDiscountRollupService.recalculate(changedQuoteIds, changedQuoteIds);
    }

    private static Boolean commercialTermsChanged(
        QuoteLineItem currentLine,
        QuoteLineItem oldLine
    ) {
        return currentLine.QuoteId != oldLine.QuoteId ||
            currentLine.PricebookEntryId != oldLine.PricebookEntryId ||
            currentLine.Quantity != oldLine.Quantity ||
            currentLine.UnitPrice != oldLine.UnitPrice ||
            currentLine.Discount != oldLine.Discount ||
            currentLine.Discount_Reason__c != oldLine.Discount_Reason__c ||
            currentLine.ServiceDate != oldLine.ServiceDate;
    }

    private static Boolean isPending(Quote quoteRecord) {
        return quoteRecord != null &&
            (quoteRecord.Approval_Status__c == 'Pending' ||
             quoteRecord.Status == 'In Review');
    }

    private static Set<Id> collectQuoteIds(
        List<QuoteLineItem> lines,
        Map<Id, QuoteLineItem> oldMap
    ) {
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem line : lines) {
            if (line.QuoteId != null) {
                quoteIds.add(line.QuoteId);
            }
            QuoteLineItem oldLine = oldMap == null ? null : oldMap.get(line.Id);
            if (oldLine != null && oldLine.QuoteId != null) {
                quoteIds.add(oldLine.QuoteId);
            }
        }
        return quoteIds;
    }
}
