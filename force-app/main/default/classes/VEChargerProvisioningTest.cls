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
    static void requestContainsBusinessContract() {
        Installation_Project__c seed = createProject();
        Installation_Project__c projectRecord = [
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
                Target_Go_Live_Date__c
            FROM Installation_Project__c
            WHERE Id = :seed.Id
            WITH SYSTEM_MODE
        ];

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
}
