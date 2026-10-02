trigger VEQuoteLineItemTrigger on QuoteLineItem (
    after insert,
    after update,
    after delete,
    after undelete
) {
    Set<Id> quoteIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (QuoteLineItem line : Trigger.new) {
            if (line.QuoteId != null) {
                quoteIds.add(line.QuoteId);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (QuoteLineItem line : Trigger.old) {
            if (line.QuoteId != null) {
                quoteIds.add(line.QuoteId);
            }
        }
    }

    VEQuoteDiscountRollupService.recalculate(quoteIds);
}