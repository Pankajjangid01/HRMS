trigger AttendanceTrigger on Attendance__c (before insert, after insert, after update) {

    // ── BEFORE INSERT: Change Owner to Internal User (Head HR) ───────────────
    if (Trigger.isBefore && Trigger.isInsert) {
        List<Employee__c> headHR = [
            SELECT User__c FROM Employee__c
            WHERE User_Type__c = 'Head HR' AND Status__c = 'Active' AND User__c != null
            LIMIT 1
        ];
        if (!headHR.isEmpty()) {
            Id internalOwnerId = headHR[0].User__c;
            for (Attendance__c att : Trigger.new) {
                if (UserInfo.getUserType() != 'Standard') {
                    att.OwnerId = internalOwnerId;
                }
            }
        }
    }

    // ── AFTER INSERT / UPDATE: Unified Platform Event Sharing ─────────────────────────
    if (Trigger.isAfter) {
        List<Sharing_Event__e> eventsToPublish = new List<Sharing_Event__e>();
        
        for (Attendance__c att : Trigger.new) {
            Boolean needsSharing = false;
            
            if (Trigger.isInsert) {
                needsSharing = true;
            } else if (Trigger.isUpdate) {
                Attendance__c old = Trigger.oldMap.get(att.Id);
                if (att.Employee__c != old.Employee__c || att.OwnerId != old.OwnerId) 
                    needsSharing = true;
            }
            
            if (needsSharing) eventsToPublish.add(new Sharing_Event__e(Record_Id__c = att.Id, Object_Type__c = 'Attendance'));
        }
        
        if (!eventsToPublish.isEmpty()) {
            EventBus.publish(eventsToPublish);
        }
    }
}