@isTest
public class DepartmentTriggerTest {

    @isTest
    static void testHODValidation() {
        User hrUser = TestDataFactory.createTestUser('Standard User', 'HRUser');
        Employee__c hrEmp = TestDataFactory.createEmployee(hrUser.Id, 'Head HR');
        
        Department__c dept1 = TestDataFactory.createDepartment('IT', hrEmp.Id);
        
        // Try to make hrEmp HOD of another department
        Department__c dept2 = new Department__c(
            Name = 'Sales', 
            Employee__c = hrEmp.Id,
            Department_Code__c = 'D_SALES'
        );
        
        Test.startTest();
        try {
            insert dept2;
            Assert.fail('Should have thrown validation error');
        } catch(Exception e) {
            String msg = e.getMessage();
            Assert.isTrue(
                msg.contains('already HOD of') || 
                msg.contains('Validate Unique Department Head'),
                'Wrong error message: ' + msg
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testHODChangeSharing() {
        User hod1User = TestDataFactory.createTestUser('Standard User', 'HOD1User');
        Employee__c hod1Emp = TestDataFactory.createEmployee(hod1User.Id, 'HOD');
        
        User hod2User = TestDataFactory.createTestUser('Standard User', 'HOD2User');
        Employee__c hod2Emp = TestDataFactory.createEmployee(hod2User.Id, 'HOD');
        
        Department__c dept = TestDataFactory.createDepartment('IT', hod1Emp.Id);
        Team__c team = TestDataFactory.createTeam('Dev', dept.Id, null);
        
        User empUser = TestDataFactory.createTestUser('Standard User', 'EmpUser');
        Employee__c emp = TestDataFactory.createEmployee(empUser.Id, 'Portal - Employee');
        emp.Department__c = dept.Id;
        emp.Team__c = team.Id;
        update emp;

        Test.startTest();
        // Change HOD
        dept.Employee__c = hod2Emp.Id;
        update dept;
        Test.stopTest();
        
        // Verify hod2 has access now
        List<Employee__Share> shares = [SELECT Id FROM Employee__Share WHERE ParentId = :emp.Id AND UserOrGroupId = :hod2User.Id];
        Assert.isTrue(shares.size() >= 1);
    }
}
