System.debug('=== VoltEdge Quote-to-Cash seed: START ===');

// ---------------------------------------------------------
// 1. Validate required currencies
// ---------------------------------------------------------

Set<String> activeCurrencies = new Set<String>();

for (CurrencyType currencyRecord : [
    SELECT IsoCode, IsActive
    FROM CurrencyType
    WHERE IsoCode IN ('PLN', 'EUR')
]) {
    if (currencyRecord.IsActive) {
        activeCurrencies.add(currencyRecord.IsoCode);
    }
}

if (
    !activeCurrencies.contains('PLN') ||
    !activeCurrencies.contains('EUR')
) {
    throw new IllegalArgumentException(
        'VoltEdge seed requires active PLN and EUR currencies.'
    );
}


// ---------------------------------------------------------
// 2. Products
// ---------------------------------------------------------

List<Product2> desiredProducts = new List<Product2>{

    new Product2(
        Name = 'VE AC Charger 22 kW',
        ProductCode = 'VE-AC22',
        Family = 'Hardware',
        IsActive = true,
        Revenue_Type__c = 'One-Time',
        Power_kW__c = 22,
        Requires_Installation__c = true
    ),

    new Product2(
        Name = 'VE DC Fast Charger 60 kW',
        ProductCode = 'VE-DC60',
        Family = 'Hardware',
        IsActive = true,
        Revenue_Type__c = 'One-Time',
        Power_kW__c = 60,
        Requires_Installation__c = true
    ),

    new Product2(
        Name = 'VE Charge Management Platform',
        ProductCode = 'VE-CMP',
        Family = 'Software',
        IsActive = true,
        Revenue_Type__c = 'Monthly Recurring',
        Default_Term_Months__c = 36,
        Requires_Installation__c = false
    ),

    new Product2(
        Name = 'VE Care Premium',
        ProductCode = 'VE-CARE-PREM',
        Family = 'Maintenance',
        IsActive = true,
        Revenue_Type__c = 'Annual Recurring',
        Default_Term_Months__c = 36,
        Requires_Installation__c = false
    )
};

Set<String> productCodes = new Set<String>();

for (Product2 product : desiredProducts) {
    productCodes.add(product.ProductCode);
}

Map<String, Product2> existingProductsByCode =
    new Map<String, Product2>();

for (Product2 product : [
    SELECT
        Id,
        Name,
        ProductCode,
        Family,
        IsActive,
        Revenue_Type__c,
        Default_Term_Months__c,
        Power_kW__c,
        Requires_Installation__c
    FROM Product2
    WHERE ProductCode IN :productCodes
]) {
    existingProductsByCode.put(product.ProductCode, product);
}

List<Product2> productsToInsert = new List<Product2>();
List<Product2> productsToUpdate = new List<Product2>();

for (Product2 desired : desiredProducts) {

    Product2 existing =
        existingProductsByCode.get(desired.ProductCode);

    if (existing == null) {

        productsToInsert.add(desired);

    } else {

        existing.Name = desired.Name;
        existing.Family = desired.Family;
        existing.IsActive = true;
        existing.Revenue_Type__c =
            desired.Revenue_Type__c;
        existing.Default_Term_Months__c =
            desired.Default_Term_Months__c;
        existing.Power_kW__c =
            desired.Power_kW__c;
        existing.Requires_Installation__c =
            desired.Requires_Installation__c;

        productsToUpdate.add(existing);
    }
}

if (!productsToInsert.isEmpty()) {
    insert productsToInsert;
}

if (!productsToUpdate.isEmpty()) {
    update productsToUpdate;
}


// Re-query so every product has an Id.
Map<String, Product2> productsByCode =
    new Map<String, Product2>();

for (Product2 product : [
    SELECT Id, ProductCode
    FROM Product2
    WHERE ProductCode IN :productCodes
]) {
    productsByCode.put(product.ProductCode, product);
}


// ---------------------------------------------------------
// 3. Price Books
// ---------------------------------------------------------

Pricebook2 standardPriceBook = [
    SELECT Id, IsActive
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
];

if (!standardPriceBook.IsActive) {
    standardPriceBook.IsActive = true;
    update standardPriceBook;
}

