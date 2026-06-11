import { LightningElement, track} from 'lwc';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';
import getLeaveRequests from '@salesforce/apex/LeaveController.getLeaveRequests';
import applyLeave from '@salesforce/apex/LeaveController.applyLeave';
import cancelLeave from '@salesforce/apex/LeaveController.cancelLeave';
export default class LeaveModule extends LightningElement {

    @track isLoading = true;

    @track leaveBalance = {

        PTO_Total__c: 0,
        PTO_Used__c: 0,
        PTO_Remaining__c: 0,

        Sick_Total__c: 0,
        Sick_Used__c: 0,
        Sick_Remaining__c: 0,

        Bereavement_Total__c: 0,
        Bereavement_Used__c: 0,
        Bereavement_Remaining__c: 0
    };

    @track leaveRequests = [];
    @track leaveType = '';
    @track startDate = '';
    @track endDate = '';
    @track reason = '';
    @track numberOfDays = 0;
    @track errorMessage = '';
    @track successMessage = '';

    get leaveTypeOptions() {
        return [
            {
                label: 'Paid Time Off',
                value: 'Paid Time Off'
            },

            {
                label: 'Sick',
                value: 'Sick'
            },

            {
                label: 'Bereavement',
                value: 'Bereavement'
            }
        ];
    }

    get hasLeaveRequests() {
        return this.leaveRequests && this.leaveRequests.length > 0;
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        Promise.all([
            getLeaveBalance(),
            getLeaveRequests()
        ])
        .then(([balance, requests]) => {
            this.leaveBalance = balance || {
                PTO_Total__c: 0,
                PTO_Used__c: 0,
                PTO_Remaining__c: 0,

                Sick_Total__c: 0,
                Sick_Used__c: 0,
                Sick_Remaining__c: 0,

                Bereavement_Total__c: 0,
                Bereavement_Used__c: 0,
                Bereavement_Remaining__c: 0
            };
            this.leaveRequests =
                requests.map(req => {
                return {
                    ...req,
                    canCancel:req.Status__c === 'Submitted'
                };
            });

        })
        .catch(error => {
            console.error('Load Data Error:', JSON.stringify(error));
            let errMsg = 'Error loading leave data';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errMsg = error.body.pageErrors[0].message;
                } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                    errMsg = error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleLeaveTypeChange(event) {
        this.leaveType = event.target.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.calculateDays();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.calculateDays();
    }

    handleReasonChange(event) {
        this.reason = event.target.value;
    }

    calculateDays() {
        if(this.startDate && this.endDate) {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            const diff = Math.floor((end - start) / (1000 * 60 * 60 * 24)) + 1;
            this.numberOfDays = diff > 0 ? diff : 0;
        } else {
            this.numberOfDays = 0;
        }
    }

    handleApplyLeave() {
        this.errorMessage = '';
        this.successMessage = '';
        if(!this.leaveType) {
            this.errorMessage = 'Please select leave type';
            return;
        }

        if(!this.startDate) {
            this.errorMessage = 'Please select start date';
            return;
        }

        if(!this.endDate) {
            this.errorMessage = 'Please select end date';
            return;
        }

        if(this.numberOfDays <= 0) {
            this.errorMessage = 'End date must be after start date';
            return;
        }

        if(!this.reason) {
            this.errorMessage = 'Please enter reason';
            return;
        }

        this.isLoading = true;
        applyLeave({
            leaveType: this.leaveType,
            startDate: this.startDate,
            endDate: this.endDate,
            reason: this.reason
        })
        .then(() => {
            this.successMessage = 'Leave applied successfully';
            this.resetForm();
            setTimeout(() => {
                this.loadData();
            }, 800);
        })
        .catch(error => {
            console.error('Leave Apply Error:', JSON.stringify(error));
            let errMsg = 'Error applying leave';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errMsg = error.body.pageErrors[0].message;
                } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                    errMsg = error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleCancelLeave(event) {
        const leaveId = event.target.dataset.id;
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';
        cancelLeave({
            leaveId: leaveId
        })
        .then(() => {
            this.successMessage = 'Leave cancelled successfully';
            this.loadData();
        })
        .catch(error => {
            console.error('Cancel Leave Error:', JSON.stringify(error));
            let errMsg = 'Error cancelling leave';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errMsg = error.body.pageErrors[0].message;
                } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                    errMsg = error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    resetForm() {
        this.leaveType = '';
        this.startDate = '';
        this.endDate = '';
        this.reason = '';
        this.numberOfDays = 0;
    }
}
