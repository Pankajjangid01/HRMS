public with sharing class UserInfoController {

    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [
            SELECT Id,
                   Name,
                   SmallPhotoUrl,
                   Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
    }

    @AuraEnabled(cacheable=true)
    public static String getUserRoleType() {
        Id userId = UserInfo.getUserId();

        List<Employee__c> emps = [
            SELECT Id, User_Type__c
            FROM Employee__c
            WHERE User__c = :userId
            AND Status__c = 'Active'
            LIMIT 1
        ];

        if(emps.isEmpty()) return 'UNKNOWN';

        return emps[0].User_Type__c != null
            ? emps[0].User_Type__c
            : 'UNKNOWN';
    }
}