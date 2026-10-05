public with sharing class VEChargerProvisioningService {
    private static final String ENDPOINT = 'callout:VE_Charger_Provisioning/v1/installations';

    public class RequestPayload {
        public String salesforceProjectId;
        public String projectName;
        public String accountId;
        public String accountName;
        public String opportunityId;
        public String opportunityName;
        public Decimal numberOfSites;
        public Decimal numberOfChargers;
        public String solutionType;
        public String targetGoLiveDate;
    }

    public class ResponsePayload {
        public String provisioningId;
        public String status;
        public String message;
    }

    public class CalloutResult {
        public Integer statusCode;
        public Boolean success;
        public Boolean retryable;
        public String responseBody;
        public String errorMessage;
        public ResponsePayload response;
    }

    public static CalloutResult provision(Installation_Project__c projectRecord) {
        if (projectRecord == null || projectRecord.Id == null) {
            throw new IllegalArgumentException('Installation Project is required.');
        }

        CalloutResult result = new CalloutResult();

        try {
            HttpRequest request = buildRequest(projectRecord);
            HttpResponse response = new Http().send(request);

            result.statusCode = response.getStatusCode();
            result.responseBody = response.getBody();
            result.retryable = result.statusCode == 429 || result.statusCode >= 500;
            result.success = result.statusCode == 200 || result.statusCode == 201;

            if (result.success) {
                try {
                    result.response = (ResponsePayload) JSON.deserialize(
                        result.responseBody,
                        ResponsePayload.class
                    );
                } catch (Exception parsingException) {
                    result.success = false;
                    result.retryable = false;
                    result.errorMessage = 'Provisioning API returned invalid JSON: ' + parsingException.getMessage();
                    return result;
                }

                if (result.response == null || String.isBlank(result.response.provisioningId)) {
                    result.success = false;
                    result.retryable = false;
                    result.errorMessage = 'Provisioning API response did not contain provisioningId.';
                }
            } else {
                result.errorMessage = buildHttpError(result.statusCode, result.responseBody);
            }
        } catch (CalloutException calloutException) {
            result.success = false;
            result.retryable = true;
            result.errorMessage = 'Callout failed: ' + calloutException.getMessage();
        }

        return result;
    }

    @TestVisible
    private static HttpRequest buildRequest(Installation_Project__c projectRecord) {
        RequestPayload payload = new RequestPayload();
        payload.salesforceProjectId = String.valueOf(projectRecord.Id);
        payload.projectName = projectRecord.Name;
        payload.accountId = projectRecord.Account__c == null ? null : String.valueOf(projectRecord.Account__c);
        payload.accountName = projectRecord.Account__r == null ? null : projectRecord.Account__r.Name;
        payload.opportunityId = projectRecord.Opportunity__c == null ? null : String.valueOf(projectRecord.Opportunity__c);
        payload.opportunityName = projectRecord.Opportunity__r == null ? null : projectRecord.Opportunity__r.Name;
        payload.numberOfSites = projectRecord.Number_of_Sites__c;
        payload.numberOfChargers = projectRecord.Number_of_Chargers__c;
        payload.solutionType = projectRecord.Solution_Type__c;
        payload.targetGoLiveDate = projectRecord.Target_Go_Live_Date__c == null
            ? null
            : String.valueOf(projectRecord.Target_Go_Live_Date__c);

        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(ENDPOINT);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Idempotency-Key', String.valueOf(projectRecord.Id));
        request.setTimeout(20000);
        request.setBody(JSON.serialize(payload));
        return request;
    }

    private static String buildHttpError(Integer statusCode, String responseBody) {
        String body = String.isBlank(responseBody) ? '[empty response]' : responseBody;
        return 'Provisioning API returned HTTP ' + statusCode + ': ' + body;
    }
}
