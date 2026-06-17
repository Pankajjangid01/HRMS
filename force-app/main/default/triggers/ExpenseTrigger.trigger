trigger ExpenseTrigger on Expense__c (before insert, after insert, after update) {

    // ── BEFORE INSERT: Portal user owner change ──────────────────────────
    if (Trigger.isBefore && Trigger.isInsert) {
        List<Employee__c> headHR = [
            SELECT User__c FROM Employee__c
            WHERE User_Type__c = 'Head HR'
            AND Status__c = 'Active'
            AND User__c != null
            LIMIT 1
        ];

        if (!headHR.isEmpty()) {
            Id internalOwnerId = headHR[0].User__c;
            for (Expense__c exp : Trigger.new) {
                if (UserInfo.getUserType() != 'Standard') {
                    exp.OwnerId = internalOwnerId;
                }
            }
        }
    }

    // ── AFTER INSERT / UPDATE: Unified Platform Event Sharing ─────────────
    if (Trigger.isAfter) {
        List<Sharing_Event__e> eventsToPublish = new List<Sharing_Event__e>();
        
        for (Expense__c exp : Trigger.new) {
            Boolean needsSharing = false;
            
            if (Trigger.isInsert) {
                needsSharing = true;
            } else if (Trigger.isUpdate) {
                Expense__c old = Trigger.oldMap.get(exp.Id);
                if (exp.Employee__c != old.Employee__c || exp.Finance_User__c != old.Finance_User__c || exp.OwnerId != old.OwnerId) {
                    needsSharing = true;
                }
            }
            
            if (needsSharing) {
                eventsToPublish.add(new Sharing_Event__e(Record_Id__c = exp.Id, Object_Type__c = 'Expense'));
            }
        }

        if (!eventsToPublish.isEmpty()) {
            EventBus.publish(eventsToPublish);
        }
    }
}