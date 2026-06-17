public without sharing class AttendanceController {

    // Get Today Attendance
    @AuraEnabled(cacheable=false)
    public static Attendance__c getTodayAttendance() {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null) return null;

            Date today = Date.today();
            List<Attendance__c> records = [
                SELECT
                    Id,
                    Check_In__c,
                    Check_Out__c,
                    Working_Hours__c,
                    Attendance_Status__c,
                    Is_Check_In_Done__c,
                    Is_Check_Out_Done__c,
                    Attendance_Date__c
                FROM Attendance__c
                WHERE Employee__c = :emp.Id
                AND Attendance_Date__c = :today
                LIMIT 1
            ];

            return records.isEmpty() ? null : records[0];
        } catch(Exception e) {
            return null;
        }
    }

    // Check In
    @AuraEnabled
    public static Attendance__c doCheckIn() {

        Employee__c emp = getCurrentEmployee();
        if(emp == null)
            throw new AuraHandledException('Employee record not found');

        Date today = Date.today();
        List<Attendance__c> existing = [
            SELECT Id FROM Attendance__c
            WHERE Employee__c = :emp.Id
            AND Attendance_Date__c = :today
            AND Is_Check_In_Done__c = true
            LIMIT 1
        ];

        if(!existing.isEmpty())
            throw new AuraHandledException('Already checked in today');

        // Create Attendance record
        Attendance__c att = new Attendance__c();
        att.Employee__c = emp.Id;
        att.Attendance_Date__c = today;
        att.Check_In__c = DateTime.now();
        att.Is_Check_In_Done__c = true;
        insert att;

        return getTodayAttendance();
    }

    // Check Out
    @AuraEnabled
    public static Attendance__c doCheckOut() {

        Employee__c emp = getCurrentEmployee();
        if(emp == null)
            throw new AuraHandledException('Employee record not found');

        Date today = Date.today();
        List<Attendance__c> records = [
            SELECT
                Id,
                Check_In__c,
                Is_Check_In_Done__c
            FROM Attendance__c
            WHERE Employee__c = :emp.Id
            AND Attendance_Date__c = :today
            AND Is_Check_In_Done__c = true
            LIMIT 1
        ];

        if(records.isEmpty())
            throw new AuraHandledException('Please check in first');

        Attendance__c att = records[0];
        att.Check_Out__c = DateTime.now();
        att.Is_Check_Out_Done__c = true;

        // Working Hours calculate karo
        Long checkInMs = att.Check_In__c.getTime();
        Long checkOutMs = DateTime.now().getTime();
        Decimal hours = (checkOutMs - checkInMs) / 3600000.0;
        att.Working_Hours__c = hours.setScale(2);

        List<Attendance_Policy__mdt> policies = [
            SELECT
                Full_Day_Hours__c,
                Half_Day_Hours__c
            FROM Attendance_Policy__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if(!policies.isEmpty()) {
            Decimal fullDay = policies[0].Full_Day_Hours__c;
            Decimal halfDay = policies[0].Half_Day_Hours__c;

            if(hours >= fullDay) {
                att.Attendance_Status__c = 'Present';
            } else if(hours >= halfDay) {
                att.Attendance_Status__c = 'Half Day';
            } else {
                att.Attendance_Status__c = 'Absent';
            }
        }
        update att;
        return getTodayAttendance();
    }

    // Get Current Employee
    private static Employee__c getCurrentEmployee() {
        Id userId = UserInfo.getUserId();
        List<Employee__c> emps = [
            SELECT Id, First_Name__c, Last_Name__c
            FROM Employee__c
            WHERE User__c = :userId
            AND Status__c = 'Active'
            LIMIT 1
        ];
        return emps.isEmpty() ? null : emps[0];
    }
}