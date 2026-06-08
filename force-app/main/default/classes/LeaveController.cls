public with sharing class LeaveController {

    // Get Leave Balances
    @AuraEnabled(cacheable=false)
    public static List<Leave_Balance__c>
        getLeaveBalances() {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null) return new List<Leave_Balance__c>();

            return [
                SELECT
                    Id,
                    Leave_Type__c,
                    Total_Leaves__c,
                    Used_Leaves__c,
                    Remaining_Leaves__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c = :emp.Id
                ORDER BY Leave_Type__c
            ];
        } catch(Exception e) {
            return new List<Leave_Balance__c>();
        }
    }

    // Get Leave Requests
    @AuraEnabled(cacheable=false)
    public static List<Leave_Request__c>
        getLeaveRequests() {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null)
                return new List<Leave_Request__c>();

            return [
                SELECT
                    Id,
                    Leave_Type__c,
                    Start_Date__c,
                    End_Date__c,
                    Number_Of_Days__c,
                    Reason__c,
                    Status__c
                FROM Leave_Request__c
                WHERE Employee__c = :emp.Id
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            return new List<Leave_Request__c>();
        }
    }

    // Apply Leave
    @AuraEnabled
    public static void applyLeave(
        String leaveType,
        String startDate,
        String endDate,
        String reason
    ) {
        Employee__c emp = getCurrentEmployee();
        if(emp == null)
            throw new AuraHandledException('Employee record not found');

        // Date conversion
        Date sDate = Date.valueOf(startDate);
        Date eDate = Date.valueOf(endDate);

        // Validate dates
        if(sDate > eDate)
            throw new AuraHandledException(
                'Start date cannot be after end date');

        if(sDate < Date.today())
            throw new AuraHandledException('Cannot apply leave for past dates');

        // Check leave balance
        List<Leave_Balance__c> balances = [
            SELECT
                Id,
                Remaining_Leaves__c,
                Total_Leaves__c,
                Used_Leaves__c
            FROM Leave_Balance__c
            WHERE Employee_Leaves__c = :emp.Id
            AND Leave_Type__c = :leaveType
            LIMIT 1
        ];

        if(balances.isEmpty())
            throw new AuraHandledException('Leave balance not found');

        Integer days = sDate.daysBetween(eDate) + 1;

        if(balances[0].Remaining_Leaves__c < days)
            throw new AuraHandledException(
                'Insufficient leave balance. Available: '
                + balances[0].Remaining_Leaves__c
                + ' days');

        // Create Leave Request
        Leave_Request__c lr = new Leave_Request__c();
        lr.Employee__c = emp.Id;
        lr.Leave_Type__c = leaveType;
        lr.Start_Date__c = sDate;
        lr.End_Date__c = eDate;
        lr.Reason__c = reason;
        lr.Status__c = 'Submitted';

        insert lr;
    }

    // Cancel Leave
    @AuraEnabled
    public static void cancelLeave(String leaveId) {
        List<Leave_Request__c> requests = [
            SELECT Id, Status__c
            FROM Leave_Request__c
            WHERE Id = :leaveId
            LIMIT 1
        ];

        if(requests.isEmpty())
            throw new AuraHandledException('Leave request not found');
        if(requests[0].Status__c != 'Draft' &&
           requests[0].Status__c != 'Submitted')
            throw new AuraHandledException('Cannot cancel this leave request');

        requests[0].Status__c = 'Cancelled';
        update requests[0];
    }

    // Get Current Employee
    private static Employee__c getCurrentEmployee() {
        Id userId = UserInfo.getUserId();
        List<Employee__c> emps = [
            SELECT Id
            FROM Employee__c
            WHERE User__c = :userId
            AND Status__c = 'Active'
            LIMIT 1
        ];
        return emps.isEmpty() ? null : emps[0];
    }
}