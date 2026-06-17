public without sharing class EmployeeSharingService {

    // ═══════════════════════════════════════════════════════════════════════
    // RECALCULATE ALL SHARING (Batch use karta hai)
    // ═══════════════════════════════════════════════════════════════════════
    public static void recalculateSharing(Set<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) return;

        deleteExistingShares(employeeIds);

        List<Employee__c> employees = [
            SELECT Id, User__c, Department__c, Team__c,
                   Team__r.Department__c,
                   Team__r.Department__r.Employee__c,
                   Team__r.Department__r.Employee__r.User__c,
                   Manager__c, Manager__r.User__c,
                   User_Type__c, Status__c
            FROM Employee__c
            WHERE Id IN :employeeIds
            AND Status__c = 'Active'
        ];

        Map<Id, Employee__c> empMap = new Map<Id, Employee__c>();
        for (Employee__c e : employees) empMap.put(e.Id, e);

        Map<String, SObject> empSharesMap   = new Map<String, SObject>();
        Map<String, SObject> deptSharesMap  = new Map<String, SObject>();
        Map<String, SObject> teamSharesMap  = new Map<String, SObject>();
        Map<String, SObject> attSharesMap   = new Map<String, SObject>();
        Map<String, SObject> expSharesMap   = new Map<String, SObject>();
        Map<String, SObject> leaveSharesMap = new Map<String, SObject>();
        Map<String, SObject> lbSharesMap    = new Map<String, SObject>();

        // ── Employee / Team / Department sharing ─────────────────────────
        for (Employee__c emp : employees) {
            Id managerUserId = getManagerUserId(emp);
            Id hodUserId     = getHodUserId(emp);
            Id deptId        = getDeptId(emp);

            if (managerUserId != null && managerUserId != emp.User__c) {
                addShare(empSharesMap, emp.Id, managerUserId, 'Edit', 'Employee__Share');
                if (emp.Team__c != null) addShare(teamSharesMap, emp.Team__c, managerUserId, 'Read', 'Team__Share');
                if (deptId != null) addShare(deptSharesMap, deptId, managerUserId, 'Read', 'Department__Share');
            }

            if (hodUserId != null && hodUserId != emp.User__c) {
                addShare(empSharesMap, emp.Id, hodUserId, 'Read', 'Employee__Share');
                if (emp.Team__c != null) addShare(teamSharesMap, emp.Team__c, hodUserId, 'Read', 'Team__Share');
                if (deptId != null) addShare(deptSharesMap, deptId, hodUserId, 'Read', 'Department__Share');
            }
        }

        // ── Attendance sharing ───────────────────────────────────────────
        for (Attendance__c att : [
            SELECT Id, Employee__c, OwnerId FROM Attendance__c
            WHERE Employee__c IN :employeeIds
        ]) {
            Employee__c emp = empMap.get(att.Employee__c);
            if (emp == null) continue;

            Id mgrU = getManagerUserId(emp);
            Id hodU = getHodUserId(emp);

            if (emp.User__c != null && emp.User__c != att.OwnerId) addShare(attSharesMap, att.Id, emp.User__c, 'Edit', 'Attendance__Share');
            if (mgrU != null && mgrU != emp.User__c && mgrU != att.OwnerId) addShare(attSharesMap, att.Id, mgrU, 'Read', 'Attendance__Share');
            if (hodU != null && hodU != emp.User__c && hodU != att.OwnerId) addShare(attSharesMap, att.Id, hodU, 'Read', 'Attendance__Share');
        }

        // ── Expense sharing ──────────────────────────────────────────────
        for (Expense__c exp : [
            SELECT Id, Employee__c, OwnerId, Finance_User__c, Finance_User__r.User__c
            FROM Expense__c
            WHERE Employee__c IN :employeeIds
        ]) {
            Employee__c emp = empMap.get(exp.Employee__c);
            if (emp == null) continue;

            Id mgrU = getManagerUserId(emp);
            Id hodU = getHodUserId(emp);
            Id finU = (exp.Finance_User__c != null && exp.Finance_User__r != null) ? exp.Finance_User__r.User__c : null;

            if (emp.User__c != null && emp.User__c != exp.OwnerId) addShare(expSharesMap, exp.Id, emp.User__c, 'Edit', 'Expense__Share');
            if (mgrU != null && mgrU != emp.User__c && mgrU != exp.OwnerId) addShare(expSharesMap, exp.Id, mgrU, 'Edit', 'Expense__Share');
            if (hodU != null && hodU != emp.User__c && hodU != exp.OwnerId) addShare(expSharesMap, exp.Id, hodU, 'Read', 'Expense__Share');
            if (finU != null && finU != emp.User__c && finU != exp.OwnerId) addShare(expSharesMap, exp.Id, finU, 'Edit', 'Expense__Share');
        }

        // ── Leave Request sharing ────────────────────────────────────────
        for (Leave_Request__c lr : [
            SELECT Id, Employee__c, OwnerId FROM Leave_Request__c
            WHERE Employee__c IN :employeeIds
        ]) {
            Employee__c emp = empMap.get(lr.Employee__c);
            if (emp == null) continue;

            Id mgrU = getManagerUserId(emp);
            Id hodU = getHodUserId(emp);

            if (emp.User__c != null && emp.User__c != lr.OwnerId) addShare(leaveSharesMap, lr.Id, emp.User__c, 'Edit', 'Leave_Request__Share');
            if (mgrU != null && mgrU != emp.User__c && mgrU != lr.OwnerId) addShare(leaveSharesMap, lr.Id, mgrU, 'Edit', 'Leave_Request__Share');
            if (hodU != null && hodU != emp.User__c && hodU != lr.OwnerId) addShare(leaveSharesMap, lr.Id, hodU, 'Read', 'Leave_Request__Share');
        }

        // ── Leave Balance sharing ────────────────────────────────────────
        for (Leave_Balance__c lb : [
            SELECT Id, Employee_Leaves__c, OwnerId FROM Leave_Balance__c
            WHERE Employee_Leaves__c IN :employeeIds
        ]) {
            Employee__c emp = empMap.get(lb.Employee_Leaves__c);
            if (emp == null) continue;

            Id mgrU = getManagerUserId(emp);
            Id hodU = getHodUserId(emp);

            if (emp.User__c != null && emp.User__c != lb.OwnerId) addShare(lbSharesMap, lb.Id, emp.User__c, 'Edit', 'Leave_Balance__Share');
            if (mgrU != null && mgrU != emp.User__c && mgrU != lb.OwnerId) addShare(lbSharesMap, lb.Id, mgrU, 'Read', 'Leave_Balance__Share');
            if (hodU != null && hodU != emp.User__c && hodU != lb.OwnerId) addShare(lbSharesMap, lb.Id, hodU, 'Read', 'Leave_Balance__Share');
        }

        // ── Insert all shares ────────────────────────────────────────────
        insertShares(empSharesMap.values());
        insertShares(deptSharesMap.values());
        insertShares(teamSharesMap.values());
        insertShares(attSharesMap.values());
        insertShares(expSharesMap.values());
        insertShares(leaveSharesMap.values());
        insertShares(lbSharesMap.values());

        System.debug('Employee Shares: '      + empSharesMap.size());
        System.debug('Department Shares: '    + deptSharesMap.size());
        System.debug('Team Shares: '          + teamSharesMap.size());
        System.debug('Attendance Shares: '    + attSharesMap.size());
        System.debug('Expense Shares: '       + expSharesMap.size());
        System.debug('Leave Shares: '         + leaveSharesMap.size());
        System.debug('Leave Balance Shares: ' + lbSharesMap.size());
    }

    private static void addShare(Map<String, SObject> shareMap, Id parentId, Id userId, String accessLevel, String sObjectType) {
        String key = parentId + '_' + userId;
        if (!shareMap.containsKey(key)) {
            SObject newShare = Schema.getGlobalDescribe().get(sObjectType).newSObject();
            newShare.put('ParentId', parentId);
            newShare.put('UserOrGroupId', userId);
            newShare.put('AccessLevel', accessLevel);
            newShare.put('RowCause', 'Manual');
            shareMap.put(key, newShare);
        } else {
            SObject existingShare = shareMap.get(key);
            if (accessLevel == 'Edit' && existingShare.get('AccessLevel') == 'Read') {
                existingShare.put('AccessLevel', 'Edit');
            }
        }
    }

    private static void insertShares(List<SObject> shares) {
        if (shares.isEmpty()) return;
        Database.SaveResult[] results = Database.insert(shares, false);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('Share Insert Failed: ' + err.getStatusCode() + ': ' + err.getMessage());
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DELETE EXISTING SHARES
    // ═══════════════════════════════════════════════════════════════════════
    private static void deleteExistingShares(Set<Id> employeeIds) {

        // Employee shares
        Database.delete([
            SELECT Id FROM Employee__Share
            WHERE ParentId IN :employeeIds
            AND RowCause = 'Manual'
        ], false);

        // Collect related record Ids
        Set<Id> deptIds  = new Set<Id>();
        Set<Id> teamIds  = new Set<Id>();
        Set<Id> attIds   = new Set<Id>();
        Set<Id> expIds   = new Set<Id>();
        Set<Id> leaveIds = new Set<Id>();
        Set<Id> lbIds    = new Set<Id>();

        for (Employee__c e : [
            SELECT Department__c, Team__c, Team__r.Department__c
            FROM Employee__c WHERE Id IN :employeeIds
        ]) {
            if (e.Department__c != null)         deptIds.add(e.Department__c);
            if (e.Team__c != null)               teamIds.add(e.Team__c);
            if (e.Team__r?.Department__c != null) deptIds.add(e.Team__r.Department__c);
        }

        for (Attendance__c a    : [SELECT Id FROM Attendance__c    WHERE Employee__c IN :employeeIds])      attIds.add(a.Id);
        for (Expense__c e       : [SELECT Id FROM Expense__c       WHERE Employee__c IN :employeeIds])      expIds.add(e.Id);
        for (Leave_Request__c l : [SELECT Id FROM Leave_Request__c WHERE Employee__c IN :employeeIds])      leaveIds.add(l.Id);
        for (Leave_Balance__c lb: [SELECT Id FROM Leave_Balance__c WHERE Employee_Leaves__c IN :employeeIds]) lbIds.add(lb.Id);

        if (!deptIds.isEmpty())
            Database.delete([SELECT Id FROM Department__Share WHERE ParentId IN :deptIds AND RowCause = 'Manual'], false);
        if (!teamIds.isEmpty())
            Database.delete([SELECT Id FROM Team__Share WHERE ParentId IN :teamIds AND RowCause = 'Manual'], false);
        if (!attIds.isEmpty())
            Database.delete([SELECT Id FROM Attendance__Share WHERE ParentId IN :attIds AND RowCause = 'Manual'], false);
        if (!leaveIds.isEmpty())
            Database.delete([SELECT Id FROM Leave_Request__Share WHERE ParentId IN :leaveIds AND RowCause = 'Manual'], false);
        if (!lbIds.isEmpty())
            Database.delete([SELECT Id FROM Leave_Balance__Share WHERE ParentId IN :lbIds AND RowCause = 'Manual'], false);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════════════
    private static Id getManagerUserId(Employee__c emp) {
        return (emp.Manager__r != null) ? emp.Manager__r.User__c : null;
    }

    private static Id getHodUserId(Employee__c emp) {
        if (emp.Team__r == null) return null;
        if (emp.Team__r.Department__r == null) return null;
        if (emp.Team__r.Department__r.Employee__r == null) return null;
        return emp.Team__r.Department__r.Employee__r.User__c;
    }

    private static Id getDeptId(Employee__c emp) {
        if (emp.Team__r != null && emp.Team__r.Department__c != null)
            return emp.Team__r.Department__c;
        return emp.Department__c;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SHARE FACTORY METHODS
    // ═══════════════════════════════════════════════════════════════════════
    private static Employee__Share makeEmployeeShare(Id parentId, Id userId, String access) {
        Employee__Share s = new Employee__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Employee__Share.RowCause.Manual; return s;
    }
    private static Department__Share makeDeptShare(Id parentId, Id userId, String access) {
        Department__Share s = new Department__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Department__Share.RowCause.Manual; return s;
    }
    private static Team__Share makeTeamShare(Id parentId, Id userId, String access) {
        Team__Share s = new Team__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Team__Share.RowCause.Manual; return s;
    }
    private static Attendance__Share makeAttShare(Id parentId, Id userId, String access) {
        Attendance__Share s = new Attendance__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Attendance__Share.RowCause.Manual; return s;
    }
    private static Expense__Share makeExpenseShare(Id parentId, Id userId, String access) {
        Expense__Share s = new Expense__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Expense__Share.RowCause.Manual; return s;
    }
    private static Leave_Request__Share makeLeaveShare(Id parentId, Id userId, String access) {
        Leave_Request__Share s = new Leave_Request__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Leave_Request__Share.RowCause.Manual; return s;
    }
    private static Leave_Balance__Share makeLeaveBalanceShare(Id parentId, Id userId, String access) {
        Leave_Balance__Share s = new Leave_Balance__Share();
        s.ParentId = parentId; s.UserOrGroupId = userId; s.AccessLevel = access;
        s.RowCause = Schema.Leave_Balance__Share.RowCause.Manual; return s;
    }

    public static void shareExpenses(Set<Id> expenseIds) {
    if (expenseIds == null || expenseIds.isEmpty()) return;

    // Purane manual shares delete karo
    List<Expense__Share> oldShares = [
        SELECT Id FROM Expense__Share
        WHERE ParentId IN :expenseIds
        AND RowCause = 'Manual'
    ];
    if (!oldShares.isEmpty()) Database.delete(oldShares, false);

    // Expenses fetch karo
    List<Expense__c> expenses = [
        SELECT Id, Employee__c,
               Employee__r.User__c,
               Employee__r.User_Type__c,
               Employee__r.Manager__c,
               Employee__r.Manager__r.User__c,
               Employee__r.Team__c,
               Employee__r.Team__r.Department__r.Employee__r.User__c,
               Finance_User__c,
               Finance_User__r.User__c,
               OwnerId
        FROM Expense__c
        WHERE Id IN :expenseIds
        AND Employee__c != null
    ];

    List<Expense__Share> shares = new List<Expense__Share>();

        for (Expense__c exp : expenses) {
            Id empU = exp.Employee__r.User__c;
            Id ownerId = exp.OwnerId;

            Id mgrU = (exp.Employee__r.Manager__r != null)
                    ? exp.Employee__r.Manager__r.User__c : null;

            Id hodU = (exp.Employee__r.Team__r != null
                    && exp.Employee__r.Team__r.Department__r != null
                    && exp.Employee__r.Team__r.Department__r.Employee__r != null)
                    ? exp.Employee__r.Team__r.Department__r.Employee__r.User__c : null;

            Id finU = (exp.Finance_User__c != null && exp.Finance_User__r != null)
                    ? exp.Finance_User__r.User__c : null;

            // Employee User — agar owner nahi hai toh share do
            if (empU != null && empU != ownerId)
                shares.add(makeExpenseShare(exp.Id, empU, 'Edit'));

            // Manager → Edit
            if (mgrU != null && mgrU != empU && mgrU != ownerId)
                shares.add(makeExpenseShare(exp.Id, mgrU, 'Edit'));

            // HOD → Read
            if (hodU != null && hodU != empU && hodU != ownerId)
                shares.add(makeExpenseShare(exp.Id, hodU, 'Read'));

            // Finance User → Edit
            if (finU != null && finU != empU && finU != ownerId)
                shares.add(makeExpenseShare(exp.Id, finU, 'Edit'));

            System.debug('Expense: ' + exp.Id
                + ' | empU: ' + empU
                + ' | mgrU: ' + mgrU
                + ' | hodU: ' + hodU
                + ' | finU: ' + finU
                + ' | owner: ' + ownerId);
        }

        System.debug('Total Expense Shares to insert: ' + shares.size());

        if (!shares.isEmpty()) {
            Database.SaveResult[] results = Database.insert(shares, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('FAILED: ' + shares[i].ParentId
                        + ' | ' + shares[i].UserOrGroupId
                        + ' | ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SHARE LEAVE REQUESTS
    // ═══════════════════════════════════════════════════════════════════════
    public static void shareLeaveRequests(Set<Id> leaveIds) {
        if (leaveIds == null || leaveIds.isEmpty()) return;

        List<Leave_Request__Share> oldShares = [SELECT Id FROM Leave_Request__Share WHERE ParentId IN :leaveIds AND RowCause = 'Manual'];
        if (!oldShares.isEmpty()) Database.delete(oldShares, false);

        List<Leave_Request__c> leaves = [
            SELECT Id, Employee__c, OwnerId, Employee__r.User__c, Employee__r.Manager__r.User__c, Employee__r.Team__r.Department__r.Employee__r.User__c
            FROM Leave_Request__c WHERE Id IN :leaveIds AND Employee__c != null
        ];

        List<Leave_Request__Share> shares = new List<Leave_Request__Share>();
        for (Leave_Request__c lr : leaves) {
            Id empU = lr.Employee__r.User__c;
            Id mgrU = lr.Employee__r.Manager__r?.User__c;
            Id hodU = lr.Employee__r.Team__r?.Department__r?.Employee__r?.User__c;
            Id ownerId = lr.OwnerId;

            if (empU != null && empU != ownerId) shares.add(makeLeaveShare(lr.Id, empU, 'Edit'));
            if (mgrU != null && mgrU != empU && mgrU != ownerId) shares.add(makeLeaveShare(lr.Id, mgrU, 'Edit'));
            if (hodU != null && hodU != empU && hodU != ownerId) shares.add(makeLeaveShare(lr.Id, hodU, 'Read'));
        }
        
        if (!shares.isEmpty()) Database.insert(shares, false);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SHARE ATTENDANCES
    // ═══════════════════════════════════════════════════════════════════════
    public static void shareAttendances(Set<Id> attendanceIds) {
        if (attendanceIds == null || attendanceIds.isEmpty()) return;

        List<Attendance__Share> oldShares = [SELECT Id FROM Attendance__Share WHERE ParentId IN :attendanceIds AND RowCause = 'Manual'];
        if (!oldShares.isEmpty()) Database.delete(oldShares, false);

        List<Attendance__c> records = [
            SELECT Id, Employee__c, OwnerId, Employee__r.User__c, Employee__r.Manager__r.User__c, Employee__r.Team__r.Department__r.Employee__r.User__c
            FROM Attendance__c WHERE Id IN :attendanceIds AND Employee__c != null
        ];

        List<Attendance__Share> shares = new List<Attendance__Share>();
        for (Attendance__c att : records) {
            Id empU = att.Employee__r.User__c;
            Id mgrU = att.Employee__r.Manager__r?.User__c;
            Id hodU = att.Employee__r.Team__r?.Department__r?.Employee__r?.User__c;
            Id ownerId = att.OwnerId;

            if (empU != null && empU != ownerId) shares.add(makeAttShare(att.Id, empU, 'Edit'));
            if (mgrU != null && mgrU != empU && mgrU != ownerId) shares.add(makeAttShare(att.Id, mgrU, 'Read'));
            if (hodU != null && hodU != empU && hodU != ownerId) shares.add(makeAttShare(att.Id, hodU, 'Read'));
        }
        
        if (!shares.isEmpty()) Database.insert(shares, false);
    }
}