Set<String> customPriceBookNames =
    new Set<String>{
        'VoltEdge Poland',
        'VoltEdge Europe'
    };

Map<String, Pricebook2> customPriceBooksByName =
    new Map<String, Pricebook2>();

for (Pricebook2 priceBook : [
    SELECT Id, Name, IsActive
    FROM Pricebook2
    WHERE Name IN :customPriceBookNames
]) {
    customPriceBooksByName.put(
        priceBook.Name,
        priceBook
    );
}

List<Pricebook2> priceBooksToInsert =
    new List<Pricebook2>();

for (String priceBookName : customPriceBookNames) {

    if (!customPriceBooksByName.containsKey(priceBookName)) {

        priceBooksToInsert.add(
            new Pricebook2(
                Name = priceBookName,
                IsActive = true
            )
        );

    } else {

        Pricebook2 existing =
            customPriceBooksByName.get(priceBookName);

        if (!existing.IsActive) {
            existing.IsActive = true;
            update existing;
        }
    }
}

if (!priceBooksToInsert.isEmpty()) {
    insert priceBooksToInsert;
}


// Refresh map after inserts.
customPriceBooksByName.clear();

for (Pricebook2 priceBook : [
    SELECT Id, Name, IsActive
    FROM Pricebook2
    WHERE Name IN :customPriceBookNames
]) {
    customPriceBooksByName.put(
        priceBook.Name,
        priceBook
    );
}


// ---------------------------------------------------------
// 4. Standard prices
// ---------------------------------------------------------

Map<String, Map<String, Decimal>> standardPrices =
    new Map<String, Map<String, Decimal>>{

        'PLN' => new Map<String, Decimal>{
            'VE-AC22'     => 6500,
            'VE-DC60'     => 85000,
            'VE-CMP'      => 65,
            'VE-CARE-PREM'=> 1200
        },

        'EUR' => new Map<String, Decimal>{
            'VE-AC22'     => 1511.63,
            'VE-DC60'     => 19767.44,
            'VE-CMP'      => 15.12,
            'VE-CARE-PREM'=> 279.07
        }
    };

Set<Id> productIds = new Set<Id>();

for (Product2 product : productsByCode.values()) {
    productIds.add(product.Id);
}

Map<String, PricebookEntry> standardEntriesByKey =
    new Map<String, PricebookEntry>();

for (PricebookEntry entry : [
    SELECT
        Id,
        Product2Id,
        CurrencyIsoCode,
        UnitPrice,
        IsActive
    FROM PricebookEntry
    WHERE
        Pricebook2Id = :standardPriceBook.Id
        AND Product2Id IN :productIds
        AND CurrencyIsoCode IN ('PLN', 'EUR')
]) {

    String key =
        String.valueOf(entry.Product2Id) +
        '|' +
        entry.CurrencyIsoCode;

    standardEntriesByKey.put(key, entry);
}

List<PricebookEntry> standardEntriesToInsert =
    new List<PricebookEntry>();

List<PricebookEntry> standardEntriesToUpdate =
    new List<PricebookEntry>();

for (String currencyIsoCode : standardPrices.keySet()) {

    Map<String, Decimal> prices =
        standardPrices.get(currencyIsoCode);

    for (String productCode : prices.keySet()) {

        Product2 product =
            productsByCode.get(productCode);

        Decimal desiredPrice =
            prices.get(productCode);

        String key =
            String.valueOf(product.Id) +
            '|' +
            currencyIsoCode;

        PricebookEntry existing =
            standardEntriesByKey.get(key);

        if (existing == null) {

            standardEntriesToInsert.add(
                new PricebookEntry(
                    Pricebook2Id =
                        standardPriceBook.Id,
                    Product2Id =
                        product.Id,
                    CurrencyIsoCode =
                        currencyIsoCode,
                    UnitPrice =
                        desiredPrice,
                    IsActive =
                        true
                )
            );

        } else {

            existing.UnitPrice = desiredPrice;
            existing.IsActive = true;

            standardEntriesToUpdate.add(existing);
        }
    }
}

if (!standardEntriesToInsert.isEmpty()) {
    insert standardEntriesToInsert;
}

