public class EmployeeSharingService {

    public static void recalculateSharing(Set<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) return;

        deleteExistingShares(employeeIds);

        List<Employee__c> employees = [
            SELECT Id, 
                   User__c,
                   Department__c,
                   Team__c,
                   Team__r.Department__c,
                   Team__r.Department__r.Employee__c,
                   Team__r.Department__r.Employee__r.User__c,
                   Manager__c, 
                   Manager__r.User__c,
                   User_Type__c,
                   Status__c
            FROM Employee__c
            WHERE Id IN :employeeIds
            AND Status__c = 'Active'
        ];

        List<Employee__Share> empShares    = new List<Employee__Share>();
        List<Department__Share> deptShares = new List<Department__Share>();
        List<Team__Share> teamShares       = new List<Team__Share>();
        List<Attendance__Share> attShares = new List<Attendance__Share>();
        Map<Id, Employee__c> empMap = new Map<Id, Employee__c>();
        for(Employee__c e : employees) {
            empMap.put(e.Id, e);
        }
        for (Employee__c emp : employees) {

            // HOD fetch via Team → Department → Department Head
            Id hodUserId     = emp.Team__r.Department__r.Employee__r.User__c;
            Id hodTeamDeptId = emp.Team__r.Department__c;
            Id managerUserId = emp.Manager__r.User__c;

            // ── MANAGER SHARING ──────────────────────────────────────────────
            if (managerUserId != null && managerUserId != emp.User__c) {

                // Manager → Employee record (Edit)
                empShares.add(makeEmployeeShare(
                    emp.Id, managerUserId, 'Edit'
                ));

                // Manager → Team record (Read)
                if (emp.Team__c != null) {
                    teamShares.add(makeTeamShare(
                        emp.Team__c, managerUserId, 'Read'
                    ));
                }

                // Manager → Department record (Read)
                if (emp.Department__c != null) {
                    deptShares.add(makeDeptShare(
                        emp.Department__c, managerUserId, 'Read'
                    ));
                }
            }

            // ── HOD SHARING ───────────────────────────────────────────────────
            if (hodUserId != null && hodUserId != emp.User__c) {

                // HOD → Employee record (Read)
                empShares.add(makeEmployeeShare(
                    emp.Id, hodUserId, 'Read'
                ));

                // HOD → Team record (Read) — Team ke Department se
                if (emp.Team__c != null) {
                    teamShares.add(makeTeamShare(
                        emp.Team__c, hodUserId, 'Read'
                    ));
                }

                // HOD → Department record (Read) — Team ka Department
                if (hodTeamDeptId != null) {
                    deptShares.add(makeDeptShare(
                        hodTeamDeptId, hodUserId, 'Read'
                    ));
                }
            }
        }

        List<Attendance__c> attendances = [
            SELECT Id, Employee__c
            FROM Attendance__c
            WHERE Employee__c IN :employeeIds
        ];

        for(Attendance__c att : attendances) {
            Employee__c emp = empMap.get(att.Employee__c);
            if(emp == null) continue;

            Id managerUserId = emp.Manager__r.User__c;
            Id hodUserId =
                emp.Team__r.Department__r.Employee__r.User__c;

            // Manager → Attendance Read
            if(managerUserId != null && managerUserId != emp.User__c) {
                attShares.add(makeAttShare(
                    att.Id, managerUserId, 'Read'
                ));
            }

            // HOD → Attendance Read
            if(hodUserId != null && hodUserId != emp.User__c) {
                attShares.add(makeAttShare(
                    att.Id, hodUserId, 'Read'
                ));
            }
        }

        if(!attShares.isEmpty())
            Database.insert(attShares, false);

        if (!empShares.isEmpty())  Database.insert(empShares,  false);
        if (!deptShares.isEmpty()) Database.insert(deptShares, false);
        if (!teamShares.isEmpty()) Database.insert(teamShares, false);
    }

    // ── Delete existing manual shares ──────────────────────────────────────────

    private static void deleteExistingShares(Set<Id> employeeIds) {

        List<Employee__Share> oldEmpShares = [
            SELECT Id FROM Employee__Share
            WHERE ParentId IN :employeeIds
            AND RowCause = 'Manual'
        ];
        if (!oldEmpShares.isEmpty()) delete oldEmpShares;

        List<Employee__c> emps = [
            SELECT Department__c, Team__c,
                   Team__r.Department__c
            FROM Employee__c
            WHERE Id IN :employeeIds
        ];

        Set<Id> deptIds = new Set<Id>();
        Set<Id> teamIds = new Set<Id>();
        Set<Id> attIds = new Set<Id>();

        for(Attendance__c a : [
            SELECT Id FROM Attendance__c
            WHERE Employee__c IN :employeeIds
        ]) {
            attIds.add(a.Id);
        }

        if(!attIds.isEmpty()) {
            delete [
                SELECT Id FROM Attendance__Share
                WHERE ParentId IN :attIds
                AND RowCause = 'Manual'
            ];
        }

        for (Employee__c e : emps) {
            if (e.Department__c != null) deptIds.add(e.Department__c);
            // Team ka Department bhi add karo
            if (e.Team__r.Department__c != null) deptIds.add(e.Team__r.Department__c);
            if (e.Team__c != null) teamIds.add(e.Team__c);
        }

        if (!deptIds.isEmpty()) {
            List<Department__Share> oldDeptShares = [
                SELECT Id FROM Department__Share
                WHERE ParentId IN :deptIds
                AND RowCause = 'Manual'
            ];
            if (!oldDeptShares.isEmpty()) delete oldDeptShares;
        }

        if (!teamIds.isEmpty()) {
            List<Team__Share> oldTeamShares = [
                SELECT Id FROM Team__Share
                WHERE ParentId IN :teamIds
                AND RowCause = 'Manual'
            ];
            if (!oldTeamShares.isEmpty()) delete oldTeamShares;
        }
    }

    // ── Share record factories ─────────────────────────────────────────────────

    private static Employee__Share makeEmployeeShare(
        Id empId, Id userId, String accessLevel
    ) {
        Employee__Share s = new Employee__Share();
        s.ParentId      = empId;
        s.UserOrGroupId = userId;
        s.AccessLevel   = accessLevel;
        s.RowCause      = Schema.Employee__Share.RowCause.Manual;
        return s;
    }

    private static Department__Share makeDeptShare(
        Id deptId, Id userId, String accessLevel
    ) {
        Department__Share s = new Department__Share();
        s.ParentId      = deptId;
        s.UserOrGroupId = userId;
        s.AccessLevel   = accessLevel;
        s.RowCause      = Schema.Department__Share.RowCause.Manual;
        return s;
    }

    private static Team__Share makeTeamShare(
        Id teamId, Id userId, String accessLevel
    ) {
        Team__Share s = new Team__Share();
        s.ParentId      = teamId;
        s.UserOrGroupId = userId;
        s.AccessLevel   = accessLevel;
        s.RowCause      = Schema.Team__Share.RowCause.Manual;
        return s;
    }

    private static Attendance__Share makeAttShare(
        Id attId, Id userId, String accessLevel
    ) {
        Attendance__Share s = new Attendance__Share();
        s.ParentId = attId;
        s.UserOrGroupId = userId;
        s.AccessLevel = accessLevel;
        s.RowCause =
            Schema.Attendance__Share.RowCause.Manual;
        return s;
    }
}