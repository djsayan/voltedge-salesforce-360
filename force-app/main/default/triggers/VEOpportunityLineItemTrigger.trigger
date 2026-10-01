trigger VEOpportunityLineItemTrigger on OpportunityLineItem (
    after insert,
    after update,
    after delete,
    after undelete
) {
    Set<Id> opportunityIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (OpportunityLineItem line : Trigger.new) {
            if (line.OpportunityId != null) {
                opportunityIds.add(line.OpportunityId);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (OpportunityLineItem line : Trigger.old) {
            if (line.OpportunityId != null) {
                opportunityIds.add(line.OpportunityId);
            }
        }
    }

    VEOpportunityRevenueRollupService.recalculate(opportunityIds);
}