@isTest
public class TestDataFactory {
    private static Integer counter = 0;
    
    private static String getUniqueSuffix() {
        counter++;
        return String.valueOf(counter) + String.valueOf(DateTime.now().getTime()).substring(10);
    }

    public static User createTestUser(String profileName, String lastName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String suffix = getUniqueSuffix();
        String uniqueName = lastName + suffix;
        User u = new User(
            Alias = lastName.substring(0, Math.min(lastName.length(), 8)),
            Email = uniqueName + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = uniqueName.substring(0, Math.min(uniqueName.length(), 10)),
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueName + '@test.com'
        );
        insert u;
        return u;
    }

    public static Account getAccount() {
        String uniqueAccName = 'Test Account ' + DateTime.now().getTime() + Integer.valueOf(Math.random() * 1000);
        Account acc = new Account(Name = uniqueAccName);
        insert acc;
        return acc;
    }

    public static Employee__c createEmployee(Id userId, String userType) {
        Account acc = getAccount();
        String suffix = getUniqueSuffix();
        Employee__c emp = new Employee__c(
            User__c = userId,
            First_Name__c = 'T' + suffix,
            Last_Name__c = 'E' + suffix,
            Email__c = 't' + suffix + '@example.com',
            Phone__c = '1' + suffix.substring(0, Math.min(suffix.length(), 9)),
            Status__c = 'Active',
            User_Type__c = userType,
            Joining_Date__c = Date.today().addDays(-30),
            Account__c = acc.Id
        );
        if(userId != null) {
            emp.OwnerId = userId;
        }
        insert emp;
        return emp;
    }

    public static Department__c createDepartment(String name, Id hodEmpId) {
        Department__c dept = new Department__c(
            Name = name,
            Employee__c = hodEmpId,
            Department_Code__c = 'D' + DateTime.now().getTime()
        );
        insert dept;
        return dept;
    }

    public static Team__c createTeam(String name, Id deptId, Id managerEmpId) {
        Team__c team = new Team__c(
            Name = name,
            Department__c = deptId,
            Employee__c = managerEmpId,
            Status__c = 'Active'
        );
        insert team;
        return team;
    }

    public static Attendance__c createAttendance(Id empId, Date attDate) {
        Employee__c emp = [SELECT User__c FROM Employee__c WHERE Id = :empId LIMIT 1];
        Attendance__c att = new Attendance__c(
            Employee__c = empId,
            Attendance_Date__c = attDate,
            Check_In__c = DateTime.now().addHours(-8),
            Is_Check_In_Done__c = true
        );
        if(emp.User__c != null) {
            att.OwnerId = emp.User__c;
        }
        insert att;
        return att;
    }

    public static Leave_Balance__c createLeaveBalance(Id empId) {
        Leave_Balance__c lb = new Leave_Balance__c(
            Employee_Leaves__c = empId,
            Year__c = Date.today().year(),
            PTO_Total__c = 20,
            PTO_Used__c = 0,
            Sick_Total__c = 10,
            Sick_Used__c = 0,
            Bereavement_Total__c = 5,
            Bereavement_Used__c = 0
        );
        insert lb;
        return lb;
    }

    public static Leave_Request__c createLeaveRequest(Id empId, String type, Date start, Date endPos) {
        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = empId,
            Leave_Type__c = type,
            Start_Date__c = start,
            End_Date__c = endPos,
            Status__c = 'Submitted',
            Reason__c = 'Test Reason'
        );
        insert lr;
        return lr;
    }

    public static Expense__c createExpense(Id empId, String title) {
        Expense__c exp = new Expense__c(
            Employee__c = empId,
            Claim_Title__c = title,
            Expense_Date__c = Date.today(),
            Status__c = 'Draft'
        );
        insert exp;
        return exp;
    }

    public static Expense_Line_Item__c createExpenseLineItem(Id expId, Decimal amt) {
        Expense_Line_Item__c li = new Expense_Line_Item__c(
            Expense__c = expId,
            Amount__c = amt,
            Expense_Category__c = 'Travel',
            Description__c = 'Test desc'
        );
        insert li;
        return li;
    }
}
