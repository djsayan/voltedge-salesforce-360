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
        Map<String, Object> opportunityFields = opportunityRecord.getPopulatedFieldsAsMap();

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
        Map<String, Object> quoteFields = new Map<String, Object>();
        if (!quoteRecords.isEmpty()) {
            SObjectAccessDecision quoteAccess = Security.stripInaccessible(
                AccessType.READABLE,
                quoteRecords
            );
            latestQuote = (Quote) quoteAccess.getRecords()[0];
            quoteFields = latestQuote.getPopulatedFieldsAsMap();
        }

        CommercialSummary summary = new CommercialSummary();
        summary.opportunityName = (String) opportunityFields.get('Name');
        summary.currencyIsoCode = (String) opportunityFields.get('CurrencyIsoCode');
        summary.totalContractValue = (Decimal) opportunityFields.get('Total_Contract_Value__c');
        summary.recurringTcv = (Decimal) opportunityFields.get('Recurring_TCV__c');
        summary.arr = (Decimal) opportunityFields.get('ARR__c');
        summary.mrr = (Decimal) opportunityFields.get('MRR__c');
        summary.oneTimeRevenue = (Decimal) opportunityFields.get('One_Time_Revenue__c');
        summary.hasQuote = latestQuote != null;

        if (latestQuote != null) {
            summary.quoteId = (Id) quoteFields.get('Id');
            summary.quoteName = (String) quoteFields.get('Name');
            summary.quoteStatus = (String) quoteFields.get('Status');
            summary.approvalStatus = (String) quoteFields.get('Approval_Status__c');
            summary.maximumLineDiscount = (Decimal) quoteFields.get('Maximum_Line_Discount__c');
            summary.commercialRevision = (Decimal) quoteFields.get('Commercial_Revision__c');
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
