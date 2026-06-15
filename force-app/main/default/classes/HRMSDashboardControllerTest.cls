@isTest
public class HRMSDashboardControllerTest {

    @isTest
    static void testHRDashboard() {
        User hrUser = TestDataFactory.createTestUser('Standard User', 'HRUser');
        Employee__c hrEmp = TestDataFactory.createEmployee(hrUser.Id, 'Head HR');
        Department__c dept = TestDataFactory.createDepartment('HR Dept', hrEmp.Id);
        hrEmp.Department__c = dept.Id;
        update hrEmp;
        
        User empUser = TestDataFactory.createTestUser('Standard User', 'NormalUser');
        Employee__c emp = TestDataFactory.createEmployee(empUser.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        emp.Manager__c = hrEmp.Id;
        update emp;
        
        TestDataFactory.createAttendance(emp.Id, Date.today());

        System.runAs(hrUser) {
            Test.startTest();
            Map<String, Object> stats = HRMSDashboardController.getDashboardStats();
            Assert.isTrue(stats.containsKey('totalEmployees'));
            HRMSDashboardController.getPendingLeaves();
            HRMSDashboardController.getPendingExpenses();
            Test.stopTest();
        }
    }

    @isTest
    static void testManagerDashboard() {
        User mgrUser = TestDataFactory.createTestUser('Standard User', 'MgrUser');
        Employee__c mgrEmp = TestDataFactory.createEmployee(mgrUser.Id, 'Manager');
        Department__c dept = TestDataFactory.createDepartment('IT', mgrEmp.Id);
        mgrEmp.Department__c = dept.Id;
        update mgrEmp;
        
        User empUser = TestDataFactory.createTestUser('Standard User', 'EmpUser');
        Employee__c emp = TestDataFactory.createEmployee(empUser.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        emp.Manager__c = mgrEmp.Id;
        update emp;

        System.runAs(mgrUser) {
            Test.startTest();
            HRMSDashboardController.getDashboardStats();
            HRMSDashboardController.doCheckIn();
            HRMSDashboardController.doCheckOut();
            HRMSDashboardController.getCurrentEmployeeInfo();
            HRMSDashboardController.getMyLeaves();
            HRMSDashboardController.getMyExpenses();
            HRMSDashboardController.createDraftExpense();
            HRMSDashboardController.getMyEmployees();
            HRMSDashboardController.getTodayAttendance();
            Test.stopTest();
        }
    }

    @isTest
    static void testMiscMethods() {
        User u = TestDataFactory.createTestUser('Standard User', 'MiscUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        Expense__c exp = TestDataFactory.createExpense(emp.Id, 'Report Test');
        
        System.runAs(u) {
            HRMSDashboardController.getApprovalWorkItemId(exp.Id);
        }
    }
}
