@isTest
public class UserInfoControllerTest {

    @isTest
    static void testGetCurrentUser() {
        User u = TestDataFactory.createTestUser('Standard User', 'TestUser');
        System.runAs(u) {
            Test.startTest();
            User current = UserInfoController.getCurrentUser();
            Test.stopTest();
            Assert.areEqual(u.Id, current.Id);
        }
    }

    @isTest
    static void testGetUserRoleType() {
        User u = TestDataFactory.createTestUser('Standard User', 'TestUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Manager');
        
        System.runAs(u) {
            Test.startTest();
            String role = UserInfoController.getUserRoleType();
            Test.stopTest();
            Assert.areEqual('Manager', role);
        }
    }

    @isTest
    static void testGetUserRoleTypeUnknown() {
        User u = TestDataFactory.createTestUser('Standard User', 'NoEmpUser');
        System.runAs(u) {
            Test.startTest();
            String role = UserInfoController.getUserRoleType();
            Test.stopTest();
            Assert.areEqual('UNKNOWN', role);
        }
    }
}
