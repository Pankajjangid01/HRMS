public class AttendanceAutoCheckoutScheduler {
    @InvocableMethod(label='Auto Checkout Employees')
    public static void autoCheckoutEmployees(List<String> dummy) {
        System.debug('=== AUTO CHECKOUT STARTED ===');
        List<Attendance__c> attendanceToUpdate = new List<Attendance__c>();

        List<Attendance__c> records = [            
            SELECT Id,
                Attendance_Date__c,
                Check_In__c,
                Check_Out__c,
                Is_Check_In_Done__c,
                Is_Check_Out_Done__c,
                Working_Hours__c,
                Attendance_Status__c,
                Remarks__c
            FROM Attendance__c
            WHERE Is_Check_In_Done__c = true
            AND Is_Check_Out_Done__c = false
            AND Check_In__c != null
            AND Attendance_Date__c <= :Date.today()
        ];

        System.debug('Records Found: ' + records.size());
        
        List<Attendance_Policy__mdt> policies = [	
            SELECT Full_Day_Hours__c, Half_Day_Hours__c
            FROM Attendance_Policy__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        
        Decimal fullDayHours = !policies.isEmpty() && policies[0].Full_Day_Hours__c != null ? policies[0].Full_Day_Hours__c : 8.0;
        Decimal halfDayHours = !policies.isEmpty() && policies[0].Half_Day_Hours__c != null ? policies[0].Half_Day_Hours__c : 4.0;

        for(Attendance__c att : records){

            DateTime autoCheckoutTime = System.now();

            att.Check_Out__c = autoCheckoutTime;
            att.Is_Check_Out_Done__c = true;

            Long ms = autoCheckoutTime.getTime() - att.Check_In__c.getTime();
            Decimal hours = (ms / 3600000.0).setScale(2);
            att.Working_Hours__c = hours;
            if(hours >= fullDayHours) {
                att.Attendance_Status__c = 'Present';
            }
            else if(hours >= halfDayHours) {
                att.Attendance_Status__c = 'Half Day';
            }
            else {
                att.Attendance_Status__c = 'Absent';
            }

            att.Remarks__c = 'Auto checkout - Employee missed checkout';
            attendanceToUpdate.add(att);
        }

        if(!attendanceToUpdate.isEmpty()){
            update attendanceToUpdate;
            System.debug('Updated Records: ' + attendanceToUpdate.size());
        }
        System.debug('=== AUTO CHECKOUT FINISHED ===');
    }
}