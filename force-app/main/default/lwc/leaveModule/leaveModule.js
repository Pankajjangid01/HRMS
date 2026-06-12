import { LightningElement, track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeaveRequests from '@salesforce/apex/LeaveController.getLeaveRequests';
import cancelLeave from '@salesforce/apex/LeaveController.cancelLeave';
export default class LeaveModule extends LightningElement {

    @track isLoading = true;

    @track leaveRequests = [];

    get hasLeaveRequests() {
        return this.leaveRequests && this.leaveRequests.length > 0;
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        getLeaveRequests()
        .then(requests => {
            this.leaveRequests =
                (requests || []).map(req => {
                const status = req.Status__c || '';
                return {
                    ...req,
                    canCancel: status === 'Submitted',
                    statusClass: this.getStatusClass(status)
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
            this.showToast('Error', errMsg, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    openLeaveModal() {
        this.template.querySelector('c-leave-apply-modal')?.openModal();
    }

    handleLeaveApplied() {
        this.showToast('Success', 'Leave applied successfully', 'success');
        this.loadData();
    }

    getStatusClass(status) {
        let cls = 'status-pill ';
        if(status === 'Submitted') {
            cls += 'submitted';
        } else if(status === 'Approved' || status === 'Manager Approved') {
            cls += 'approved';
        } else if(status === 'Rejected') {
            cls += 'rejected';
        } else if(status === 'Cancelled') {
            cls += 'cancelled';
        } else {
            cls += 'pending';
        }
        return cls;
    }

    handleCancelLeave(event) {
        const leaveId = event.target.dataset.id;
        this.isLoading = true;
        cancelLeave({
            leaveId: leaveId
        })
        .then(() => {
            this.showToast('Success', 'Leave cancelled successfully', 'success');
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
            this.showToast('Error', errMsg, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
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
