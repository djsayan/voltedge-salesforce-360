public without sharing class VEOpportunityRevenueRollupService {

    public static void recalculate(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, RevenueTotals> totalsByOpportunity = new Map<Id, RevenueTotals>();

        // Seed every Opportunity with zero values.
        // This is important when the last Opportunity Product is deleted.
        for (Id opportunityId : opportunityIds) {
            totalsByOpportunity.put(opportunityId, new RevenueTotals());
        }

            for (OpportunityLineItem line : [
            SELECT
                OpportunityId,
                CurrencyIsoCode,
                One_Time_Revenue__c,
                MRR__c,
                ARR__c,
                Recurring_TCV__c,
                Line_TCV__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :opportunityIds
            WITH SYSTEM_MODE
        ]) {
            RevenueTotals totals = totalsByOpportunity.get(line.OpportunityId);

            totals.oneTimeRevenue += valueOrZero(line.One_Time_Revenue__c);
            totals.mrr += valueOrZero(line.MRR__c);
            totals.arr += valueOrZero(line.ARR__c);
            totals.recurringTcv += valueOrZero(line.Recurring_TCV__c);
            totals.totalContractValue += valueOrZero(line.Line_TCV__c);
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Id opportunityId : totalsByOpportunity.keySet()) {
            RevenueTotals totals = totalsByOpportunity.get(opportunityId);

            opportunitiesToUpdate.add(new Opportunity(
                Id = opportunityId,
                One_Time_Revenue__c = totals.oneTimeRevenue,
                MRR__c = totals.mrr,
                ARR__c = totals.arr,
                Recurring_TCV__c = totals.recurringTcv,
                Total_Contract_Value__c = totals.totalContractValue
            ));
        }

            if (!opportunitiesToUpdate.isEmpty()) {
        update as system opportunitiesToUpdate;
    }
    }

    private static Decimal valueOrZero(Decimal value) {
        return value == null ? 0 : value;
    }

    private class RevenueTotals {
        Decimal oneTimeRevenue = 0;
        Decimal mrr = 0;
        Decimal arr = 0;
        Decimal recurringTcv = 0;
        Decimal totalContractValue = 0;
    }
}