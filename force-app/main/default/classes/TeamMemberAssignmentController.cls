public without sharing class TeamMemberAssignmentController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getTeamEmployees(String teamId) {
        try {
            Team__c team = [
                SELECT Id, Name, Department__c, 
                       Employee__c
                FROM Team__c
                WHERE Id = :teamId
                LIMIT 1
            ];

            List<Employee__c> allDeptEmps = [
                SELECT Id, First_Name__c, Last_Name__c,
                    Email__c, Team__c, User_Type__c,
                    Designation__c
                FROM Employee__c
                WHERE Status__c = 'Active'
                AND (
                    Department__c = :team.Department__c
                    OR Department__c = null
                    OR Team__c = null
                )
                AND User_Type__c != 'HOD'
                AND User_Type__c != 'Head HR'
                ORDER BY First_Name__c
            ];

            // Current team members
            Set<Id> currentMembers = new Set<Id>();
            for(Employee__c e : allDeptEmps) {
                if(e.Team__c == teamId) {
                    currentMembers.add(e.Id);
                }
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('employees', allDeptEmps);
            result.put('currentMembers', new List<Id>(currentMembers));
            result.put('managerId', team.Employee__c);
            return result;

        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveTeamMembers(String teamId, List<String> selectedEmpIds) {
        try {
            Team__c team = [
                SELECT Id, Employee__c,
                    Department__c,
                    Department__r.Employee__c
                FROM Team__c
                WHERE Id = :teamId
                LIMIT 1
            ];

            Id teamManagerId = team.Employee__c;
            Id hodId = team.Department__r.Employee__c;

            Set<Id> newMemberIds = new Set<Id>(
                (List<Id>)(List<Object>) selectedEmpIds
            );

            // Current team members + new selected
            List<Employee__c> allEmps = [
                SELECT Id, Team__c, Manager__c,
                    Department__c, User_Type__c
                FROM Employee__c
                WHERE Status__c = 'Active'
                AND (
                    Team__c = :teamId
                    OR Id IN :newMemberIds
                )
            ];

            List<Employee__c> toUpdate = new List<Employee__c>();
            for(Employee__c emp : allEmps) {
                if(newMemberIds.contains(emp.Id)) {
                    emp.Team__c = teamId;
                    emp.Department__c = team.Department__c;

                    // Manager Type wise assign
                    if(emp.User_Type__c == 'Portal - Employee') {
                        emp.Manager__c = teamManagerId;
                    } else if(emp.User_Type__c == 'Manager') {
                        emp.Manager__c = hodId;
                    } else {
                        emp.Manager__c = null;
                    }
                    toUpdate.add(emp);
                } else if(emp.Team__c == teamId) {
                    emp.Team__c = null;
                    emp.Department__c = null;
                    emp.Manager__c = null;
                    toUpdate.add(emp);
                }
            }

            if(!toUpdate.isEmpty()) {
                update toUpdate;
            }

        } catch(Exception e) {
            throw new AuraHandledException(
                e.getMessage());
        }
    }
}