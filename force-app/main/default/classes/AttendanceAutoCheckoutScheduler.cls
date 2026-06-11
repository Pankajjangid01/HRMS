public class AttendanceAutoCheckoutScheduler {
    @InvocableMethod(label='Auto Checkout Employees')
    public static void autoCheckoutEmployees(List<String> dummy) {
        List<Attendance__c> attendanceToUpdate = new List<Attendance__c>();

        // Today start & end
        Date today = Date.today();
        DateTime startOfDay = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = DateTime.newInstance(today, Time.newInstance(23, 59, 59, 0));
        List<Attendance__c> records = [
            SELECT
                Id,
                Check_In__c,
                Check_Out__c,
                Is_Check_In_Done__c,
                Is_Check_Out_Done__c,
                Working_Hours__c,
                Attendance_Status__c,
                Remarks__c
            FROM Attendance__c
            WHERE CreatedDate >= :startOfDay
            AND CreatedDate <= :endOfDay
            AND Is_Check_In_Done__c = true
            AND Is_Check_Out_Done__c = false
        ];

        for(Attendance__c att : records) {
            DateTime autoCheckoutTime = DateTime.newInstance(today, Time.newInstance(23, 59, 0, 0));

            att.Check_Out__c = autoCheckoutTime;
            att.Is_Check_Out_Done__c = true;

            Decimal hours =(autoCheckoutTime.getTime() - att.Check_In__c.getTime()) / (1000 * 60 * 60);
            hours = hours.setScale(2);
            att.Working_Hours__c = hours;
            if(hours >= 8) {
                att.Attendance_Status__c = 'Present';
            }
            else if(hours >= 4) {
                att.Attendance_Status__c = 'Half Day';
            }
            else {
                att.Attendance_Status__c = 'Absent';
            }

            att.Remarks__c = 'Auto checkout - Employee missed checkout';
            attendanceToUpdate.add(att);
        }

        if(!attendanceToUpdate.isEmpty()) {
            update attendanceToUpdate;
        }
    }
}
