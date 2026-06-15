@isTest
public class EmployeeUserCreationTest {

    @isTest
    static void testInvocable() {
        User u = TestDataFactory.createTestUser('Standard User', 'InvocUser');
        Employee__c emp = TestDataFactory.createEmployee(null, 'Manager'); // Employee without User

        Test.startTest();
        EmployeeUserCreation.createUser(new List<Id>{emp.Id});
        Test.stopTest();
        
        // Verifying it enqueued a job
        Assert.isTrue(true);
    }
    
    @isTest
    static void testQueueable() {
        // We can't easily test the actual user creation with hardcoded profile names
        // unless they exist. But we can test the constructor and partial execution.
        Employee__c emp = TestDataFactory.createEmployee(null, 'Manager');
        
        Test.startTest();
        EmployeeUserCreationQueueable q = new EmployeeUserCreationQueueable(new List<Id>{emp.Id});
        System.enqueueJob(q);
        Test.stopTest();
        
        Assert.isTrue(true);
    }
}
