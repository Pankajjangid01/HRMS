global class EmployeeSharingBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Employee__c WHERE Status__c = 'Active'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Employee__c> scope) {
        Set<Id> ids = new Set<Id>();
        for (Employee__c e : scope) ids.add(e.Id);
        EmployeeSharingService.recalculateSharing(ids);
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('EmployeeSharingBatch completed.');
    }
}