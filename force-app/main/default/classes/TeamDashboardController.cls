public without sharing class TeamDashboardController {

    // Get Team Employees
    @AuraEnabled(cacheable=false)
    public static List<Employee__c> getTeamEmployees() {
        try {
            Employee__c currentEmp =
                getCurrentEmployee();
            if(currentEmp == null)
                return new List<Employee__c>();

            return [
                SELECT
                    Id,
                    First_Name__c,
                    Last_Name__c,
                    Email__c,
                    Phone__c,
                    Status__c,
                    User_Type__c,
                    Joining_Date__c
                FROM Employee__c
                WHERE Manager__c = :currentEmp.Id
                AND Status__c = 'Active'
            ];
        } catch(Exception e) {
            return new List<Employee__c>();
        }
    }

    // Get Team Attendance
    @AuraEnabled(cacheable=false)
    public static List<Attendance__c>
        getTeamAttendance(String employeeId) {
        try {
            Employee__c currentEmp =
                getCurrentEmployee();
            if(currentEmp == null)
                return new List<Attendance__c>();

            // Verify employee belongs to manager
            List<Employee__c> empCheck = [
                SELECT Id
                FROM Employee__c
                WHERE Id = :employeeId
                AND Manager__c = :currentEmp.Id
                LIMIT 1
            ];

            if(empCheck.isEmpty())
                return new List<Attendance__c>();

            return [
                SELECT
                    Id,
                    Attendance_Date__c,
                    Check_In__c,
                    Check_Out__c,
                    Working_Hours__c,
                    Attendance_Status__c
                FROM Attendance__c
                WHERE Employee__c = :employeeId
                ORDER BY Attendance_Date__c DESC
                LIMIT 30
            ];
        } catch(Exception e) {
            return new List<Attendance__c>();
        }
    }

    // Get Team Leave Requests
    @AuraEnabled(cacheable=false)
    public static List<Leave_Request__c>
        getTeamLeaves() {
        try {
            Employee__c currentEmp =
                getCurrentEmployee();
            if(currentEmp == null)
                return new List<Leave_Request__c>();

            // Get team employee ids
            List<Employee__c> teamEmps = [
                SELECT Id
                FROM Employee__c
                WHERE Manager__c = :currentEmp.Id
                AND Status__c = 'Active'
            ];

            Set<Id> teamEmpIds = new Set<Id>();
            for(Employee__c emp : teamEmps) {
                teamEmpIds.add(emp.Id);
            }

            if(teamEmpIds.isEmpty())
                return new List<Leave_Request__c>();

            return [
                SELECT
                    Id,
                    Employee__c,
                    Employee__r.First_Name__c,
                    Employee__r.Last_Name__c,
                    Leave_Type__c,
                    Start_Date__c,
                    End_Date__c,
                    Number_Of_Days__c,
                    Reason__c,
                    Status__c
                FROM Leave_Request__c
                WHERE Employee__c IN :teamEmpIds
                AND Status__c = 'Submitted'
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            return new List<Leave_Request__c>();
        }
    }

    // Get Team Expenses
    @AuraEnabled(cacheable=false)
    public static List<Expense__c>
        getTeamExpenses() {
        try {
            Employee__c currentEmp =
                getCurrentEmployee();
            if(currentEmp == null)
                return new List<Expense__c>();

            List<Employee__c> teamEmps = [
                SELECT Id
                FROM Employee__c
                WHERE Manager__c = :currentEmp.Id
                AND Status__c = 'Active'
            ];

            Set<Id> teamEmpIds = new Set<Id>();
            for(Employee__c emp : teamEmps) {
                teamEmpIds.add(emp.Id);
            }

            if(teamEmpIds.isEmpty())
                return new List<Expense__c>();

            return [
                SELECT
                    Id,
                    Employee__c,
                    Employee__r.First_Name__c,
                    Employee__r.Last_Name__c,
                    Claim_Title__c,
                    Expense_Date__c,
                    Total_Amount__c,
                    Status__c
                FROM Expense__c
                WHERE Employee__c IN :teamEmpIds
                AND Status__c = 'Submitted'
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            return new List<Expense__c>();
        }
    }
    
    // getTeamLeaveBalances()
    @AuraEnabled(cacheable=false)
    public static Map<Id, Leave_Balance__c>
        getTeamLeaveBalances() {
        try {
            Employee__c currentEmp =
                getCurrentEmployee();
            if(currentEmp == null)
                return new Map<Id, Leave_Balance__c>();

            List<Employee__c> teamEmps = [
                SELECT Id
                FROM Employee__c
                WHERE Manager__c = :currentEmp.Id
                AND Status__c = 'Active'
            ];

            Set<Id> teamEmpIds = new Set<Id>();
            for(Employee__c emp : teamEmps) {
                teamEmpIds.add(emp.Id);
            }

            if(teamEmpIds.isEmpty())
                return new Map<Id, Leave_Balance__c>();

            Map<Id, Leave_Balance__c> balanceMap =
                new Map<Id, Leave_Balance__c>();

            for(Leave_Balance__c lb : [
                SELECT
                    Id,
                    Employee_Leaves__c,
                    PTO_Total__c, PTO_Used__c,
                    PTO_Remaining__c,
                    Sick_Total__c, Sick_Used__c,
                    Sick_Remaining__c,
                    Bereavement_Total__c,
                    Bereavement_Used__c,
                    Bereavement_Remaining__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c IN :teamEmpIds
                AND Year__c = :Date.today().year()
            ]) {
                balanceMap.put(lb.Employee_Leaves__c, lb);
            }

            return balanceMap;
        } catch(Exception e) {
            return new Map<Id, Leave_Balance__c>();
        }
    }
    // Validate Leave Balance Before Approve
    @AuraEnabled
    public static void updateLeaveStatus(
        String leaveId,
        String status,
        String remarks
    ) {
        Employee__c currentEmp =
            getCurrentEmployee();
        if(currentEmp == null)
            throw new AuraHandledException(
                'Employee not found');

        List<Leave_Request__c> leaves = [
            SELECT
                Id,
                Status__c,
                Employee__c,
                Leave_Type__c,
                Number_Of_Days__c,
                Employee__r.Manager__c
            FROM Leave_Request__c
            WHERE Id = :leaveId
            LIMIT 1
        ];

        if(leaves.isEmpty())
            throw new AuraHandledException(
                'Leave request not found');

        // Verify manager access
        if(leaves[0].Employee__r.Manager__c
            != currentEmp.Id)
            throw new AuraHandledException(
                'Access denied');

        // Balance check before approve
        if(status == 'Manager Approved') {
            List<Leave_Balance__c> balances = [
                SELECT
                    Id,
                    PTO_Remaining__c,
                    Sick_Remaining__c,
                    Bereavement_Remaining__c
                FROM Leave_Balance__c
                WHERE Employee_Leaves__c =
                    :leaves[0].Employee__c
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];

            if(balances.isEmpty()) {
                throw new AuraHandledException(
                    'Leave balance not found'
                );
            }

            Decimal remaining = 0;

            // Check remaining balance based on leave type
            if(leaves[0].Leave_Type__c ==
                'Paid Time Off') {

                remaining =
                    balances[0].PTO_Remaining__c ?? 0;

            } else if(leaves[0].Leave_Type__c ==
                'Sick') {

                remaining =
                    balances[0].Sick_Remaining__c ?? 0;

            } else if(leaves[0].Leave_Type__c ==
                'Bereavement') {

                remaining =
                    balances[0]
                        .Bereavement_Remaining__c ?? 0;
            }

            if(remaining <
                leaves[0].Number_Of_Days__c) {

                throw new AuraHandledException(
                    'Insufficient leave balance. ' +
                    'Available: ' +
                    remaining +
                    ' days. Requested: ' +
                    leaves[0].Number_Of_Days__c +
                    ' days.'
                );
            }
        }

        leaves[0].Status__c = status;
        update leaves[0];
    }

    // Approve/Reject Expense
    @AuraEnabled
    public static void updateExpenseStatus(
        String expenseId,
        String status,
        String remarks
    ) {
        Employee__c currentEmp =
            getCurrentEmployee();
        if(currentEmp == null)
            throw new AuraHandledException(
                'Employee not found');

        List<Expense__c> expenses = [
            SELECT
                Id,
                Status__c,
                Employee__c,
                Employee__r.Manager__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];

        if(expenses.isEmpty())
            throw new AuraHandledException(
                'Expense not found');

        // Verify manager access
        if(expenses[0].Employee__r.Manager__c
            != currentEmp.Id)
            throw new AuraHandledException(
                'Access denied');

        expenses[0].Status__c = status;
        update expenses[0];
    }

    // Get Current Employee
    private static Employee__c getCurrentEmployee() {
        Id userId = UserInfo.getUserId();
        List<Employee__c> emps = [
            SELECT Id, First_Name__c,
                Last_Name__c, User_Type__c
            FROM Employee__c
            WHERE User__c = :userId
            AND Status__c = 'Active'
            LIMIT 1
        ];
        return emps.isEmpty() ? null : emps[0];
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkIsManager() {
        String roleType =
            UserInfoController.getUserRoleType();
        String normalizedRole =
            roleType != null
                ? roleType.trim().toLowerCase()
                : '';

        return normalizedRole == 'manager' ||
            normalizedRole == 'team manager' ||
            normalizedRole == 'hod';
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getMyTeamInfo() {
        try {
            List<Employee__c> emps = [
                SELECT 
                    Id,
                    First_Name__c,
                    Last_Name__c,
                    User_Type__c,
                    Team__c,
                    Team__r.Name,
                    Team__r.Employee__c,
                    Team__r.Employee__r.First_Name__c,
                    Team__r.Employee__r.Last_Name__c,
                    Department__c,
                    Department__r.Name
                FROM Employee__c
                WHERE User__c = :UserInfo.getUserId()
                AND Status__c = 'Active'
                LIMIT 1
            ];

            if(emps.isEmpty()) {
                return null;
            }
            
            Employee__c currentEmp = emps[0];

            Map<String, Object> result = new Map<String, Object>();

            // ── HOD — Department level info ───────────────────────────────
            if(currentEmp.User_Type__c == 'HOD') {

                // Department ki saari teams
                List<Team__c> deptTeams = [
                    SELECT Id, Name
                    FROM Team__c
                    WHERE Department__c = :currentEmp.Department__c
                    AND Status__c = 'Active'
                ];

                Set<Id> teamIds = new Set<Id>();
                for(Team__c t : deptTeams) teamIds.add(t.Id);

                // Department ke saare employees
                List<Employee__c> deptMembers = new List<Employee__c>();
                if(!teamIds.isEmpty()) {
                    deptMembers = [
                        SELECT 
                            Id,
                            First_Name__c,
                            Last_Name__c,
                            Email__c,
                            Status__c,
                            Team__r.Name
                        FROM Employee__c
                        WHERE Team__c IN :teamIds
                        AND Status__c = 'Active'
                    ];
                }

                List<Map<String, String>> memberList = 
                    new List<Map<String, String>>();

                for(Employee__c emp : deptMembers) {
                    Map<String, String> m = new Map<String, String>();
                    m.put('firstName', emp.First_Name__c);
                    m.put('lastName', emp.Last_Name__c);
                    m.put('email', emp.Email__c);
                    m.put('status', emp.Status__c);
                    m.put('teamName', emp.Team__r.Name);
                    memberList.add(m);
                }

                result.put('teamName', null);
                result.put('departmentName', currentEmp.Department__r != null ? currentEmp.Department__r.Name : null);
                result.put('managerName', null);
                result.put('isHOD', true);
                result.put('members', memberList);

            // ── Team Manager / Employee — Team level info ─────────────────
            } else {

                if(currentEmp.Team__c == null) {
                    result.put('teamName', null);
                    result.put('departmentName', null);
                    result.put('managerName', null);
                    result.put('isHOD', false);
                    result.put('members', new List<Map<String, String>>());
                    return result;
                }

                List<Employee__c> teamMembers = [
                    SELECT 
                        Id,
                        First_Name__c,
                        Last_Name__c,
                        Email__c,
                        Status__c
                    FROM Employee__c
                    WHERE Team__c = :currentEmp.Team__c
                    AND Status__c = 'Active'
                ];

                List<Map<String, String>> memberList = 
                    new List<Map<String, String>>();

                for(Employee__c emp : teamMembers) {
                    Map<String, String> m = new Map<String, String>();
                    m.put('firstName', emp.First_Name__c);
                    m.put('lastName', emp.Last_Name__c);
                    m.put('email', emp.Email__c);
                    m.put('status', emp.Status__c);
                    memberList.add(m);
                }

                String managerName = '';
                if(currentEmp.Team__r.Employee__c != null) {
                    managerName = 
                        (currentEmp.Team__r.Employee__r.First_Name__c != null 
                            ? currentEmp.Team__r.Employee__r.First_Name__c 
                            : '') 
                        + ' ' + 
                        (currentEmp.Team__r.Employee__r.Last_Name__c != null 
                            ? currentEmp.Team__r.Employee__r.Last_Name__c 
                            : '');
                }

                result.put('teamName', currentEmp.Team__r.Name);
                result.put('departmentName', 
                    currentEmp.Team__r != null 
                        ? currentEmp.Team__r.Name 
                        : null);
                result.put('managerName', managerName.trim());
                result.put('isHOD', false);
                result.put('members', memberList);
            }

            return result;

        } catch(Exception e) {
            System.debug('getMyTeamInfo error: ' + e.getMessage());
            System.debug('Line: ' + e.getLineNumber());
            return null;
        }
    }
}
