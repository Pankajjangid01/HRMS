public without sharing class HRMSDashboardController {

    // Get My Leave Requests
    @AuraEnabled(cacheable=false)
    public static List<Leave_Request__c> getMyLeaves() {
        try {
            Employee__c emp = getCurrentEmployee();
            return [
                SELECT Id, Name, Leave_Type__c,
                    Start_Date__c, End_Date__c,
                    Number_Of_Days__c, Status__c,
                    Reason__c
                FROM Leave_Request__c
                WHERE Employee__c = :emp.Id
                ORDER BY CreatedDate DESC
            ];
        } catch(Exception e) {
            return new List<Leave_Request__c>();
        }
    }

    // ── Get My Recent Expenses ─────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Expense__c> getMyExpenses() {
        try {
            Employee__c emp = getCurrentEmployee();
            return [
                SELECT Id, Claim_Title__c,
                    Total_Amount__c, Status__c,
                    Expense_Date__c
                FROM Expense__c
                WHERE Employee__c = :emp.Id
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
        } catch(Exception e) {
            return new List<Expense__c>();
        }
    }

    // ── Create Draft Expense ─────────────────────────────────────────────────
    @AuraEnabled
    public static String createDraftExpense() {
        Employee__c emp = getCurrentEmployee();
        Expense__c exp = new Expense__c();
        exp.Employee__c = emp.Id;
        exp.Status__c = 'Draft';
        exp.Expense_Date__c = Date.today();
        exp.Claim_Title__c = 'Draft';
        insert exp;

        return exp.Id;
    }

    // ── Get Current Employee ──────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrentEmployeeInfo() {
        try {
            Id userId = UserInfo.getUserId();
            List<Employee__c> emps = [
                SELECT 
                    Id, First_Name__c, Last_Name__c,
                    User_Type__c, Department__c,
                    Department__r.Name, Team__c,
                    Team__r.Name, Designation__c,
                    Status__c
                FROM Employee__c
                WHERE User__c = :userId
                AND Status__c = 'Active'
                LIMIT 1
            ];

            if(emps.isEmpty()) return null;

            Employee__c emp = emps[0];
            Map<String, Object> result = new Map<String, Object>();
            result.put('id', emp.Id);
            result.put('firstName', emp.First_Name__c);
            result.put('lastName', emp.Last_Name__c);
            result.put('userType', emp.User_Type__c);
            result.put('departmentId', emp.Department__c);
            result.put('departmentName', emp.Department__r.Name);
            result.put('teamId', emp.Team__c);
            result.put('teamName', emp.Team__r != null ? emp.Team__r.Name : null);
            result.put('designation', emp.Designation__c);
            return result;
        } catch(Exception e) {
            System.debug('getCurrentEmployeeInfo ERROR => ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Stat Cards Data ───────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDashboardStats() {
        try {
            Employee__c currentEmp = getCurrentEmployee();

            Map<String, Object> stats = new Map<String, Object>();
            String role = currentEmp.User_Type__c;
            Date today = Date.today();

            // ── HEAD HR ───────────────────────────────────────────────────────
            if(role != null && role.contains('HR')) {
                stats.put('totalEmployees', [
                    SELECT COUNT() FROM Employee__c
                ]);
                stats.put('presentToday', [
                    SELECT COUNT() FROM Attendance__c
                    WHERE Attendance_Date__c = :today
                    AND Is_Check_In_Done__c = true
                ]);
                stats.put('pendingLeaves', [
                    SELECT COUNT()
                    FROM Leave_Request__c
                    WHERE Status__c IN ('Submitted', 'Manager Approved', 'Manager Rejected', 'HR Approval Pending')
                ]);
                stats.put('pendingExpenses', [
                    SELECT COUNT() FROM Expense__c
                    WHERE Status__c Not IN ('Draft', 'Paid' , 'Cancelled', 'Rejected')
                ]);
            }

            // ── HOD ───────────────────────────────────────────────────────────
            else if(role.contains('HOD')) {
                Set<Id> subordinateEmpIds = new Set<Id>();
                for(Employee__c e : [SELECT Id FROM Employee__c WHERE Team__r.Department__c = :currentEmp.Department__c AND Status__c = 'Active' AND Id != :currentEmp.Id]) {
                    subordinateEmpIds.add(e.Id);
                }

                stats.put('totalEmployees', subordinateEmpIds.size());
                if (!subordinateEmpIds.isEmpty()) {
                    stats.put('presentToday', [SELECT COUNT() FROM Attendance__c WHERE Employee__c IN :subordinateEmpIds AND Attendance_Date__c = :today AND Is_Check_In_Done__c = true]);
                    stats.put('pendingLeaves', [SELECT COUNT() FROM Leave_Request__c WHERE Employee__c IN :subordinateEmpIds AND Status__c = 'Submitted']);
                    stats.put('pendingExpenses', [SELECT COUNT() FROM Expense__c WHERE Employee__c IN :subordinateEmpIds AND Status__c = 'Submitted']);
                } else {
                    stats.put('presentToday', 0);
                    stats.put('pendingLeaves', 0);
                    stats.put('pendingExpenses', 0);
                }
            }

            // ── TEAM MANAGER ──────────────────────────────────────────────────
            else if(role.contains('Manager')) {
                Set<Id> subordinateEmpIds = new Set<Id>();
                for(Employee__c e : [SELECT Id FROM Employee__c WHERE Manager__c = :currentEmp.Id AND Status__c = 'Active' AND Id != :currentEmp.Id]) {
                    subordinateEmpIds.add(e.Id);
                }

                stats.put('totalEmployees', subordinateEmpIds.size());
                if (!subordinateEmpIds.isEmpty()) {
                    stats.put('presentToday', [
                        SELECT COUNT() FROM Attendance__c
                        WHERE Employee__c IN :subordinateEmpIds
                        AND Attendance_Date__c = :today
                        AND Is_Check_In_Done__c = true
                    ]);
                    stats.put('pendingLeaves', [
                        SELECT COUNT() FROM Leave_Request__c
                        WHERE Employee__c IN :subordinateEmpIds AND Status__c = 'Submitted'
                    ]);
                    stats.put('pendingExpenses', [
                        SELECT COUNT() FROM Expense__c
                        WHERE Employee__c IN :subordinateEmpIds AND Status__c = 'Submitted'
                    ]);
                } else {
                    stats.put('presentToday', 0);
                    stats.put('pendingLeaves', 0);
                    stats.put('pendingExpenses', 0);
                }
            }

            // ── FINANCE EXECUTIVE ─────────────────────────────────────────────
            else if(role != null && role.contains('Finance')) {
                Integer pendingExpenses = [
                    SELECT COUNT() FROM Expense__c
                    WHERE Finance_User__c = :currentEmp.Id
                    AND Status__c = 'Finance User Assigned'
                ];
                Integer approvedThisMonth = [
                    SELECT COUNT() FROM Expense__c
                    WHERE Status__c = 'Approved'
                    AND Approved_Date__c = THIS_MONTH
                    AND Employee__c != :currentEmp.Id
                ];
                AggregateResult[] totalAmt = [
                    SELECT SUM(Total_Amount__c) total
                    FROM Expense__c
                    WHERE Status__c = 'Finance User Assigned'
                    AND Employee__c != :currentEmp.Id
                ];
                Decimal totalAmount = 0;
                if(totalAmt != null && !totalAmt.isEmpty() && totalAmt[0].get('total') != null) {
                    totalAmount = (Decimal)totalAmt[0].get('total');
                }

                stats.put('pendingExpenses', pendingExpenses);
                stats.put('approvedThisMonth', approvedThisMonth);
                stats.put('totalPendingAmount', totalAmount);
            }

            return stats;
        } catch(Exception e) {
            System.debug('getDashboardStats error: ' + e.getMessage());
            return new Map<String, Object>();
        }
    }

    // ── Get Pending Leaves ────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Leave_Request__c> getPendingLeaves() {
        try {
            Employee__c currentEmp = getCurrentEmployee();

            String role = currentEmp.User_Type__c;

            if(role != null && role.contains('HR')) {
                return [
                    SELECT Id, Name,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Leave_Type__c, Start_Date__c,
                        End_Date__c, Number_Of_Days__c,
                        Status__c, Reason__c
                    FROM Leave_Request__c
                    WHERE Status__c IN ('Submitted', 'Manager Approved', 'Manager Rejected', 'HR Approval Pending')
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            else if(role.contains('HOD')) {
                List<Team__c> deptTeams = [
                    SELECT Id FROM Team__c
                    WHERE Department__c = :currentEmp.Department__c
                ];
                Set<Id> teamIds = new Set<Id>();
                for(Team__c t : deptTeams) teamIds.add(t.Id);

                if(teamIds.isEmpty()) return new List<Leave_Request__c>();

                Set<Id> empIds = new Set<Id>();
                for(Employee__c e : [
                    SELECT Id FROM Employee__c
                    WHERE Team__c IN :teamIds AND Status__c = 'Active'
                ]) empIds.add(e.Id);

                if(empIds.isEmpty()) return new List<Leave_Request__c>();

                return [
                    SELECT Id, Name,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Leave_Type__c, Start_Date__c,
                        End_Date__c, Number_Of_Days__c,
                        Status__c, Reason__c
                    FROM Leave_Request__c
                    WHERE Employee__c IN :empIds
                    AND Status__c IN ('Submitted', 'Manager Approved')
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            else if(role.contains('Manager')) {
                return [
                    SELECT Id, Name,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Leave_Type__c, Start_Date__c,
                        End_Date__c, Number_Of_Days__c,
                        Status__c, Reason__c
                    FROM Leave_Request__c
                    WHERE Employee__r.Manager__c = :currentEmp.Id
                    AND Status__c = 'Submitted'
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }

            return new List<Leave_Request__c>();
        } catch(Exception e) {
            return new List<Leave_Request__c>();
        }
    }

    // ── Get Pending Expenses ──────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Expense__c> getPendingExpenses() {
        try {
            Employee__c currentEmp = getCurrentEmployee();

            String role = currentEmp.User_Type__c;

            if(role != null && role.contains('HR')) {
                return [
                    SELECT Id, Name, Claim_Title__c,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Expense_Date__c, Total_Amount__c,
                        Status__c, Remarks__c
                    FROM Expense__c
                    WHERE Status__c Not IN ('Draft', 'Paid' , 'Cancelled', 'Rejected')
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            else if(role.contains('HOD')) {

                List<Team__c> deptTeams = [
                    SELECT Id
                    FROM Team__c
                    WHERE Department__c = :currentEmp.Department__c
                ];

                Set<Id> teamIds = new Set<Id>();

                for(Team__c t : deptTeams) {
                    teamIds.add(t.Id);
                }

                if(teamIds.isEmpty()) {
                    return new List<Expense__c>();
                }

                Set<Id> empIds = new Set<Id>();

                for(Employee__c e : [
                    SELECT Id
                    FROM Employee__c
                    WHERE Team__c IN :teamIds
                    AND Status__c = 'Active'
                    AND Id != :currentEmp.Id
                ]) {
                    empIds.add(e.Id);
                }

                if(empIds.isEmpty()) {
                    return new List<Expense__c>();
                }

                return [
                    SELECT
                        Id,
                        Name,
                        Claim_Title__c,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Expense_Date__c,
                        Total_Amount__c,
                        Status__c,
                        Remarks__c
                    FROM Expense__c
                    WHERE Employee__c IN :empIds
                    AND Status__c = 'Submitted'
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            else if(role.contains('Manager')) {
                return [
                    SELECT Id, Name, Claim_Title__c,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Expense_Date__c, Total_Amount__c,
                        Status__c, Remarks__c
                    FROM Expense__c
                    WHERE Employee__r.Manager__c = :currentEmp.Id
                    AND Status__c = 'Submitted'
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            else if(role != null && role.contains('Finance')) {
                return [
                    SELECT
                        Id,
                        Name,
                        Claim_Title__c,
                        Employee__r.First_Name__c,
                        Employee__r.Last_Name__c,
                        Expense_Date__c,
                        Total_Amount__c,
                        Status__c,
                        Remarks__c,
                        Reimbursement_Date__c,
                        Finance_User__c
                    FROM Expense__c
                    WHERE Finance_User__c = :currentEmp.Id
                    AND Status__c IN (
                        'Finance User Assigned',
                        'Approved'
                    )
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }

            return new List<Expense__c>();
        } catch(Exception e) {
            return new List<Expense__c>();
        }
    }

    // ── Get Department/Team Employees ─────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Employee__c> getMyEmployees() {
        try {
            Employee__c currentEmp = getCurrentEmployee();

            String role = currentEmp.User_Type__c;

            if(role != null && role.contains('HR')) {
                return [
                    SELECT Id, Name, First_Name__c, Last_Name__c,
                        Email__c, Phone__c, Designation__c,
                        Department__r.Name, Team__r.Name,
                        User_Type__c, Status__c, Joining_Date__c
                    FROM Employee__c
                    ORDER BY First_Name__c
                    LIMIT 100
                ];
            }
            else if(role.contains('HOD')) {
                List<Team__c> deptTeams = [
                    SELECT Id
                    FROM Team__c
                    WHERE Department__c = :currentEmp.Department__c
                ];
                Set<Id> teamIds = new Set<Id>();
                for(Team__c t : deptTeams) {
                    teamIds.add(t.Id);
                }
                if(teamIds.isEmpty()) {
                    return new List<Employee__c>();
                }
                return [
                    SELECT
                        Id,
                        Name,
                        First_Name__c,
                        Last_Name__c,
                        Email__c,
                        Phone__c,
                        Designation__c,
                        Team__r.Name,
                        User_Type__c,
                        Status__c,
                        Joining_Date__c
                    FROM Employee__c
                    WHERE Team__c IN :teamIds
                    AND Status__c = 'Active'
                    AND Id != :currentEmp.Id
                    ORDER BY First_Name__c
                ];
            }
            else if(role.contains('Manager')) {
                return [
                    SELECT
                        Id,
                        Name,
                        First_Name__c,
                        Last_Name__c,
                        Email__c,
                        Phone__c,
                        Designation__c,
                        Team__r.Name,
                        User_Type__c,
                        Status__c,
                        Joining_Date__c
                    FROM Employee__c
                    WHERE Manager__c = :currentEmp.Id
                    AND Status__c = 'Active'
                    AND Id != :currentEmp.Id
                    ORDER BY First_Name__c
                ];
            }

            return new List<Employee__c>();
        } catch(Exception e) {
            return new List<Employee__c>();
        }
    }

    // ── Today Attendance ──────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Attendance__c getTodayAttendance() {
        try {
            Employee__c emp = getCurrentEmployee();
            List<Attendance__c> records = [
                SELECT Id, Check_In__c, Check_Out__c,
                    Working_Hours__c, Attendance_Status__c,
                    Is_Check_In_Done__c, Is_Check_Out_Done__c,
                    Attendance_Date__c
                FROM Attendance__c
                WHERE Employee__c = :emp.Id
                AND Attendance_Date__c = :Date.today()
                LIMIT 1
            ];

            return records.isEmpty() ? null : records[0];
        } catch(Exception e) {
            return null;
        }
    }

    // ── Check In ──────────────────────────────────────────────────────────────
    @AuraEnabled
    public static Attendance__c doCheckIn() {
        Employee__c emp = getCurrentEmployee();
        if (emp == null) throw new AuraHandledException('Active employee record not found.');
        List<Attendance__c> existing = [
            SELECT Id FROM Attendance__c
            WHERE Employee__c = :emp.Id
            AND Attendance_Date__c = :Date.today()
            AND Is_Check_In_Done__c = true
            LIMIT 1
        ];

        if(!existing.isEmpty())
            throw new AuraHandledException('Already checked in today');

        Attendance__c att = new Attendance__c();
        att.Employee__c = emp.Id;
        att.Attendance_Date__c = Date.today();
        att.Check_In__c = DateTime.now();
        att.Is_Check_In_Done__c = true;
        insert att;

        return [
            SELECT Id, Check_In__c, Check_Out__c, Working_Hours__c, Attendance_Status__c, Is_Check_In_Done__c, Is_Check_Out_Done__c, Attendance_Date__c
            FROM Attendance__c
            WHERE Id = :att.Id
        ];
    }

    // ── Check Out ─────────────────────────────────────────────────────────────
    @AuraEnabled
    public static Attendance__c doCheckOut() {
        Employee__c emp = getCurrentEmployee();
        if (emp == null) throw new AuraHandledException('Active employee record not found.');

        List<Attendance__c> records = [
            SELECT Id, Check_In__c
            FROM Attendance__c
            WHERE Employee__c = :emp.Id
            AND Attendance_Date__c = :Date.today()
            AND Is_Check_In_Done__c = true
            LIMIT 1
        ];

        if(records.isEmpty())
            throw new AuraHandledException('Please check in first');

        Attendance__c att = records[0];
        att.Check_Out__c = DateTime.now();
        att.Is_Check_Out_Done__c = true;

        Long ms = DateTime.now().getTime() - att.Check_In__c.getTime();
        att.Working_Hours__c = (ms / 3600000.0).setScale(2);

        List<Attendance_Policy__mdt> policies = [
            SELECT Full_Day_Hours__c, Half_Day_Hours__c
            FROM Attendance_Policy__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if(!policies.isEmpty()) {
            Decimal full = policies[0].Full_Day_Hours__c;
            Decimal half = policies[0].Half_Day_Hours__c;
            Decimal hrs = att.Working_Hours__c;

            if(hrs >= full) att.Attendance_Status__c = 'Present';
            else if(hrs >= half) att.Attendance_Status__c = 'Half Day';
            else att.Attendance_Status__c = 'Absent';
        }

        update att;
        return [
            SELECT Id, Check_In__c, Check_Out__c, Working_Hours__c, Attendance_Status__c, Is_Check_In_Done__c, Is_Check_Out_Done__c, Attendance_Date__c
            FROM Attendance__c
            WHERE Id = :att.Id
        ];
    }

    // ── Update Leave Status ───────────────────────────────────────────────────
    @AuraEnabled
    public static void updateLeaveStatus(
        String leaveId, String status
    ) {
        List<Leave_Request__c> leaves = [
            SELECT Id, Status__c, Employee__c,
                Leave_Type__c, Number_Of_Days__c,
                Employee__r.Manager__c
            FROM Leave_Request__c
            WHERE Id = :leaveId
            LIMIT 1
        ];

        if(leaves.isEmpty())
            throw new AuraHandledException('Leave not found');

        leaves[0].Status__c = status;
        update leaves[0];
    }

    // ── Update Expense Status ─────────────────────────────────────────────────
    @AuraEnabled
    public static void updateExpenseStatus(
        String expenseId, String status
    ) {
        List<Expense__c> expenses = [
            SELECT Id, Status__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];

        if(expenses.isEmpty())
            throw new AuraHandledException('Expense not found');

        if(status == 'Approved') {
            expenses[0].Approved_Date__c = Date.today();
        }

        expenses[0].Status__c = status;
        update expenses[0];
    }

    @AuraEnabled
    public static void deleteDraftExpense(String expenseId) {
        List<Expense__c> exps = [
            SELECT Id, Status__c FROM Expense__c
            WHERE Id = :expenseId
            AND Status__c = 'Draft'
            LIMIT 1
        ];
        if(!exps.isEmpty()) delete exps[0];
    }

    @AuraEnabled(cacheable=true)
    public static String getApprovalWorkItemId(Id recordId) {

        List<ProcessInstanceWorkitem> wis = [
            SELECT Id
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :recordId
            LIMIT 1
        ];

        return wis.isEmpty() ? null : wis[0].Id;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════════════
    private static Employee__c getCurrentEmployee() {
        try {
            Id userId = UserInfo.getUserId();
            List<Employee__c> emps = [
                SELECT Id, User_Type__c, Department__c, Team__c
                FROM Employee__c WHERE User__c = :userId AND Status__c = 'Active' LIMIT 1
            ];
            return emps.isEmpty() ? null : emps[0];
        } catch (Exception e) {
            throw new AuraHandledException('Could not retrieve current employee: ' + e.getMessage());
        }
    }
}