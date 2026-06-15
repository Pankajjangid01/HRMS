@isTest
public class TeamMemberAssignmentControllerTest {

    @isTest
    static void testAssignmentFlow() {
        User hrUser = TestDataFactory.createTestUser('Standard User', 'HRUser');
        Employee__c hrEmp = TestDataFactory.createEmployee(hrUser.Id, 'Head HR');
        
        Department__c dept = TestDataFactory.createDepartment('IT', hrEmp.Id);
        Team__c team = TestDataFactory.createTeam('Dev', dept.Id, null);
        
        // Emp 1: Portal - Employee
        User empUser1 = TestDataFactory.createTestUser('Standard User', 'Emp1');
        Employee__c emp1 = TestDataFactory.createEmployee(empUser1.Id, 'Portal - Employee');
        emp1.Department__c = dept.Id;
        update emp1;
        
        // Emp 2: Manager
        User empUser2 = TestDataFactory.createTestUser('Standard User', 'Emp2');
        Employee__c emp2 = TestDataFactory.createEmployee(empUser2.Id, 'Manager');
        emp2.Department__c = dept.Id;
        update emp2;

        Test.startTest();
        // 1. Get employees
        Map<String, Object> result = TeamMemberAssignmentController.getTeamEmployees(team.Id);
        Assert.isNotNull(result.get('employees'));
        
        // 2. Add members
        TeamMemberAssignmentController.saveTeamMembers(team.Id, new List<String>{emp1.Id, emp2.Id});
        
        Employee__c updatedEmp1 = [SELECT Team__c, Manager__c FROM Employee__c WHERE Id = :emp1.Id];
        Assert.areEqual(team.Id, updatedEmp1.Team__c);

        // 3. Remove specifically emp1
        TeamMemberAssignmentController.saveTeamMembers(team.Id, new List<String>{emp2.Id});
        
        updatedEmp1 = [SELECT Team__c FROM Employee__c WHERE Id = :emp1.Id];
        Assert.isNull(updatedEmp1.Team__c);
        
        // 4. Exception handling
        try {
            TeamMemberAssignmentController.getTeamEmployees(null);
        } catch(Exception e) {}
        
        Test.stopTest();
    }
}
