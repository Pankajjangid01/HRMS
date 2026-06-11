public without sharing class LeaveController {

    @AuraEnabled(cacheable=false)
    public static Leave_Balance__c getLeaveBalance() {

        try {

            Employee__c emp = getCurrentEmployee();

            if(emp == null) {
                throw new AuraHandledException('Employee record not found. Please contact HR.');
            }

            List<Leave_Balance__c> balances = [
                SELECT
                    Id,
                    PTO_Total__c,
                    PTO_Used__c,
                    PTO_Remaining__c,
                    Sick_Total__c,
                    Sick_Used__c,
                    Sick_Remaining__c,
                    Bereavement_Total__c,
                    Bereavement_Used__c,
                    Bereavement_Remaining__c,
                    Year__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c = :emp.Id
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];

            return balances.isEmpty() ? null : balances[0];

        } catch(Exception e) {

            throw new AuraHandledException(
                'Error fetching leave balance: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Leave_Request__c> getLeaveRequests() {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null) {
                throw new AuraHandledException('Employee record not found');
            }

            return [
                SELECT
                    Id,
                    Leave_Type__c,
                    Start_Date__c,
                    End_Date__c,
                    Number_Of_Days__c,
                    Reason__c,
                    Status__c,
                    CreatedDate
                FROM Leave_Request__c
                WHERE Employee__c = :emp.Id
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            throw new AuraHandledException(
                'Error fetching leave requests: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void applyLeave(String leaveType, String startDate, String endDate, String reason) {
        try {
            Employee__c emp = getCurrentEmployee();
            if(emp == null) {
                throw new AuraHandledException('Employee record not found');
            }
            Date sDate = Date.valueOf(startDate);
            Date eDate = Date.valueOf(endDate);
            if(sDate > eDate) {
                throw new AuraHandledException('Start date cannot be after end date');
            }

            if(sDate < Date.today()) {
                throw new AuraHandledException('Cannot apply leave for past dates');
            }

            List<Leave_Balance__c> balances = [
                SELECT
                    Id,
                    PTO_Remaining__c,
                    Sick_Remaining__c,
                    Bereavement_Remaining__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c = :emp.Id
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];

            if(balances.isEmpty()) {
                throw new AuraHandledException(
                    'Leave balance not found'
                );
            }
            Integer days = sDate.daysBetween(eDate) + 1;
            Decimal remaining = 0;
            if(leaveType == 'Paid Time Off') {
                remaining = balances[0].PTO_Remaining__c != null ? balances[0].PTO_Remaining__c : 0;
            } else if(leaveType == 'Sick') {
                remaining = balances[0].Sick_Remaining__c != null ? balances[0].Sick_Remaining__c : 0;
            } else if(leaveType == 'Bereavement') {
                remaining = balances[0].Bereavement_Remaining__c != null ? balances[0].Bereavement_Remaining__c : 0;
            } else {
                throw new AuraHandledException('Invalid leave type');
            }

            if(remaining < days) {
                throw new AuraHandledException('Insufficient leave balance. Available: ' + remaining + ' days');
            }

            Leave_Request__c lr = new Leave_Request__c();

            lr.Employee__c = emp.Id;
            lr.Leave_Type__c = leaveType;
            lr.Start_Date__c = sDate;
            lr.End_Date__c = eDate;
            lr.Reason__c = reason;
            lr.Status__c = 'Submitted';

            insert lr;

        } catch(Exception e) {
            throw new AuraHandledException('Error applying leave: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void cancelLeave(String leaveId) {
        try {
            List<Leave_Request__c> requests = [
                SELECT
                    Id,
                    Status__c
                FROM Leave_Request__c
                WHERE Id = :leaveId
                LIMIT 1
            ];

            if(requests.isEmpty()) {
                throw new AuraHandledException('Leave request not found');
            }

            if(requests[0].Status__c != 'Submitted') {
                throw new AuraHandledException(
                    'Cannot cancel this leave request'
                );
            }
            requests[0].Status__c = 'Withdrawn';
            update requests[0];

        } catch(Exception e) {
            throw new AuraHandledException('Error cancelling leave: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deductLeaveBalance(String leaveId) {
        try {
            List<Leave_Request__c> leaves = [
                SELECT
                    Id,
                    Employee__c,
                    Leave_Type__c,
                    Number_Of_Days__c
                FROM Leave_Request__c
                WHERE Id = :leaveId
                LIMIT 1
            ];
            if(leaves.isEmpty()) { return; }

            List<Leave_Balance__c> balances = [
                SELECT
                    Id,
                    PTO_Used__c,
                    Sick_Used__c,
                    Bereavement_Used__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c = :leaves[0].Employee__c
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];

            if(balances.isEmpty()) { return; }
            Leave_Balance__c lb = balances[0];
            Decimal days =
                leaves[0].Number_Of_Days__c != null
                ? leaves[0].Number_Of_Days__c
                : 0;

            if(leaves[0].Leave_Type__c == 'Paid Time Off') {
                lb.PTO_Used__c =
                    (
                        lb.PTO_Used__c != null
                        ? lb.PTO_Used__c
                        : 0
                    ) + days;

            } else if(leaves[0].Leave_Type__c == 'Sick') {
                lb.Sick_Used__c =
                    (
                        lb.Sick_Used__c != null
                        ? lb.Sick_Used__c
                        : 0
                    ) + days;

            } else if(leaves[0].Leave_Type__c == 'Bereavement') {
                lb.Bereavement_Used__c =
                    (
                        lb.Bereavement_Used__c != null
                        ? lb.Bereavement_Used__c
                        : 0
                    ) + days;
            }
            update lb;

        } catch(Exception e) {
            throw new AuraHandledException(
                'Error deducting leave balance: ' + e.getMessage()
            );
        }
    }

    private static Employee__c getCurrentEmployee() {

        try {
            Id userId = UserInfo.getUserId();

            List<Employee__c> emps = [
                SELECT
                    Id
                FROM Employee__c
                WHERE User__c = :userId
                AND Status__c = 'Active'
                LIMIT 1
            ];

            if(emps.isEmpty()) {
                System.debug('ERROR: No Employee record found for User: ' + userId);
                return null;
            }

            return emps[0];
        } catch(QueryException qe) {
            System.debug('ERROR in getCurrentEmployee QueryException: ' + qe.getMessage());
            throw new AuraHandledException('Database error: ' + qe.getMessage());
        } catch(Exception e) {
            System.debug('ERROR in getCurrentEmployee: ' + e.getMessage());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
}