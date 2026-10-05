@IsTest
private class VEChargerProvisioningTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(request.getEndpoint().contains('VE_Charger_Provisioning'));
            System.assertNotEquals(null, request.getHeader('Idempotency-Key'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"provisioningId":"PRV-10482","status":"ACCEPTED","message":"Installation accepted for provisioning"}');
            return response;
        }
    }

    private class ClientErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"error":"Invalid installation payload"}');
            return response;
        }
    }

    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(503);
            response.setBody('{"error":"Provisioning service unavailable"}');
            return response;
        }
    }

    private class InvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('not-json');
            return response;
        }
    }

    private class MissingProvisioningIdMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"status":"ACCEPTED","message":"Missing id"}');
            return response;
        }
    }

    private static Installation_Project__c createProject() {
        Account accountRecord = new Account(Name = 'VE Provisioning Account');
        insert as system accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'VE Provisioning Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today()
        );
        insert as system opportunityRecord;

        Installation_Project__c projectRecord = new Installation_Project__c(
            Account__c = accountRecord.Id,
            Opportunity__c = opportunityRecord.Id,
            Number_of_Sites__c = 2,
            Number_of_Chargers__c = 12,
            Solution_Type__c = 'Mixed',
            Status__c = 'Planning',
            Target_Go_Live_Date__c = Date.today().addDays(45)
        );
        insert as system projectRecord;
        return projectRecord;
    }

    private static Installation_Project__c queryProjectForCallout(Id projectId) {
        return [
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
        ];
    }

    @IsTest
    static void successfulProvisioningStoresExternalResult() {
        Installation_Project__c projectRecord = createProject();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        System.enqueueJob(new VEChargerProvisioningQueueable(projectRecord.Id));
        Test.stopTest();

        Installation_Project__c actual = [
            SELECT
                Provisioning_Status__c,
                External_Provisioning_Id__c,
                Provisioning_Attempt_Count__c,
                Provisioning_HTTP_Status__c,
                Provisioning_Error__c,
                Provisioning_Last_Attempt__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Provisioned', actual.Provisioning_Status__c);
        System.assertEquals('PRV-10482', actual.External_Provisioning_Id__c);
        System.assertEquals(1, actual.Provisioning_Attempt_Count__c);
        System.assertEquals(201, actual.Provisioning_HTTP_Status__c);
        System.assertEquals(null, actual.Provisioning_Error__c);
        System.assertNotEquals(null, actual.Provisioning_Last_Attempt__c);
    }

    @IsTest
    static void clientErrorFailsWithoutRetry() {
        Installation_Project__c projectRecord = createProject();
        Test.setMock(HttpCalloutMock.class, new ClientErrorMock());

        Test.startTest();
        System.enqueueJob(new VEChargerProvisioningQueueable(projectRecord.Id));
        Test.stopTest();

        Installation_Project__c actual = [
            SELECT
                Provisioning_Status__c,
                Provisioning_Attempt_Count__c,
                Provisioning_HTTP_Status__c,
                Provisioning_Error__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Failed', actual.Provisioning_Status__c);
        System.assertEquals(1, actual.Provisioning_Attempt_Count__c);
        System.assertEquals(400, actual.Provisioning_HTTP_Status__c);
        System.assert(actual.Provisioning_Error__c.contains('HTTP 400'));
    }

    @IsTest
    static void transientErrorSchedulesRetry() {
        Installation_Project__c projectRecord = createProject();
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        System.enqueueJob(new VEChargerProvisioningQueueable(projectRecord.Id));
        Test.stopTest();

        Installation_Project__c actual = [
            SELECT
                Provisioning_Status__c,
                Provisioning_Attempt_Count__c,
                Provisioning_HTTP_Status__c,
                Provisioning_Error__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Queued', actual.Provisioning_Status__c);
        System.assertEquals(1, actual.Provisioning_Attempt_Count__c);
        System.assertEquals(503, actual.Provisioning_HTTP_Status__c);
        System.assert(actual.Provisioning_Error__c.contains('Retry scheduled'));
        System.assert(actual.Provisioning_Error__c.contains('attempt 2 of 3'));
    }

    @IsTest
    static void transientErrorFailsAfterFinalAttempt() {
        Installation_Project__c projectRecord = createProject();
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        System.enqueueJob(new VEChargerProvisioningQueueable(projectRecord.Id, 3));
        Test.stopTest();

        Installation_Project__c actual = [
            SELECT
                Provisioning_Status__c,
                Provisioning_Attempt_Count__c,
                Provisioning_HTTP_Status__c,
                Provisioning_Error__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Failed', actual.Provisioning_Status__c);
        System.assertEquals(3, actual.Provisioning_Attempt_Count__c);
        System.assertEquals(503, actual.Provisioning_HTTP_Status__c);
        System.assert(actual.Provisioning_Error__c.contains('HTTP 503'));
    }

    @IsTest
    static void invalidSuccessResponseIsRejected() {
        Installation_Project__c projectRecord = queryProjectForCallout(createProject().Id);

        Test.setMock(HttpCalloutMock.class, new InvalidJsonMock());
        VEChargerProvisioningService.CalloutResult invalidJson =
            VEChargerProvisioningService.provision(projectRecord);
        System.assertEquals(false, invalidJson.success);
        System.assertEquals(false, invalidJson.retryable);
        System.assert(invalidJson.errorMessage.contains('invalid JSON'));

        Test.setMock(HttpCalloutMock.class, new MissingProvisioningIdMock());
        VEChargerProvisioningService.CalloutResult missingId =
            VEChargerProvisioningService.provision(projectRecord);
        System.assertEquals(false, missingId.success);
        System.assertEquals(false, missingId.retryable);
        System.assert(missingId.errorMessage.contains('did not contain provisioningId'));
    }

    @IsTest
    static void alreadyProvisionedProjectIsIdempotent() {
        Installation_Project__c projectRecord = createProject();
        update as system new Installation_Project__c(
            Id = projectRecord.Id,
            Provisioning_Status__c = 'Provisioned',
            External_Provisioning_Id__c = 'PRV-EXISTING'
        );

        Test.startTest();
        System.enqueueJob(new VEChargerProvisioningQueueable(projectRecord.Id));
        Test.stopTest();

        Installation_Project__c actual = [
            SELECT Provisioning_Status__c, External_Provisioning_Id__c, Provisioning_Attempt_Count__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Provisioned', actual.Provisioning_Status__c);
        System.assertEquals('PRV-EXISTING', actual.External_Provisioning_Id__c);
        System.assertEquals(null, actual.Provisioning_Attempt_Count__c);
    }

    @IsTest
    static void requestContainsBusinessContract() {
        Installation_Project__c projectRecord = queryProjectForCallout(createProject().Id);

        HttpRequest request = VEChargerProvisioningService.buildRequest(projectRecord);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());

        System.assertEquals(String.valueOf(projectRecord.Id), body.get('salesforceProjectId'));
        System.assertEquals(projectRecord.Name, body.get('projectName'));
        System.assertEquals('VE Provisioning Account', body.get('accountName'));
        System.assertEquals('VE Provisioning Opportunity', body.get('opportunityName'));
        System.assertEquals('Mixed', body.get('solutionType'));
        System.assertEquals(String.valueOf(projectRecord.Id), request.getHeader('Idempotency-Key'));
    }

    @IsTest
    static void serviceRejectsMissingProject() {
        Test.startTest();
        try {
            VEChargerProvisioningService.provision(null);
            System.assert(false, 'Expected IllegalArgumentException.');
        } catch (IllegalArgumentException expectedException) {
            System.assert(expectedException.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void invocableQueuesProject() {
        Installation_Project__c projectRecord = createProject();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        VEChargerProvisioningAction.Request request = new VEChargerProvisioningAction.Request();
        request.projectId = projectRecord.Id;

        List<VEChargerProvisioningAction.Response> responses;
        Test.startTest();
        responses = VEChargerProvisioningAction.submit(
            new List<VEChargerProvisioningAction.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('Queued', responses[0].status);
        System.assertNotEquals(null, responses[0].jobId);

        Installation_Project__c actual = [
            SELECT Provisioning_Status__c, External_Provisioning_Id__c
            FROM Installation_Project__c
            WHERE Id = :projectRecord.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Provisioned', actual.Provisioning_Status__c);
        System.assertEquals('PRV-10482', actual.External_Provisioning_Id__c);
    }

    @IsTest
    static void invocableHandlesEmptyMissingAndAlreadyProvisionedInputs() {
        System.assertEquals(0, VEChargerProvisioningAction.submit(null).size());
        System.assertEquals(
            0,
            VEChargerProvisioningAction.submit(new List<VEChargerProvisioningAction.Request>()).size()
        );

        VEChargerProvisioningAction.Request missingRequest =
            new VEChargerProvisioningAction.Request();
        List<VEChargerProvisioningAction.Response> missingResponses =
            VEChargerProvisioningAction.submit(
                new List<VEChargerProvisioningAction.Request>{ missingRequest }
            );
        System.assertEquals('Missing Project Id', missingResponses[0].status);

        Installation_Project__c projectRecord = createProject();
        update as system new Installation_Project__c(
            Id = projectRecord.Id,
            Provisioning_Status__c = 'Provisioned',
            External_Provisioning_Id__c = 'PRV-EXISTING'
        );

        VEChargerProvisioningAction.Request provisionedRequest =
            new VEChargerProvisioningAction.Request();
        provisionedRequest.projectId = projectRecord.Id;
        List<VEChargerProvisioningAction.Response> provisionedResponses =
            VEChargerProvisioningAction.submit(
                new List<VEChargerProvisioningAction.Request>{ provisionedRequest }
            );
        System.assertEquals('Already Provisioned', provisionedResponses[0].status);
        System.assertEquals(null, provisionedResponses[0].jobId);
    }
}
