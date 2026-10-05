public with sharing class VECommercialSummaryController {
    @AuraEnabled(cacheable=true)
    public static CommercialSummary getSummary(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        List<Opportunity> opportunityRecords = [
            SELECT
                Id,
                Name,
                CurrencyIsoCode,
                Total_Contract_Value__c,
                Recurring_TCV__c,
                ARR__c,
                MRR__c,
                One_Time_Revenue__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        SObjectAccessDecision opportunityAccess = Security.stripInaccessible(
            AccessType.READABLE,
            opportunityRecords
        );
        Opportunity opportunityRecord = (Opportunity) opportunityAccess.getRecords()[0];

        List<Quote> quoteRecords = [
            SELECT
                Id,
                Name,
                Status,
                Approval_Status__c,
                Maximum_Line_Discount__c,
                Commercial_Revision__c
            FROM Quote
            WHERE OpportunityId = :opportunityId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];

        Quote latestQuote;
        if (!quoteRecords.isEmpty()) {
            SObjectAccessDecision quoteAccess = Security.stripInaccessible(
                AccessType.READABLE,
                quoteRecords
            );
            latestQuote = (Quote) quoteAccess.getRecords()[0];
        }

        CommercialSummary summary = new CommercialSummary();
        summary.opportunityName = opportunityRecord.Name;
        summary.currencyIsoCode = opportunityRecord.CurrencyIsoCode;
        summary.totalContractValue = opportunityRecord.Total_Contract_Value__c;
        summary.recurringTcv = opportunityRecord.Recurring_TCV__c;
        summary.arr = opportunityRecord.ARR__c;
        summary.mrr = opportunityRecord.MRR__c;
        summary.oneTimeRevenue = opportunityRecord.One_Time_Revenue__c;
        summary.hasQuote = latestQuote != null;

        if (latestQuote != null) {
            summary.quoteId = latestQuote.Id;
            summary.quoteName = latestQuote.Name;
            summary.quoteStatus = latestQuote.Status;
            summary.approvalStatus = latestQuote.Approval_Status__c;
            summary.maximumLineDiscount = latestQuote.Maximum_Line_Discount__c;
            summary.commercialRevision = latestQuote.Commercial_Revision__c;
        }

        return summary;
    }

    public class CommercialSummary {
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public String currencyIsoCode { get; set; }
        @AuraEnabled public Decimal totalContractValue { get; set; }
        @AuraEnabled public Decimal recurringTcv { get; set; }
        @AuraEnabled public Decimal arr { get; set; }
        @AuraEnabled public Decimal mrr { get; set; }
        @AuraEnabled public Decimal oneTimeRevenue { get; set; }
        @AuraEnabled public Boolean hasQuote { get; set; }
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String quoteName { get; set; }
        @AuraEnabled public String quoteStatus { get; set; }
        @AuraEnabled public String approvalStatus { get; set; }
        @AuraEnabled public Decimal maximumLineDiscount { get; set; }
        @AuraEnabled public Decimal commercialRevision { get; set; }
    }
}
