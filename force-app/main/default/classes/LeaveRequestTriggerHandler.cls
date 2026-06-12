public class LeaveRequestTriggerHandler {
    public static void updateLeaveBalance(
        List<Leave_Request__c> newList,
        Map<Id, Leave_Request__c> oldMap
    ) {
        Set<Id> empIds = new Set<Id>();
        for(Leave_Request__c leave : newList) {
            Leave_Request__c oldLeave =
                oldMap.get(leave.Id);
            if(
                leave.Status__c == 'HR Approved' &&
                oldLeave.Status__c != 'HR Approved'
            ) {
                empIds.add(leave.Employee__c);
            }
        }

        if(empIds.isEmpty()) {
            return;
        }

        Map<Id, Leave_Balance__c> balanceMap = new Map<Id, Leave_Balance__c>();
        for(Leave_Balance__c lb : [
            SELECT
                Id,
                Employee_Leaves__c,
                PTO_Total__c,
                PTO_Used__c,
                Sick_Total__c,
                Sick_Used__c,
                Bereavement_Total__c,
                Bereavement_Used__c

            FROM Leave_Balance__c
            WHERE Employee_Leaves__c IN :empIds
            AND Year__c = :Date.today().year()
        ]) {
            balanceMap.put(
                lb.Employee_Leaves__c,
                lb
            );
        }

        List<Leave_Balance__c> balancesToUpdate =
            new List<Leave_Balance__c>();
        for(Leave_Request__c leave : newList) {
            Leave_Request__c oldLeave = oldMap.get(leave.Id);
            if(
                leave.Status__c != 'HR Approved' ||
                oldLeave.Status__c == 'HR Approved'
            ) {
                continue;
            }

            Leave_Balance__c balance = balanceMap.get(leave.Employee__c);
            if(balance == null) {
                leave.addError( 'Leave balance record not found for this employee.');
                continue;
            }

            Decimal requestedDays =
                leave.Number_Of_Days__c == null
                ? 0
                : leave.Number_Of_Days__c;

            // ── PTO ─────────────────────────────
            if(leave.Leave_Type__c == 'Paid Time Off') {

                Decimal total =
                    balance.PTO_Total__c == null
                    ? 0
                    : balance.PTO_Total__c;

                Decimal used =
                    balance.PTO_Used__c == null
                    ? 0
                    : balance.PTO_Used__c;

                Decimal available =
                    total - used;

                if(requestedDays > available) {

                    leave.addError(
                        'Insufficient PTO balance. Available: '
                        + available + ' day(s).'
                    );
                    continue;
                }

                balance.PTO_Used__c = used + requestedDays;
            }

            // ── Sick Leave ─────────────────────
            else if(leave.Leave_Type__c == 'Sick') {
                Decimal total =
                    balance.Sick_Total__c == null
                    ? 0
                    : balance.Sick_Total__c;

                Decimal used =
                    balance.Sick_Used__c == null
                    ? 0
                    : balance.Sick_Used__c;

                Decimal available =
                    total - used;

                if(requestedDays > available) {
                    leave.addError(
                        'Insufficient Sick Leave balance. Available: '
                        + available + ' day(s).'
                    );
                    continue;
                }

                balance.Sick_Used__c = used + requestedDays;
            }

            // ── Bereavement ────────────────────
            else if(leave.Leave_Type__c == 'Bereavement') {
                Decimal total =
                    balance.Bereavement_Total__c == null
                    ? 0
                    : balance.Bereavement_Total__c;

                Decimal used =
                    balance.Bereavement_Used__c == null
                    ? 0
                    : balance.Bereavement_Used__c;

                Decimal available =
                    total - used;

                if(requestedDays > available) {
                    leave.addError(
                        'Insufficient Bereavement Leave balance. Available: '
                        + available + ' day(s).'
                    );
                    continue;
                }
                balance.Bereavement_Used__c = used + requestedDays;
            }
            balancesToUpdate.add(balance);
        }

        if(!balancesToUpdate.isEmpty()) {
            update balancesToUpdate;
        }
    }
}