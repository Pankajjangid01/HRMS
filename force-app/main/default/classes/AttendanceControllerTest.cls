@isTest
public class AttendanceControllerTest {

    @isTest
    static void testAttendanceFlow() {
        User u = TestDataFactory.createTestUser('Standard User', 'AttUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');

        System.runAs(u) {
            Test.startTest();
            // 1. Get today attendance (should be null)
            Attendance__c att1 = AttendanceController.getTodayAttendance();
            Assert.isNull(att1);

            // 2. Do check in
            Attendance__c att2 = AttendanceController.doCheckIn();
            Assert.isNotNull(att2);
            Assert.isTrue(att2.Is_Check_In_Done__c);

            // 3. Do check out
            Attendance__c att3 = AttendanceController.doCheckOut();
            Assert.isNotNull(att3);
            Assert.isTrue(att3.Is_Check_Out_Done__c);
            Test.stopTest();
        }
    }

    @isTest
    static void testAlreadyCheckedIn() {
        User u = TestDataFactory.createTestUser('Standard User', 'AttUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');
        TestDataFactory.createAttendance(emp.Id, Date.today());

        System.runAs(u) {
            Test.startTest();
            try {
                AttendanceController.doCheckIn();
                Assert.fail('Should have thrown an exception');
            } catch(AuraHandledException e) {
                // In tests, AuraHandledException message is often 'Script-thrown exception'
                Assert.isTrue(true);
            } catch(Exception e) {
                Assert.fail('Wrong exception: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testCheckOutWithoutCheckIn() {
        User u = TestDataFactory.createTestUser('Standard User', 'AttUser');
        Employee__c emp = TestDataFactory.createEmployee(u.Id, 'Portal - Employee');

        System.runAs(u) {
            Test.startTest();
            try {
                AttendanceController.doCheckOut();
                Assert.fail('Should have thrown an exception');
            } catch(AuraHandledException e) {
                Assert.isTrue(true);
            } catch(Exception e) {
                Assert.fail('Wrong exception: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }
}
