/*==============================================================================
02_BRONZE / 04_SAMPLE_DATA
Synthetic sample data for offline demo mode (no QBO credentials needed).
Intentionally includes quality issues so DMFs light up:
  - NULL customer_id on invoice INV-007
  - Duplicate invoice ID (INV-003 appears twice)
  - Negative amount on INV-008
  - due_date < txn_date on INV-009
  - Orphan customer_id on INV-010 (references non-existent customer)
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- Customers
-------------------------------------------------------------------------------
INSERT INTO RAW_CUSTOMER (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "DisplayName": "Acme Corp",
    "CompanyName": "Acme Corporation",
    "PrimaryEmailAddr": {"Address": "billing@acme.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 100-1001"},
    "BillAddr": {"Line1": "100 Main St", "City": "San Francisco", "CountrySubDivisionCode": "CA", "PostalCode": "94105"},
    "Balance": 4500.00,
    "MetaData": {"CreateTime": "2025-06-15T10:00:00", "LastUpdatedTime": "2026-01-20T08:30:00"}
}'), '/v3/company/sample/query?query=Customer'),
('2', PARSE_JSON('{
    "Id": "2", "DisplayName": "Globex Industries",
    "CompanyName": "Globex Industries Inc",
    "PrimaryEmailAddr": {"Address": "ap@globex.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 200-2002"},
    "BillAddr": {"Line1": "200 Oak Ave", "City": "Austin", "CountrySubDivisionCode": "TX", "PostalCode": "73301"},
    "Balance": 12750.00,
    "MetaData": {"CreateTime": "2025-03-01T09:00:00", "LastUpdatedTime": "2026-02-10T14:00:00"}
}'), '/v3/company/sample/query?query=Customer'),
('3', PARSE_JSON('{
    "Id": "3", "DisplayName": "Initech LLC",
    "CompanyName": "Initech LLC",
    "PrimaryEmailAddr": {"Address": "peter@initech.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 300-3003"},
    "BillAddr": {"Line1": "300 Elm St", "City": "Chicago", "CountrySubDivisionCode": "IL", "PostalCode": "60601"},
    "Balance": 0.00,
    "MetaData": {"CreateTime": "2025-09-10T11:00:00", "LastUpdatedTime": "2025-12-05T16:45:00"}
}'), '/v3/company/sample/query?query=Customer'),
('4', PARSE_JSON('{
    "Id": "4", "DisplayName": "Stark Enterprises",
    "CompanyName": "Stark Enterprises",
    "PrimaryEmailAddr": {"Address": "finance@stark.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 400-4004"},
    "BillAddr": {"Line1": "400 Park Blvd", "City": "New York", "CountrySubDivisionCode": "NY", "PostalCode": "10001"},
    "Balance": 28000.00,
    "MetaData": {"CreateTime": "2025-01-15T08:00:00", "LastUpdatedTime": "2026-02-25T09:15:00"}
}'), '/v3/company/sample/query?query=Customer'),
('5', PARSE_JSON('{
    "Id": "5", "DisplayName": "Wayne Corp",
    "CompanyName": "Wayne Corporation",
    "PrimaryEmailAddr": {"Address": "accounts@wayne.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 500-5005"},
    "BillAddr": {"Line1": "500 Gotham Way", "City": "Gotham", "CountrySubDivisionCode": "NJ", "PostalCode": "07001"},
    "Balance": 1200.00,
    "MetaData": {"CreateTime": "2025-07-20T13:30:00", "LastUpdatedTime": "2026-01-10T11:00:00"}
}'), '/v3/company/sample/query?query=Customer');

-------------------------------------------------------------------------------
-- Vendors
-------------------------------------------------------------------------------
INSERT INTO RAW_VENDOR (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "DisplayName": "Office Supplies Co",
    "CompanyName": "Office Supplies Co",
    "PrimaryEmailAddr": {"Address": "sales@officesupplies.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 600-6001"},
    "Balance": 3200.00,
    "MetaData": {"CreateTime": "2025-04-01T09:00:00", "LastUpdatedTime": "2026-01-15T10:00:00"}
}'), '/v3/company/sample/query?query=Vendor'),
('2', PARSE_JSON('{
    "Id": "2", "DisplayName": "Cloud Hosting Inc",
    "CompanyName": "Cloud Hosting Inc",
    "PrimaryEmailAddr": {"Address": "billing@cloudhosting.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 700-7002"},
    "Balance": 8500.00,
    "MetaData": {"CreateTime": "2025-02-15T08:30:00", "LastUpdatedTime": "2026-02-01T14:30:00"}
}'), '/v3/company/sample/query?query=Vendor'),
('3', PARSE_JSON('{
    "Id": "3", "DisplayName": "Legal Eagles LLP",
    "CompanyName": "Legal Eagles LLP",
    "PrimaryEmailAddr": {"Address": "invoices@legaleagles.com"},
    "PrimaryPhone": {"FreeFormNumber": "(555) 800-8003"},
    "Balance": 15000.00,
    "MetaData": {"CreateTime": "2025-06-01T10:00:00", "LastUpdatedTime": "2025-12-20T09:00:00"}
}'), '/v3/company/sample/query?query=Vendor');

-------------------------------------------------------------------------------
-- Items (products/services sold)
-------------------------------------------------------------------------------
INSERT INTO RAW_ITEM (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "Name": "Consulting - Hourly",
    "Type": "Service",
    "UnitPrice": 250.00,
    "IncomeAccountRef": {"value": "1", "name": "Services Revenue"},
    "Active": true,
    "MetaData": {"CreateTime": "2025-01-10T08:00:00", "LastUpdatedTime": "2025-06-15T10:00:00"}
}'), '/v3/company/sample/query?query=Item'),
('2', PARSE_JSON('{
    "Id": "2", "Name": "Software License - Annual",
    "Type": "Service",
    "UnitPrice": 12000.00,
    "IncomeAccountRef": {"value": "1", "name": "Services Revenue"},
    "Active": true,
    "MetaData": {"CreateTime": "2025-01-10T08:00:00", "LastUpdatedTime": "2025-08-20T14:00:00"}
}'), '/v3/company/sample/query?query=Item'),
('3', PARSE_JSON('{
    "Id": "3", "Name": "Training Workshop",
    "Type": "Service",
    "UnitPrice": 5000.00,
    "IncomeAccountRef": {"value": "1", "name": "Services Revenue"},
    "Active": true,
    "MetaData": {"CreateTime": "2025-03-01T09:00:00", "LastUpdatedTime": "2025-09-10T11:30:00"}
}'), '/v3/company/sample/query?query=Item'),
('4', PARSE_JSON('{
    "Id": "4", "Name": "Hardware - Server",
    "Type": "Inventory",
    "UnitPrice": 8500.00,
    "QtyOnHand": 12,
    "IncomeAccountRef": {"value": "2", "name": "Product Revenue"},
    "Active": true,
    "MetaData": {"CreateTime": "2025-05-01T10:00:00", "LastUpdatedTime": "2026-01-05T08:00:00"}
}'), '/v3/company/sample/query?query=Item');

-------------------------------------------------------------------------------
-- Accounts (chart of accounts)
-------------------------------------------------------------------------------
INSERT INTO RAW_ACCOUNT (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "Name": "Services Revenue",
    "AccountType": "Income", "AccountSubType": "ServiceFeeIncome",
    "CurrentBalance": 285000.00, "Active": true,
    "MetaData": {"CreateTime": "2025-01-01T00:00:00", "LastUpdatedTime": "2026-02-27T00:00:00"}
}'), '/v3/company/sample/query?query=Account'),
('2', PARSE_JSON('{
    "Id": "2", "Name": "Product Revenue",
    "AccountType": "Income", "AccountSubType": "SalesOfProductIncome",
    "CurrentBalance": 68000.00, "Active": true,
    "MetaData": {"CreateTime": "2025-01-01T00:00:00", "LastUpdatedTime": "2026-02-27T00:00:00"}
}'), '/v3/company/sample/query?query=Account'),
('3', PARSE_JSON('{
    "Id": "3", "Name": "Accounts Receivable",
    "AccountType": "Accounts Receivable", "AccountSubType": "AccountsReceivable",
    "CurrentBalance": 46450.00, "Active": true,
    "MetaData": {"CreateTime": "2025-01-01T00:00:00", "LastUpdatedTime": "2026-02-27T00:00:00"}
}'), '/v3/company/sample/query?query=Account'),
('4', PARSE_JSON('{
    "Id": "4", "Name": "Accounts Payable",
    "AccountType": "Accounts Payable", "AccountSubType": "AccountsPayable",
    "CurrentBalance": 26700.00, "Active": true,
    "MetaData": {"CreateTime": "2025-01-01T00:00:00", "LastUpdatedTime": "2026-02-27T00:00:00"}
}'), '/v3/company/sample/query?query=Account'),
('5', PARSE_JSON('{
    "Id": "5", "Name": "Operating Expenses",
    "AccountType": "Expense", "AccountSubType": "OfficeGeneralAdministrativeExpenses",
    "CurrentBalance": 42000.00, "Active": true,
    "MetaData": {"CreateTime": "2025-01-01T00:00:00", "LastUpdatedTime": "2026-02-27T00:00:00"}
}'), '/v3/company/sample/query?query=Account');

-------------------------------------------------------------------------------
-- Invoices (with intentional quality issues marked with --DQ)
-------------------------------------------------------------------------------
INSERT INTO RAW_INVOICE (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "DocNumber": "INV-001",
    "CustomerRef": {"value": "1", "name": "Acme Corp"},
    "TxnDate": "2025-12-01", "DueDate": "2025-12-31",
    "TotalAmt": 15000.00, "Balance": 0.00,
    "PrivateNote": "Urgent - client needs delivery by end of month. Very satisfied with our service so far.",
    "Line": [
        {"Id": "1", "Amount": 10000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 40, "UnitPrice": 250.00}},
        {"Id": "2", "Amount": 5000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "3"}, "Qty": 1, "UnitPrice": 5000.00}}
    ],
    "MetaData": {"CreateTime": "2025-12-01T09:00:00", "LastUpdatedTime": "2026-01-05T10:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),
('2', PARSE_JSON('{
    "Id": "2", "DocNumber": "INV-002",
    "CustomerRef": {"value": "2", "name": "Globex Industries"},
    "TxnDate": "2026-01-15", "DueDate": "2026-02-14",
    "TotalAmt": 12750.00, "Balance": 12750.00,
    "PrivateNote": "Renewal invoice. Customer has expressed concerns about pricing increase.",
    "Line": [
        {"Id": "1", "Amount": 12000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "2"}, "Qty": 1, "UnitPrice": 12000.00}},
        {"Id": "2", "Amount": 750.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 3, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-01-15T11:00:00", "LastUpdatedTime": "2026-01-15T11:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),
('3', PARSE_JSON('{
    "Id": "3", "DocNumber": "INV-003",
    "CustomerRef": {"value": "4", "name": "Stark Enterprises"},
    "TxnDate": "2026-01-20", "DueDate": "2026-02-19",
    "TotalAmt": 28000.00, "Balance": 28000.00,
    "PrivateNote": "Large hardware order. Customer wants net-30 terms.",
    "Line": [
        {"Id": "1", "Amount": 25500.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "4"}, "Qty": 3, "UnitPrice": 8500.00}},
        {"Id": "2", "Amount": 2500.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 10, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-01-20T14:00:00", "LastUpdatedTime": "2026-01-22T09:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),
('4', PARSE_JSON('{
    "Id": "4", "DocNumber": "INV-004",
    "CustomerRef": {"value": "3", "name": "Initech LLC"},
    "TxnDate": "2025-10-01", "DueDate": "2025-10-31",
    "TotalAmt": 5000.00, "Balance": 0.00,
    "PrivateNote": "Training completed successfully. Client team was very engaged.",
    "Line": [
        {"Id": "1", "Amount": 5000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "3"}, "Qty": 1, "UnitPrice": 5000.00}}
    ],
    "MetaData": {"CreateTime": "2025-10-01T09:00:00", "LastUpdatedTime": "2025-11-02T08:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),
('5', PARSE_JSON('{
    "Id": "5", "DocNumber": "INV-005",
    "CustomerRef": {"value": "5", "name": "Wayne Corp"},
    "TxnDate": "2026-02-01", "DueDate": "2026-03-03",
    "TotalAmt": 1250.00, "Balance": 1200.00,
    "PrivateNote": "Partial payment received. Follow up needed.",
    "Line": [
        {"Id": "1", "Amount": 1250.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 5, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-01T10:00:00", "LastUpdatedTime": "2026-02-15T14:30:00"}
}'), '/v3/company/sample/query?query=Invoice'),
('6', PARSE_JSON('{
    "Id": "6", "DocNumber": "INV-006",
    "CustomerRef": {"value": "1", "name": "Acme Corp"},
    "TxnDate": "2026-02-10", "DueDate": "2026-03-12",
    "TotalAmt": 4500.00, "Balance": 4500.00,
    "PrivateNote": "Follow-up consulting engagement. Client expanding scope.",
    "Line": [
        {"Id": "1", "Amount": 4500.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 18, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-10T09:00:00", "LastUpdatedTime": "2026-02-10T09:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),

-- DQ ISSUE: NULL customer reference
('7', PARSE_JSON('{
    "Id": "7", "DocNumber": "INV-007",
    "TxnDate": "2026-02-15", "DueDate": "2026-03-17",
    "TotalAmt": 3000.00, "Balance": 3000.00,
    "PrivateNote": "Missing customer ref - data entry error.",
    "Line": [
        {"Id": "1", "Amount": 3000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 12, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-15T11:00:00", "LastUpdatedTime": "2026-02-15T11:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),

-- DQ ISSUE: Duplicate ID (INV-003 again with different data)
('3', PARSE_JSON('{
    "Id": "3", "DocNumber": "INV-003-DUP",
    "CustomerRef": {"value": "4", "name": "Stark Enterprises"},
    "TxnDate": "2026-01-20", "DueDate": "2026-02-19",
    "TotalAmt": 28000.00, "Balance": 28000.00,
    "PrivateNote": "Duplicate record from sync glitch.",
    "Line": [
        {"Id": "1", "Amount": 28000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "4"}, "Qty": 3, "UnitPrice": 8500.00}}
    ],
    "MetaData": {"CreateTime": "2026-01-20T14:00:00", "LastUpdatedTime": "2026-01-20T14:05:00"}
}'), '/v3/company/sample/query?query=Invoice'),

-- DQ ISSUE: Negative amount
('8', PARSE_JSON('{
    "Id": "8", "DocNumber": "INV-008",
    "CustomerRef": {"value": "2", "name": "Globex Industries"},
    "TxnDate": "2026-02-20", "DueDate": "2026-03-22",
    "TotalAmt": -500.00, "Balance": -500.00,
    "PrivateNote": "Credit memo entered as invoice by mistake.",
    "Line": [
        {"Id": "1", "Amount": -500.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": -2, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-20T15:00:00", "LastUpdatedTime": "2026-02-20T15:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),

-- DQ ISSUE: due_date < txn_date
('9', PARSE_JSON('{
    "Id": "9", "DocNumber": "INV-009",
    "CustomerRef": {"value": "5", "name": "Wayne Corp"},
    "TxnDate": "2026-02-25", "DueDate": "2026-01-25",
    "TotalAmt": 2000.00, "Balance": 2000.00,
    "PrivateNote": "Due date set incorrectly, needs correction.",
    "Line": [
        {"Id": "1", "Amount": 2000.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "1"}, "Qty": 8, "UnitPrice": 250.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-25T09:00:00", "LastUpdatedTime": "2026-02-25T09:00:00"}
}'), '/v3/company/sample/query?query=Invoice'),

-- DQ ISSUE: Orphan customer_id (customer 99 does not exist)
('10', PARSE_JSON('{
    "Id": "10", "DocNumber": "INV-010",
    "CustomerRef": {"value": "99", "name": "Unknown Customer"},
    "TxnDate": "2026-02-26", "DueDate": "2026-03-28",
    "TotalAmt": 7500.00, "Balance": 7500.00,
    "PrivateNote": "Customer record missing from QBO sync.",
    "Line": [
        {"Id": "1", "Amount": 7500.00, "DetailType": "SalesItemLineDetail",
         "SalesItemLineDetail": {"ItemRef": {"value": "2"}, "Qty": 1, "UnitPrice": 7500.00}}
    ],
    "MetaData": {"CreateTime": "2026-02-26T08:00:00", "LastUpdatedTime": "2026-02-26T08:00:00"}
}'), '/v3/company/sample/query?query=Invoice');

-------------------------------------------------------------------------------
-- Payments
-------------------------------------------------------------------------------
INSERT INTO RAW_PAYMENT (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "TotalAmt": 15000.00,
    "CustomerRef": {"value": "1", "name": "Acme Corp"},
    "TxnDate": "2025-12-28",
    "Line": [{"Amount": 15000.00, "LinkedTxn": [{"TxnId": "1", "TxnType": "Invoice"}]}],
    "MetaData": {"CreateTime": "2025-12-28T10:00:00", "LastUpdatedTime": "2025-12-28T10:00:00"}
}'), '/v3/company/sample/query?query=Payment'),
('2', PARSE_JSON('{
    "Id": "2", "TotalAmt": 5000.00,
    "CustomerRef": {"value": "3", "name": "Initech LLC"},
    "TxnDate": "2025-10-28",
    "Line": [{"Amount": 5000.00, "LinkedTxn": [{"TxnId": "4", "TxnType": "Invoice"}]}],
    "MetaData": {"CreateTime": "2025-10-28T09:00:00", "LastUpdatedTime": "2025-10-28T09:00:00"}
}'), '/v3/company/sample/query?query=Payment'),
('3', PARSE_JSON('{
    "Id": "3", "TotalAmt": 50.00,
    "CustomerRef": {"value": "5", "name": "Wayne Corp"},
    "TxnDate": "2026-02-10",
    "Line": [{"Amount": 50.00, "LinkedTxn": [{"TxnId": "5", "TxnType": "Invoice"}]}],
    "MetaData": {"CreateTime": "2026-02-10T14:00:00", "LastUpdatedTime": "2026-02-10T14:00:00"}
}'), '/v3/company/sample/query?query=Payment');

-------------------------------------------------------------------------------
-- Bills (vendor invoices to us)
-------------------------------------------------------------------------------
INSERT INTO RAW_BILL (qbo_id, raw_payload, api_endpoint) VALUES
('1', PARSE_JSON('{
    "Id": "1", "DocNumber": "BILL-001",
    "VendorRef": {"value": "1", "name": "Office Supplies Co"},
    "TxnDate": "2026-01-05", "DueDate": "2026-02-04",
    "TotalAmt": 3200.00, "Balance": 3200.00,
    "Line": [
        {"Id": "1", "Amount": 2200.00, "DetailType": "AccountBasedExpenseLineDetail",
         "AccountBasedExpenseLineDetail": {"AccountRef": {"value": "5"}}},
        {"Id": "2", "Amount": 1000.00, "DetailType": "AccountBasedExpenseLineDetail",
         "AccountBasedExpenseLineDetail": {"AccountRef": {"value": "5"}}}
    ],
    "MetaData": {"CreateTime": "2026-01-05T09:00:00", "LastUpdatedTime": "2026-01-05T09:00:00"}
}'), '/v3/company/sample/query?query=Bill'),
('2', PARSE_JSON('{
    "Id": "2", "DocNumber": "BILL-002",
    "VendorRef": {"value": "2", "name": "Cloud Hosting Inc"},
    "TxnDate": "2026-02-01", "DueDate": "2026-03-03",
    "TotalAmt": 8500.00, "Balance": 8500.00,
    "Line": [
        {"Id": "1", "Amount": 8500.00, "DetailType": "AccountBasedExpenseLineDetail",
         "AccountBasedExpenseLineDetail": {"AccountRef": {"value": "5"}}}
    ],
    "MetaData": {"CreateTime": "2026-02-01T08:00:00", "LastUpdatedTime": "2026-02-01T08:00:00"}
}'), '/v3/company/sample/query?query=Bill'),
('3', PARSE_JSON('{
    "Id": "3", "DocNumber": "BILL-003",
    "VendorRef": {"value": "3", "name": "Legal Eagles LLP"},
    "TxnDate": "2025-11-15", "DueDate": "2025-12-15",
    "TotalAmt": 15000.00, "Balance": 15000.00,
    "Line": [
        {"Id": "1", "Amount": 15000.00, "DetailType": "AccountBasedExpenseLineDetail",
         "AccountBasedExpenseLineDetail": {"AccountRef": {"value": "5"}}}
    ],
    "MetaData": {"CreateTime": "2025-11-15T10:00:00", "LastUpdatedTime": "2025-11-15T10:00:00"}
}'), '/v3/company/sample/query?query=Bill');
