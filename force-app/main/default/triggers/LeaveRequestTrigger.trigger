trigger LeaveRequestTrigger on Leave_Request__c (after update) {
    LeaveRequestTriggerHandler.updateLeaveBalance(Trigger.new,Trigger.oldMap);
}