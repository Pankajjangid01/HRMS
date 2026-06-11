public class EmployeeUserCreation {

    @InvocableMethod(label='Create User For Employee')
    public static void createUser(
        List<Id> employeeIds
    ) {
    
        if(employeeIds == null ||
           employeeIds.isEmpty()) {
            return;
        }
    
        System.enqueueJob(
            new EmployeeUserCreationQueueable(
                employeeIds
            )
        );
    }

}