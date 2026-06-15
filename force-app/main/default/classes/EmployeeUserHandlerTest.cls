@isTest
public class EmployeeUserHandlerTest {

    @isTest
    static void testUserActivationDeactivation() {
        User u = TestDataFactory.createTestUser('Standard User', 'ActiveUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        
        Test.startTest();
        // 1. Deactivate
        emp.Status__c = 'Exited';
        EmployeeUserHandler.handleUserActivation(
            new List<Employee__c>{emp}, 
            new Map<Id, Employee__c>{emp.Id => new Employee__c(Id = emp.Id, Status__c = 'Active', User__c = u.Id)}
        );
        
        // 2. Activate
        emp.Status__c = 'Active';
        EmployeeUserHandler.handleUserActivation(
            new List<Employee__c>{emp}, 
            new Map<Id, Employee__c>{emp.Id => new Employee__c(Id = emp.Id, Status__c = 'Exited', User__c = u.Id)}
        );
        Test.stopTest();
        
        User updatedUser = [SELECT IsActive FROM User WHERE Id = :u.Id];
        Assert.isTrue(updatedUser.IsActive);
    }
}
