public class EmployeeUserCreationQueueable implements Queueable {
    private List<Id> employeeIds;

    public EmployeeUserCreationQueueable(List<Id> employeeIds) {
        this.employeeIds = employeeIds;
    }
    
    public void execute(QueueableContext context) {
        try {
            List<Employee__c> employees = [
                SELECT
                    Id,
                    First_Name__c,
                    Last_Name__c,
                    Email__c,
                    Contact__c,
                    User_Type__c,
                    User__c
                FROM Employee__c
                WHERE Id IN :employeeIds
            ];
    
            // ── Profile Map — Correct Names ───────────────────────────────
            Map<String, Id> profileMap = new Map<String, Id>(); 
            for(Profile p : [
                SELECT Id, Name
                FROM Profile
                WHERE Name IN (
                    'YOJOY Head HR',
                    'YOJOY HR Staff',
                    'YOJOY HOD',
                    'YOJOY Team Manager',
                    'YOJOY Finance Executive',
                    'HRMS_Experience_User'
                )
            ]) {
                profileMap.put(p.Name, p.Id);
            }

            List<User> usersToCreate = new List<User>();
            List<Employee__c> validEmployees = new List<Employee__c>();

            for(Employee__c emp : employees) {

                // Already has user — skip
                if(emp.User__c != null) continue;
                   
                // Employee (portal) needs Contact
                if(emp.User_Type__c == 'Portal - Employee' && emp.Contact__c == null) {
                    System.debug('Contact missing for Employee: ' + emp.Id);
                    continue;
                }
    
                User u = new User();
                u.FirstName = emp.First_Name__c;
                u.LastName = String.isBlank(emp.Last_Name__c) ? 'User' : emp.Last_Name__c;
                u.Email = emp.Email__c;
                u.Username = emp.Email__c + '.' + System.currentTimeMillis() + '@hrms.com';
                String aliasValue = emp.First_Name__c != null ? emp.First_Name__c : 'emp';
                u.Alias = aliasValue.length() > 8 ? aliasValue.substring(0, 8) : aliasValue;
                u.TimeZoneSidKey = 'Asia/Kolkata';
                u.LocaleSidKey = 'en_IN';
                u.EmailEncodingKey = 'UTF-8';
                u.LanguageLocaleKey = 'en_US';
                u.UserPreferencesContentNoEmail = true;
                u.UserPreferencesContentEmailAsAndWhen = false;
    
                // ── Profile Assignment — Correct Logic ────────────────────
                if(emp.User_Type__c == 'Portal - Employee') {
                    // Portal Employee — Community License
                    u.ProfileId = profileMap.get('HRMS_Experience_User');
                    u.ContactId = emp.Contact__c;

                } else if(emp.User_Type__c == 'Head HR') {
                    // Head HR — Full Salesforce License
                    u.ProfileId = profileMap.get('YOJOY Head HR');

                } else if(emp.User_Type__c == 'HR') {
                    u.ProfileId = profileMap.get('YOJOY HR Staff');

                } else if(emp.User_Type__c == 'HOD') {
                    u.ProfileId = profileMap.get('YOJOY HOD');

                } else if(emp.User_Type__c == 'Manager') {
                    u.ProfileId = profileMap.get('YOJOY Team Manager');

                } else if(emp.User_Type__c == 'Finance Executive') {
                    u.ProfileId = profileMap.get('YOJOY Finance Executive');

                } else {
                    System.debug('Unknown User_Type__c: ' + emp.User_Type__c);
                    continue;
                }
    
                // Profile not found — skip
                if(u.ProfileId == null) {
                    System.debug('Profile not found for: ' + emp.Id);
                    continue;
                }

                usersToCreate.add(u);
                validEmployees.add(emp);
            }

            // ── Insert Users ──────────────────────────────────────────────
            if(!usersToCreate.isEmpty()) {
                Database.SaveResult[] results = Database.insert(usersToCreate, false);
                List<Employee__c> updateEmployees = new List<Employee__c>();

                for(Integer i = 0; i < results.size(); i++) {
                    if(results[i].isSuccess()) {
                        validEmployees[i].User__c = results[i].getId();
                        updateEmployees.add(validEmployees[i]);
                        System.debug('User Created: ' + results[i].getId());
                    } else {
                        for(Database.Error err : results[i].getErrors()) {
                            System.debug('User Creation Error: ' + err.getMessage());
                        }
                    }
                }
    
                if(!updateEmployees.isEmpty()) {
                    update updateEmployees;
                }
            }
    
        } catch(Exception e) {
            System.debug('Queueable Error: ' + e.getMessage());
            System.debug('Line: ' + e.getLineNumber());
        }
    }
}