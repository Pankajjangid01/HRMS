@isTest
public class AttendanceAutoCheckoutSchedulerTest {

    @isTest
    static void testAutoCheckoutEmployees() {
        // 0. Create a dummy Account since Account__c is a required lookup
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // 1. Create dummy Employee record
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Employee',
            Status__c = 'Active',
            Joining_Date__c = Date.today().addDays(-30),
            Email__c = 'test.employee@example.com',
            Phone__c = '1234567890',
            User_Type__c = 'HOD',
            Account__c = acc.Id
        );
        insert emp;

        // 2. Create Attendance record with check-in yesterday to ensure > 13 hours
        Date yesterdayDate = Date.today().addDays(-1);
        DateTime checkInTime = DateTime.newInstance(yesterdayDate, Time.newInstance(0, 0, 0, 0));
        
        Attendance__c att = new Attendance__c(
            Employee__c = emp.Id,
            Attendance_Date__c = yesterdayDate,
            Check_In__c = checkInTime,
            Is_Check_In_Done__c = true,
            Is_Check_Out_Done__c = false
        );
        insert att;

        // 3. Run the scheduler invocable method
        Test.startTest();
        AttendanceAutoCheckoutScheduler.autoCheckoutEmployees(new List<String>());
        Test.stopTest();

        // 4. Query the updated record to verify calculations
        Attendance__c updatedAtt = [
            SELECT Id, Check_Out__c, Is_Check_Out_Done__c, Working_Hours__c, Attendance_Status__c, Remarks__c
            FROM Attendance__c
            WHERE Id = :att.Id
        ];

        // 5. Assertions to prove the logic worked
        System.assertEquals(true, updatedAtt.Is_Check_Out_Done__c, 'Check out flag should be true');
        System.assertNotEquals(null, updatedAtt.Check_Out__c, 'Check out time should be set');
        
        // Check-in was 12:00 AM (midnight), Check-out should be set to 11:59 PM. 
        // That's roughly 23.98 hours.
        System.assert(updatedAtt.Working_Hours__c > 13.0, 'Working hours should be calculated correctly');
        
        // Since 13+ hours is > Full Day limits, status must be present
        System.assertEquals('Present', updatedAtt.Attendance_Status__c, 'Status should be Present for > 8 hours');
        System.assertEquals('Auto checkout - Employee missed checkout', updatedAtt.Remarks__c, 'Remarks should match the auto checkout string');
    }

}