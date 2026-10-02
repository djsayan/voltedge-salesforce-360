trigger VEQuoteLineItemTrigger on QuoteLineItem (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isBefore) {
        VEQuoteLineItemHandler.validateEditable(
            Trigger.isDelete ? Trigger.old : Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    } else {
        // Salesforce has no before-undelete trigger event.
        if (Trigger.isUndelete) {
            VEQuoteLineItemHandler.validateEditable(Trigger.new, null);
        }
        VEQuoteLineItemHandler.afterChange(
            Trigger.isDelete ? Trigger.old : Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
}
