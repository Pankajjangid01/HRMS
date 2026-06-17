trigger SharingEventTrigger on Sharing_Event__e (after insert) {
    
    Set<Id> expenseIds = new Set<Id>();
    Set<Id> leaveIds = new Set<Id>();
    Set<Id> attIds = new Set<Id>();
    
    // Collect IDs from the platform events
    for (Sharing_Event__e event : Trigger.new) {
        if (event.Object_Type__c == 'Expense') {
            expenseIds.add(event.Record_Id__c);
        } else if (event.Object_Type__c == 'LeaveRequest') {
            leaveIds.add(event.Record_Id__c);
        } else if (event.Object_Type__c == 'Attendance') {
            attIds.add(event.Record_Id__c);
        }
    }
    
    if (!expenseIds.isEmpty()) EmployeeSharingService.shareExpenses(expenseIds);
    if (!leaveIds.isEmpty()) EmployeeSharingService.shareLeaveRequests(leaveIds);
    if (!attIds.isEmpty()) EmployeeSharingService.shareAttendances(attIds);
}