public class LeaveRequestTriggerHandler {

    public static void updateLeaveBalance(
        List<Leave_Request__c> newList,
        Map<Id, Leave_Request__c> oldMap
    ) {

        Map<Id, Leave_Request__c> approvedLeaves =
            new Map<Id, Leave_Request__c>();

        Set<Id> empIds = new Set<Id>();

        // Find newly approved leaves
        for(Leave_Request__c leave : newList) {

            Leave_Request__c oldLeave =
                oldMap.get(leave.Id);

            if(
                leave.Status__c == 'Manager Approved' &&
                oldLeave.Status__c !=
                'Manager Approved'
            ) {

                approvedLeaves.put(
                    leave.Employee__c,
                    leave
                );

                empIds.add(leave.Employee__c);
            }
        }

        if(empIds.isEmpty()) {
            return;
        }

        // Get leave balances
        List<Leave_Balance__c> balances = [
            SELECT
                Id,
                Employee_Leaves__c,
                PTO_Used__c,
                Sick_Used__c,
                Bereavement_Used__c
            FROM Leave_Balance__c
            WHERE Employee_Leaves__c IN :empIds
            AND Year__c = :Date.today().year()
        ];

        List<Leave_Balance__c> balancesToUpdate =
            new List<Leave_Balance__c>();

        for(Leave_Balance__c balance : balances) {

            Leave_Request__c leave =
                approvedLeaves.get(
                    balance.Employee_Leaves__c
                );

            if(leave == null) {
                continue;
            }

            Decimal days =
                leave.Number_Of_Days__c == null
                ? 0
                : leave.Number_Of_Days__c;

            // Update correct leave type field
            if(leave.Leave_Type__c ==
                'Paid Time Off') {

                balance.PTO_Used__c =
                    (balance.PTO_Used__c == null
                    ? 0
                    : balance.PTO_Used__c)
                    + days;

            } else if(leave.Leave_Type__c ==
                'Sick') {

                balance.Sick_Used__c =
                    (balance.Sick_Used__c == null
                    ? 0
                    : balance.Sick_Used__c)
                    + days;

            } else if(leave.Leave_Type__c ==
                'Bereavement') {

                balance.Bereavement_Used__c =
                    (
                        balance
                        .Bereavement_Used__c == null
                        ? 0
                        : balance
                            .Bereavement_Used__c
                    )
                    + days;
            }

            balancesToUpdate.add(balance);
        }

        if(!balancesToUpdate.isEmpty()) {
            update balancesToUpdate;
        }
    }
}