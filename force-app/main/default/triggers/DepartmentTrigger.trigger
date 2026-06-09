trigger DepartmentTrigger on Department__c (before insert, before update, after update) {

    // ── BEFORE: Validation ────────────────────────────────────────────────────
    if (Trigger.isBefore) {

        Set<Id> newHODEmpIds = new Set<Id>();

        for (Department__c dept : Trigger.new) {
            if (dept.Employee__c == null) continue;
            if (Trigger.isInsert) {
                newHODEmpIds.add(dept.Employee__c);
            } else if (Trigger.isUpdate && 
                    dept.Employee__c != Trigger.oldMap.get(dept.Id).Employee__c) {
                newHODEmpIds.add(dept.Employee__c);
            }
        }

        if (!newHODEmpIds.isEmpty()) {

            // Insert pe existing department IDs exclude karne ke liye alag set
            Set<Id> existingDeptIds = new Set<Id>();
            if (Trigger.isUpdate) {
                existingDeptIds.addAll(Trigger.newMap.keySet());
            }

            List<Department__c> existing = [
                SELECT Id, Name, Employee__c
                FROM Department__c
                WHERE Employee__c IN :newHODEmpIds
                AND Id NOT IN :existingDeptIds
            ];

            Map<Id, String> empToDeptName = new Map<Id, String>();
            for (Department__c d : existing) {
                empToDeptName.put(d.Employee__c, d.Name);
            }

            for (Department__c dept : Trigger.new) {
                if (dept.Employee__c != null && 
                    empToDeptName.containsKey(dept.Employee__c)) {
                    dept.Employee__c.addError(
                        'This Employee is already HOD of ' + 
                        empToDeptName.get(dept.Employee__c) + 
                        '. One Employee can head only one Department.'
                    );
                }
            }
        }
    }

    // ── AFTER UPDATE: Recalculate Sharing only ────────────────────────────────
    if (Trigger.isAfter && Trigger.isUpdate) {

        Set<Id> deptIds      = new Set<Id>();
        Set<Id> oldHODEmpIds = new Set<Id>();

        for (Department__c dept : Trigger.new) {
            Department__c old = Trigger.oldMap.get(dept.Id);
            if (dept.Employee__c != old.Employee__c) {
                deptIds.add(dept.Id);
                if (old.Employee__c != null) {
                    oldHODEmpIds.add(old.Employee__c);
                }
            }
        }

        if (deptIds.isEmpty()) return;

        // Fetch old HOD User Ids
        Set<Id> oldHODUserIds = new Set<Id>();
        if (!oldHODEmpIds.isEmpty()) {
            for (Employee__c e : [
                SELECT Id, User__c
                FROM Employee__c
                WHERE Id IN :oldHODEmpIds
            ]) {
                if (e.User__c != null) oldHODUserIds.add(e.User__c);
            }
        }

        // ── Delete old HOD shares ─────────────────────────────────────────────
        if (!oldHODUserIds.isEmpty()) {

            // Department shares
            List<Department__Share> oldDeptShares = [
                SELECT Id FROM Department__Share
                WHERE ParentId IN :deptIds
                AND UserOrGroupId IN :oldHODUserIds
                AND RowCause = 'Manual'
            ];
            if (!oldDeptShares.isEmpty()) delete oldDeptShares;

            // Team shares
            Set<Id> teamIds = new Set<Id>();
            for (Team__c t : [
                SELECT Id FROM Team__c 
                WHERE Department__c IN :deptIds
            ]) {
                teamIds.add(t.Id);
            }
            if (!teamIds.isEmpty()) {
                List<Team__Share> oldTeamShares = [
                    SELECT Id FROM Team__Share
                    WHERE ParentId IN :teamIds
                    AND UserOrGroupId IN :oldHODUserIds
                    AND RowCause = 'Manual'
                ];
                if (!oldTeamShares.isEmpty()) delete oldTeamShares;
            }

            // Employee shares
            List<Employee__Share> oldEmpShares = [
                SELECT Id FROM Employee__Share
                WHERE UserOrGroupId IN :oldHODUserIds
                AND RowCause = 'Manual'
            ];
            if (!oldEmpShares.isEmpty()) delete oldEmpShares;
        }

        // ── Recalculate sharing for all dept employees ────────────────────────
        Set<Id> empIds = new Set<Id>();
        for (Employee__c e : [
            SELECT Id FROM Employee__c
            WHERE Department__c IN :deptIds
        ]) {
            empIds.add(e.Id);
        }
        if (!empIds.isEmpty()) {
            EmployeeSharingService.recalculateSharing(empIds);
        }
    }
}