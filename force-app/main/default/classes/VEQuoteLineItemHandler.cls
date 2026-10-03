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

public static void captureApprovalBasisPrice(
    List<QuoteLineItem> lines,
    Map<Id, QuoteLineItem> oldMap
) {
    if (lines == null || lines.isEmpty()) {
        return;
    }

    Set<Id> pricebookEntryIds = new Set<Id>();
    Set<Id> linesNeedingSnapshot = new Set<Id>();

    for (QuoteLineItem line : lines) {
        if (line.PricebookEntryId == null) {
            continue;
        }

        QuoteLineItem oldLine =
            oldMap == null ? null : oldMap.get(line.Id);

        Boolean isInsert = oldLine == null;

        Boolean pricebookEntryChanged =
            oldLine != null &&
            line.PricebookEntryId != oldLine.PricebookEntryId;

        Boolean missingBasis =
            line.Approval_Basis_Unit_Price__c == null;

        if (
            isInsert ||
            pricebookEntryChanged ||
            missingBasis
        ) {
            pricebookEntryIds.add(line.PricebookEntryId);

            if (line.Id != null) {
                linesNeedingSnapshot.add(line.Id);
            }
        }
    }

    if (pricebookEntryIds.isEmpty()) {
        return;
    }

    Map<Id, PricebookEntry> entriesById =
        new Map<Id, PricebookEntry>([
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Id IN :pricebookEntryIds
        ]);

    for (QuoteLineItem line : lines) {
        if (line.PricebookEntryId == null) {
            continue;
        }

        QuoteLineItem oldLine =
            oldMap == null ? null : oldMap.get(line.Id);

        Boolean isInsert = oldLine == null;

        Boolean pricebookEntryChanged =
            oldLine != null &&
            line.PricebookEntryId != oldLine.PricebookEntryId;

        Boolean missingBasis =
            line.Approval_Basis_Unit_Price__c == null;

        if (
            !isInsert &&
            !pricebookEntryChanged &&
            !missingBasis
        ) {
            continue;
        }

        PricebookEntry entry =
            entriesById.get(line.PricebookEntryId);

        if (entry != null) {
            line.Approval_Basis_Unit_Price__c =
                entry.UnitPrice;
        }
    }
}
}