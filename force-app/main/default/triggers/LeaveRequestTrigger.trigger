trigger LeaveRequestTrigger on Leave_Request__c (before update) {
    LeaveRequestTriggerHandler.updateLeaveBalance(Trigger.new, Trigger.oldMap);
}