if (!standardEntriesToUpdate.isEmpty()) {
    update standardEntriesToUpdate;
}


// ---------------------------------------------------------
// 5. Regional custom prices
// ---------------------------------------------------------

Pricebook2 polandPriceBook =
    customPriceBooksByName.get('VoltEdge Poland');

Pricebook2 europePriceBook =
    customPriceBooksByName.get('VoltEdge Europe');


Map<String, Decimal> polandPrices =
    new Map<String, Decimal>{
        'VE-AC22'      => 6500,
        'VE-DC60'      => 85000,
        'VE-CMP'       => 65,
        'VE-CARE-PREM' => 1200
    };

Map<String, Decimal> europePrices =
    new Map<String, Decimal>{
        'VE-AC22'      => 1590,
        'VE-DC60'      => 19900,
        'VE-CMP'       => 17,
        'VE-CARE-PREM' => 300
    };


Set<Id> customPriceBookIds =
    new Set<Id>{
        polandPriceBook.Id,
        europePriceBook.Id
    };

Map<String, PricebookEntry> customEntriesByKey =
    new Map<String, PricebookEntry>();

for (PricebookEntry entry : [
    SELECT
        Id,
        Pricebook2Id,
        Product2Id,
        CurrencyIsoCode,
        UnitPrice,
        IsActive,
        UseStandardPrice
    FROM PricebookEntry
    WHERE
        Pricebook2Id IN :customPriceBookIds
        AND Product2Id IN :productIds
]) {

    String key =
        String.valueOf(entry.Pricebook2Id) +
        '|' +
        String.valueOf(entry.Product2Id) +
        '|' +
        entry.CurrencyIsoCode;

    customEntriesByKey.put(key, entry);
}


List<PricebookEntry> customEntriesToInsert =
    new List<PricebookEntry>();

List<PricebookEntry> customEntriesToUpdate =
    new List<PricebookEntry>();


// Poland — PLN only
for (String productCode : polandPrices.keySet()) {

    Product2 product =
        productsByCode.get(productCode);

    String key =
        String.valueOf(polandPriceBook.Id) +
        '|' +
        String.valueOf(product.Id) +
        '|PLN';

    PricebookEntry existing =
        customEntriesByKey.get(key);

    if (existing == null) {

        customEntriesToInsert.add(
            new PricebookEntry(
                Pricebook2Id =
                    polandPriceBook.Id,
                Product2Id =
                    product.Id,
                CurrencyIsoCode =
                    'PLN',
                UnitPrice =
                    polandPrices.get(productCode),
                IsActive =
                    true,
                UseStandardPrice =
                    false
            )
        );

    } else {

        existing.UnitPrice =
            polandPrices.get(productCode);

        existing.IsActive = true;
        existing.UseStandardPrice = false;

        customEntriesToUpdate.add(existing);
    }
}


// Europe — EUR only
for (String productCode : europePrices.keySet()) {

    Product2 product =
        productsByCode.get(productCode);

    String key =
        String.valueOf(europePriceBook.Id) +
        '|' +
        String.valueOf(product.Id) +
        '|EUR';

    PricebookEntry existing =
        customEntriesByKey.get(key);

    if (existing == null) {

        customEntriesToInsert.add(
            new PricebookEntry(
                Pricebook2Id =
                    europePriceBook.Id,
                Product2Id =
                    product.Id,
                CurrencyIsoCode =
                    'EUR',
                UnitPrice =
                    europePrices.get(productCode),
                IsActive =
                    true,
                UseStandardPrice =
                    false
            )
        );

    } else {

        existing.UnitPrice =
            europePrices.get(productCode);

        existing.IsActive = true;
        existing.UseStandardPrice = false;

        customEntriesToUpdate.add(existing);
    }
}


if (!customEntriesToInsert.isEmpty()) {
    insert customEntriesToInsert;
}

if (!customEntriesToUpdate.isEmpty()) {
    update customEntriesToUpdate;
}


System.debug(
    '=== VoltEdge Quote-to-Cash seed: COMPLETE ==='
);

System.debug(
    'Products: ' + productsByCode.size()
);

System.debug(
    'Custom Price Books: ' +
    customPriceBooksByName.size()
);