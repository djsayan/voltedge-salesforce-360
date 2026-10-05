public with sharing class VEChargerProvisioningAction {
    public class Request {
        @InvocableVariable(required=true label='Installation Project Id')
        public Id projectId;
    }

    public class Response {
        @InvocableVariable(label='Installation Project Id')
        public Id projectId;

        @InvocableVariable(label='Queueable Job Id')
        public String jobId;

        @InvocableVariable(label='Submission Status')
        public String status;
    }

    @InvocableMethod(
        label='Submit Charger Provisioning'
        description='Queues Installation Projects for asynchronous provisioning in the external charger platform.'
    )
    public static List<Response> submit(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Response>();
        }

        if (requests.size() > 50) {
            throw new IllegalArgumentException('A maximum of 50 Installation Projects can be submitted per transaction.');
        }

        Set<Id> projectIds = new Set<Id>();
        for (Request request : requests) {
            if (request != null && request.projectId != null) {
                projectIds.add(request.projectId);
            }
        }

        Map<Id, Installation_Project__c> projectsById = new Map<Id, Installation_Project__c>([
            SELECT Id, Provisioning_Status__c, External_Provisioning_Id__c
            FROM Installation_Project__c
            WHERE Id IN :projectIds
            WITH SYSTEM_MODE
        ]);

        List<Installation_Project__c> queuedUpdates = new List<Installation_Project__c>();
        for (Id projectId : projectIds) {
            Installation_Project__c projectRecord = projectsById.get(projectId);
            if (
                projectRecord != null &&
                !(projectRecord.Provisioning_Status__c == 'Provisioned' &&
                  !String.isBlank(projectRecord.External_Provisioning_Id__c))
            ) {
                queuedUpdates.add(new Installation_Project__c(
                    Id = projectId,
                    Provisioning_Status__c = 'Queued',
                    Provisioning_Error__c = null
                ));
            }
        }

        if (!queuedUpdates.isEmpty()) {
            update as system queuedUpdates;
        }

        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            Response response = new Response();
            response.projectId = request == null ? null : request.projectId;

            Installation_Project__c projectRecord = response.projectId == null
                ? null
                : projectsById.get(response.projectId);

            if (response.projectId == null) {
                response.status = 'Missing Project Id';
            } else if (projectRecord == null) {
                response.status = 'Project Not Found';
            } else if (
                projectRecord.Provisioning_Status__c == 'Provisioned' &&
                !String.isBlank(projectRecord.External_Provisioning_Id__c)
            ) {
                response.status = 'Already Provisioned';
            } else {
                response.jobId = String.valueOf(
                    System.enqueueJob(new VEChargerProvisioningQueueable(response.projectId))
                );
                response.status = 'Queued';
            }

            responses.add(response);
        }

        return responses;
    }
}
