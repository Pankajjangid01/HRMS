import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeaveBalances from '@salesforce/apex/LeaveController.getLeaveBalances';
import getLeaveRequests from '@salesforce/apex/LeaveController.getLeaveRequests';
import applyLeave from '@salesforce/apex/LeaveController.applyLeave';
import cancelLeave from '@salesforce/apex/LeaveController.cancelLeave';

export default class LeaveModule extends LightningElement {

    @track isLoading = true;
    @track leaveBalances = [];
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
            { label: 'Paid Time Off', value: 'Paid Time Off' },
            { label: 'Sick', value: 'Sick' },
            { label: 'Bereavement', value: 'Bereavement' }
        ];
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        Promise.all([
            getLeaveBalances(),
            getLeaveRequests()
        ])
        .then(([balances, requests]) => {
            this.leaveBalances = balances;
            // canCancel property add karo
            this.leaveRequests = requests.map(req => {
                return {
                    ...req,
                    canCancel: req.Status__c === 'Draft' ||
                            req.Status__c === 'Submitted'
                };
            });
            this.isLoading = false;
        })
        .catch(error => {
            console.error(error);
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
            const diff = end - start;
            this.numberOfDays =
                Math.floor(diff / (1000 * 60 * 60 * 24)) + 1;
        }
    }

    handleApplyLeave() {

        // Reset messages
        this.errorMessage = '';
        this.successMessage = '';

        // Validation
        if(!this.leaveType) {
            this.errorMessage =
                'Please select leave type';
            return;
        }
        if(!this.startDate) {
            this.errorMessage =
                'Please select start date';
            return;
        }
        if(!this.endDate) {
            this.errorMessage =
                'Please select end date';
            return;
        }
        if(this.numberOfDays <= 0) {
            this.errorMessage =
                'End date must be after start date';
            return;
        }
        if(!this.reason) {
            this.errorMessage =
                'Please enter reason';
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
            this.successMessage =
                'Leave applied successfully';
            this.resetForm();
            this.loadData();
        })
        .catch(error => {
            let errMsg = 'Error applying leave';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors &&
                    error.body.pageErrors.length > 0) {
                    errMsg =
                        error.body.pageErrors[0].message;
                } else if(error.body.output &&
                    error.body.output.errors &&
                    error.body.output.errors.length > 0) {
                    errMsg =
                        error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
            this.isLoading = false;
        });
    }

    handleCancelLeave(event) {
        const leaveId = event.target.dataset.id;
        this.isLoading = true;
        cancelLeave({ leaveId: leaveId })
        .then(() => {
            this.showToast('Success',
                'Leave cancelled successfully',
                'success');
            this.loadData();
        })
        .catch(error => {
            let errMsg = 'Error cancelling leave';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors &&
                    error.body.pageErrors.length > 0) {
                    errMsg =
                        error.body.pageErrors[0].message;
                } else if(error.body.output &&
                    error.body.output.errors &&
                    error.body.output.errors.length > 0) {
                    errMsg =
                        error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
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

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}