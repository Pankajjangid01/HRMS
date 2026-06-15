@isTest
public class EmployeeSharingServiceTest {

    @isTest
    static void testRecalculateSharingViaTrigger() {
        // Setup HOD -> Manager -> Employee
        User hodUser = TestDataFactory.createTestUser('Standard User', 'HODUser');
        Employee__c hodEmp = TestDataFactory.createEmployee(hodUser.Id, 'HOD');
        
        Department__c dept = TestDataFactory.createDepartment('IT', hodEmp.Id);
        
        // Ensure HOD is in the department for validation rules
        hodEmp.Department__c = dept.Id;
        update hodEmp;
        
        User mgrUser = TestDataFactory.createTestUser('Standard User', 'MgrUser');
        Employee__c mgrEmp = TestDataFactory.createEmployee(mgrUser.Id, 'Manager');
        mgrEmp.Department__c = dept.Id;
        update mgrEmp;
        
        Team__c team = TestDataFactory.createTeam('Dev', dept.Id, mgrEmp.Id);
        
        User empUser = TestDataFactory.createTestUser('Standard User', 'EmpUser');
        Employee__c emp = TestDataFactory.createEmployee(empUser.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        update emp;

        Test.startTest();
        // This update should trigger EmployeeSharingTrigger
        emp.Team__c = team.Id;
        emp.Manager__c = mgrEmp.Id;
        update emp;
        Test.stopTest();
        
        // Verify shares
        List<Employee__Share> shares = [SELECT Id FROM Employee__Share WHERE ParentId = :emp.Id AND RowCause = 'Manual'];
        Assert.isTrue(shares.size() >= 1);
    }
}
