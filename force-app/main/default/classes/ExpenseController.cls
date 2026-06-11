public without sharing class ExpenseController {

    // Wrapper class for Line Item
    public class LineItemWrapper {
        @AuraEnabled public String category;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String description;
    }

    // Get Expense History
    @AuraEnabled(cacheable=false)
    public static List<Expense__c> getExpenses() {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null)
                return new List<Expense__c>();

            return [
                SELECT
                    Id,
                    Name,
                    Claim_Title__c,
                    Expense_Date__c,
                    Total_Amount__c,
                    Status__c,
                    Remarks__c,
                    Reimbursement_Date__c
                FROM Expense__c
                WHERE Employee__c = :emp.Id
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            return new List<Expense__c>();
        }
    }

    // Get Line Items for an Expense
    @AuraEnabled(cacheable=false)
    public static List<Expense_Line_Item__c>
        getLineItems(String expenseId) {
        try {
            return [
                SELECT
                    Id,
                    Expense_Category__c,
                    Amount__c,
                    Description__c,
                    Expense_Date__c
                FROM Expense_Line_Item__c
                WHERE Expense__c = :expenseId
            ];
        } catch(Exception e) {
            return new List<Expense_Line_Item__c>();
        }
    }

    // Create Expense with Line Items (WITHOUT file attachment)
    @AuraEnabled
    public static String createExpense(
        String claimTitle,
        String expenseDate,
        String remarks,
        String lineItemsJson
    ) {
        Employee__c emp = getCurrentEmployee();
        if(emp == null)
            throw new AuraHandledException(
                'Employee record not found');

        // Validate
        if(String.isBlank(claimTitle))
            throw new AuraHandledException(
                'Claim title is required');

        if(String.isBlank(expenseDate))
            throw new AuraHandledException(
                'Expense date is required');

        // Parse Line Items
        List<LineItemWrapper> lineItems =
            (List<LineItemWrapper>)
            JSON.deserialize(
                lineItemsJson,
                List<LineItemWrapper>.class
            );

        if(lineItems == null || lineItems.isEmpty())
            throw new AuraHandledException(
                'At least one line item is required');

        // Calculate Total
        Decimal total = 0;
        for(LineItemWrapper item : lineItems) {
            if(item.amount == null || item.amount <= 0)
                throw new AuraHandledException(
                    'Amount must be greater than 0');
            if(String.isBlank(item.category))
                throw new AuraHandledException(
                    'Category is required for all line items');
            total += item.amount;
        }

        // Create Expense
        Expense__c exp = new Expense__c();
        exp.Employee__c = emp.Id;
        exp.Claim_Title__c = claimTitle;
        exp.Expense_Date__c = Date.valueOf(expenseDate);
        exp.Remarks__c = remarks;
        exp.Status__c = 'Draft';

        insert exp;

        // Create Line Items
        List<Expense_Line_Item__c> items =
            new List<Expense_Line_Item__c>();

        for(LineItemWrapper item : lineItems) {
            Expense_Line_Item__c li =
                new Expense_Line_Item__c();
            li.Expense__c = exp.Id;
            li.Expense_Category__c = item.category;
            li.Amount__c = item.amount;
            li.Description__c = item.description;
            li.Expense_Date__c =
                Date.valueOf(expenseDate);
            items.add(li);
        }

        insert items;

        return exp.Id;
    }

    // Attach receipt to existing expense
    @AuraEnabled
    public static void attachReceiptToExpense(
        String expenseId,
        String contentDocumentId
    ) {
        try {
            // Verify expense exists and belongs to current user
            List<Expense__c> expenses = [
                SELECT Id, Employee__c
                FROM Expense__c
                WHERE Id = :expenseId
                LIMIT 1
            ];

            if(expenses.isEmpty())
                throw new AuraHandledException('Expense not found');

            Employee__c emp = getCurrentEmployee();
            if(emp == null || expenses[0].Employee__c != emp.Id)
                throw new AuraHandledException('Unauthorized access to expense');

            // Link Receipt to Expense only if not already linked
            List<ContentDocumentLink> existingLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
                AND LinkedEntityId = :expenseId
                LIMIT 1
            ];

            if(existingLinks.isEmpty()) {
                ContentDocumentLink cdl =
                    new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocumentId;
                cdl.LinkedEntityId = expenseId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }

            // Update Expense status to Submitted
            expenses[0].Status__c = 'Submitted';
            expenses[0].Receipt_Attached__c = true;
            update expenses[0];

        } catch(DmlException de) {
            System.debug('ERROR linking receipt: ' + de.getMessage());
            throw new AuraHandledException('Failed to attach receipt: ' + de.getMessage());
        }
    }

    // Cancel Expense
    @AuraEnabled
    public static void cancelExpense(
        String expenseId
    ) {
        List<Expense__c> expenses = [
            SELECT Id, Status__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];

        if(expenses.isEmpty())
            throw new AuraHandledException(
                'Expense not found');

        if(expenses[0].Status__c != 'Draft' &&
           expenses[0].Status__c != 'Submitted')
            throw new AuraHandledException(
                'Cannot cancel this expense');

        expenses[0].Status__c = 'Cancelled';
        update expenses[0];
    }

    // Get Current Employee
    private static Employee__c getCurrentEmployee() {
        try {
            Id userId = UserInfo.getUserId();
            List<Employee__c> emps = [
                SELECT Id
                FROM Employee__c
                WHERE User__c = :userId
                AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if(emps.isEmpty()) {
                System.debug('ERROR: No Employee record found for User: ' + userId);
                return null;
            }
            
            return emps[0];
        } catch(QueryException qe) {
            System.debug('ERROR in getCurrentEmployee QueryException: ' + qe.getMessage());
            throw new AuraHandledException('Database error: ' + qe.getMessage());
        } catch(Exception e) {
            System.debug('ERROR in getCurrentEmployee: ' + e.getMessage());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
    
    // Get Receipt URL for Expense
    @AuraEnabled(cacheable=true)
    public static String getReceiptUrl(
        String expenseId
    ) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :expenseId
                LIMIT 1
            ];

            if(links.isEmpty()) return null;

            List<ContentVersion> versions = [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId =
                    :links[0].ContentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];

            if(versions.isEmpty()) return null;

            return '/sfc/servlet.shepherd/version/download/'
                + versions[0].Id;
        } catch(Exception e) {
            return null;
        }
    }
}