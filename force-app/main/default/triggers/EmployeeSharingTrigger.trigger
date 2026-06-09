trigger EmployeeSharingTrigger on Employee__c (after insert, after update) {

    Set<Id> employeeIds = new Set<Id>();

    if (Trigger.isInsert) {
        for (Employee__c emp : Trigger.new) {
            employeeIds.add(emp.Id);
        }
    }

    if (Trigger.isUpdate) {
        for (Employee__c emp : Trigger.new) {
            Employee__c old = Trigger.oldMap.get(emp.Id);
            // Recalculate only if relevant fields changed
            if (emp.Manager__c != old.Manager__c ||
                emp.Department__c != old.Department__c ||
                emp.Team__c != old.Team__c ||
                emp.Status__c != old.Status__c) {
                employeeIds.add(emp.Id);
            }
        }
    }

    if (!employeeIds.isEmpty()) {
        EmployeeSharingService.recalculateSharing(employeeIds);
    }
}