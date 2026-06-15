@isTest
public class ExpenseControllerTest {

    @isTest
    static void testExpenseFlow() {
        User u = TestDataFactory.createTestUser('Standard User', 'ExpUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');

        System.runAs(u) {
            Test.startTest();
            // 1. Create JSON for line items
            List<Map<String, Object>> wrappers = new List<Map<String, Object>>();
            Map<String, Object> w = new Map<String, Object>();
            w.put('category', 'Travel');
            w.put('amount', 500);
            w.put('description', 'Flight');
            wrappers.add(w);
            String jsonStr = JSON.serialize(wrappers);

            // 2. Create Expense
            String expId = ExpenseController.createExpense(
                'Business Trip', 
                String.valueOf(Date.today()), 
                'Going to NY', 
                jsonStr
            );
            Assert.isNotNull(expId);

            // 3. Get Expenses
            List<Expense__c> expenses = ExpenseController.getExpenses();
            Assert.areEqual(1, expenses.size());

            // 4. Get Line Items
            List<Expense_Line_Item__c> items = ExpenseController.getLineItems(expId);
            Assert.areEqual(1, items.size());

            // 5. Cancel Expense
            ExpenseController.cancelExpense(expId);
            expenses = ExpenseController.getExpenses();
            Assert.areEqual('Cancelled', expenses[0].Status__c);
            
            // 6. Get Receipt URL
            ExpenseController.getReceiptUrl(items[0].Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testDeleteDraft() {
        User u = TestDataFactory.createTestUser('Standard User', 'ExpUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        Expense__c exp = TestDataFactory.createExpense(emp.Id, 'Draft Exp');

        System.runAs(u) {
            ExpenseController.deleteDraftExpense(exp.Id);
            List<Expense__c> expenses = [SELECT Id FROM Expense__c WHERE Id = :exp.Id];
            Assert.isTrue(expenses.isEmpty());
        }
    }
    
    @isTest
    static void testExpenseExceptions() {
        User u = TestDataFactory.createTestUser('Standard User', 'ExpUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');

        System.runAs(u) {
            // Invalid JSON
            try {
                ExpenseController.createExpense('Title', '2023-01-01', 'Desc', 'invalid json');
            } catch(Exception e) {}
            
            // Not found cancel
            try {
                ExpenseController.cancelExpense(emp.Id);
            } catch(Exception e) {}
        }
    }
}
