@isTest
public class LeaveControllerTest {

    @isTest
    static void testLeaveFlow() {
        User hrUser = TestDataFactory.createTestUser('Standard User', 'HRUser');
        Employee__c hrEmp = TestDataFactory.createEmployee(hrUser.Id, 'Head HR');
        Department__c dept = TestDataFactory.createDepartment('IT', hrEmp.Id);
        
        // HOD is also in the department
        hrEmp.Department__c = dept.Id;
        update hrEmp;

        User u = TestDataFactory.createTestUser('Standard User', 'LeaveUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        emp.Manager__c = hrEmp.Id;
        update emp;
        
        TestDataFactory.createLeaveBalance(emp.Id);

        System.runAs(u) {
            Test.startTest();
            // 1. Get balance
            Leave_Balance__c lb = LeaveController.getLeaveBalance();
            Assert.isNotNull(lb);

            // 2. Apply leave (Sick)
            LeaveController.applyLeave(
                'Sick', 
                String.valueOf(Date.today().addDays(5)), 
                String.valueOf(Date.today().addDays(5)), 
                'Flu'
            );

            // 3. Get requests
            List<Leave_Request__c> requests = LeaveController.getLeaveRequests();
            Assert.areEqual(1, requests.size());

            // 4. Cancel leave
            LeaveController.cancelLeave(requests[0].Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testDeductBalanceAllTypes() {
        User hrUser = TestDataFactory.createTestUser('Standard User', 'HRUser');
        Employee__c hrEmp = TestDataFactory.createEmployee(hrUser.Id, 'Head HR');
        Department__c dept = TestDataFactory.createDepartment('IT', hrEmp.Id);
        hrEmp.Department__c = dept.Id;
        update hrEmp;

        User u = TestDataFactory.createTestUser('Standard User', 'LeaveUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        emp.Manager__c = hrEmp.Id;
        update emp;

        TestDataFactory.createLeaveBalance(emp.Id);
        
        // PTO
        Leave_Request__c lr1 = TestDataFactory.createLeaveRequest(emp.Id, 'Paid Time Off', Date.today().addDays(1), Date.today().addDays(1));
        lr1.Status__c = 'Approved';
        update lr1;

        Test.startTest();
        LeaveController.deductLeaveBalance(new List<String>{lr1.Id});
        Test.stopTest();

        Leave_Balance__c lb = [SELECT PTO_Used__c FROM Leave_Balance__c WHERE Employee_Leaves__c = :emp.Id LIMIT 1];
        Assert.areEqual(1, lb.PTO_Used__c);
    }
}
