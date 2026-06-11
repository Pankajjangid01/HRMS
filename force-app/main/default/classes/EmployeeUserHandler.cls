public with sharing class EmployeeUserHandler {
    public static void handleUserActivation(List<Employee__c> newList, Map<Id, Employee__c> oldMap) {

        Set<Id> activateIds = new Set<Id>();
        Set<Id> deactivateIds = new Set<Id>();
        for (Employee__c emp : newList) {
            Employee__c oldEmp = oldMap.get(emp.Id);
            if (
                emp.Status__c == 'Exited' &&
                oldEmp.Status__c != 'Exited' &&
                emp.User__c != null
            ) {
                deactivateIds.add(emp.User__c);
            }
            else if (
                emp.Status__c == 'Active' &&
                oldEmp.Status__c == 'Exited' &&
                emp.User__c != null
            ) {
                activateIds.add(emp.User__c);
            }
        }

        if (!activateIds.isEmpty() || !deactivateIds.isEmpty()) {
            updateUsersAsync(
                new List<Id>(activateIds),
                new List<Id>(deactivateIds)
            );
        }
    }

    @future
    public static void updateUsersAsync(
        List<Id> activateIds,
        List<Id> deactivateIds
    ) {
        List<User> usersToUpdate = new List<User>();
        // Activate Users
        if (activateIds != null) {
            for (Id userId : activateIds) {
                usersToUpdate.add(
                    new User(
                        Id = userId,
                        IsActive = true
                    )
                );
            }
        }

        // Deactivate Users
        if (deactivateIds != null) {
            for (Id userId : deactivateIds) {
                usersToUpdate.add(
                    new User(
                        Id = userId,
                        IsActive = false
                    )
                );
            }
        }
        if (!usersToUpdate.isEmpty()) {
            update usersToUpdate;
        }
    }
}
