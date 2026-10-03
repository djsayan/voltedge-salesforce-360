List<QuoteLineItem> lines = [
    SELECT
        Id,
        PricebookEntryId,
        PricebookEntry.UnitPrice,
        Approval_Basis_Unit_Price__c
    FROM QuoteLineItem
    WHERE Approval_Basis_Unit_Price__c = NULL
    AND PricebookEntryId != NULL
];

System.debug('Lines to backfill: ' + lines.size());

for (QuoteLineItem line : lines) {
    line.Approval_Basis_Unit_Price__c =
        line.PricebookEntry.UnitPrice;

    System.debug(
        'Backfill ' + line.Id +
        ' -> Basis=' + line.Approval_Basis_Unit_Price__c
    );
}

Database.SaveResult[] results =
    Database.update(lines, false);

for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        System.debug(
            'SUCCESS | ' + lines[i].Id
        );
    } else {
        for (Database.Error error : results[i].getErrors()) {
            System.debug(
                'FAILED | ' + lines[i].Id +
                ' | ' + error.getMessage()
            );
        }
    }
}