public with sharing class VEChargerProvisioningQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer MAX_ATTEMPTS = 3;

    private final Id projectId;
    private final Integer attemptNumber;

    public VEChargerProvisioningQueueable(Id projectId) {
        this(projectId, 1);
    }

    @TestVisible
    private VEChargerProvisioningQueueable(Id projectId, Integer attemptNumber) {
        this.projectId = projectId;
        this.attemptNumber = attemptNumber == null || attemptNumber < 1 ? 1 : attemptNumber;
    }

    public void execute(QueueableContext context) {
        if (projectId == null) {
            return;
        }

        List<Installation_Project__c> projects = [
            SELECT
                Id,
                Name,
                Account__c,
                Account__r.Name,
                Opportunity__c,
                Opportunity__r.Name,
                Number_of_Sites__c,
                Number_of_Chargers__c,
                Solution_Type__c,
                Target_Go_Live_Date__c,
                Provisioning_Status__c,
                External_Provisioning_Id__c
            FROM Installation_Project__c
            WHERE Id = :projectId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (projects.isEmpty()) {
            return;
        }

        Installation_Project__c projectRecord = projects[0];

        if (
            projectRecord.Provisioning_Status__c == 'Provisioned' &&
            !String.isBlank(projectRecord.External_Provisioning_Id__c)
        ) {
            return;
        }

        VEChargerProvisioningService.CalloutResult result =
            VEChargerProvisioningService.provision(projectRecord);

        Installation_Project__c updateRecord = new Installation_Project__c(
            Id = projectRecord.Id,
            Provisioning_Last_Attempt__c = System.now(),
            Provisioning_Attempt_Count__c = attemptNumber,
            Provisioning_HTTP_Status__c = result.statusCode
        );

        Boolean shouldRetry = result.retryable == true && attemptNumber < MAX_ATTEMPTS;

        if (result.success == true) {
            updateRecord.Provisioning_Status__c = 'Provisioned';
            updateRecord.External_Provisioning_Id__c = result.response.provisioningId;
            updateRecord.Provisioning_Error__c = null;
        } else if (shouldRetry) {
            updateRecord.Provisioning_Status__c = 'Queued';
            updateRecord.Provisioning_Error__c = buildRetryMessage(result, attemptNumber + 1);
        } else {
            updateRecord.Provisioning_Status__c = 'Failed';
            updateRecord.Provisioning_Error__c = result.errorMessage;
        }

        update as system updateRecord;

        if (shouldRetry) {
            System.enqueueJob(
                new VEChargerProvisioningQueueable(projectRecord.Id, attemptNumber + 1)
            );
        }
    }

    private static String buildRetryMessage(
        VEChargerProvisioningService.CalloutResult result,
        Integer nextAttempt
    ) {
        String reason = String.isBlank(result.errorMessage)
            ? 'Transient provisioning failure.'
            : result.errorMessage;
        return reason + ' Retry scheduled (attempt ' + nextAttempt + ' of ' + MAX_ATTEMPTS + ').';
    }
}
