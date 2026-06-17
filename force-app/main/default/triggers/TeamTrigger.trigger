trigger TeamTrigger on Team__c (after insert, after update) {

    Set<Id> changedManagerTeamIds = new Set<Id>();

    // 1. Identify teams where the Manager (Employee__c) was added or changed
    for (Team__c team : Trigger.new) {
        if (Trigger.isInsert && team.Employee__c != null) {
            changedManagerTeamIds.add(team.Id);
        } else if (Trigger.isUpdate) {
            Team__c oldTeam = Trigger.oldMap.get(team.Id);
            if (team.Employee__c != oldTeam.Employee__c) {
                changedManagerTeamIds.add(team.Id);
            }
        }
    }

    if (!changedManagerTeamIds.isEmpty()) {
        Map<Id, Employee__c> employeesToUpdate = new Map<Id, Employee__c>();
        
        // 2. Fetch the Team's Department HOD and update the Team Manager's Manager__c
        List<Team__c> teamsWithHOD = [
            SELECT Id, Employee__c, Department__r.Employee__c 
            FROM Team__c 
            WHERE Id IN :changedManagerTeamIds AND Employee__c != null
        ];
        
        for (Team__c team : teamsWithHOD) {
            if (team.Department__r.Employee__c != null) {
                employeesToUpdate.put(team.Employee__c, new Employee__c(
                    Id = team.Employee__c,
                    Manager__c = team.Department__r.Employee__c
                ));
            }
        }

        // 3. Update Team Members to point to the new Team Manager (needed for your TeamTriggerTest)
        for (Employee__c emp : [SELECT Id, Team__c, Manager__c FROM Employee__c WHERE Team__c IN :changedManagerTeamIds]) {
            Team__c parentTeam = Trigger.newMap.get(emp.Team__c);
            emp.Manager__c = parentTeam.Employee__c; 
            employeesToUpdate.put(emp.Id, emp); // Map handles duplicates gracefully
        }
        
        // 4. Commit updates to the database
        if (!employeesToUpdate.isEmpty()) {
            update employeesToUpdate.values();
        }
    }
}