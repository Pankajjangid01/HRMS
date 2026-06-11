import { api, LightningElement, track } from 'lwc';
import applyLeave from '@salesforce/apex/LeaveController.applyLeave';

export default class LeaveApplyModal extends LightningElement {
    @track isOpen = false;
    @track leaveType = '';
    @track startDate = '';
    @track endDate = '';
    @track reason = '';
    @track numberOfDays = 0;
    @track errorMessage = '';
    @track isSubmitting = false;

    @api openModal() {
        this.isOpen = true;
        this.errorMessage = '';
    }

    @api closeModal() {
        this.isOpen = false;
        this.resetForm();
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
        if (this.startDate && this.endDate) {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            const diff = Math.floor((end - start) / (1000 * 60 * 60 * 24)) + 1;
            this.numberOfDays = diff > 0 ? diff : 0;
            return;
        }
        this.numberOfDays = 0;
    }

    async handleApplyLeave() {
        this.errorMessage = '';
        if (!this.leaveType) {
            this.errorMessage = 'Please select leave type';
            return;
        }
        if (!this.startDate) {
            this.errorMessage = 'Please select start date';
            return;
        }
        if (!this.endDate) {
            this.errorMessage = 'Please select end date';
            return;
        }
        if (this.numberOfDays <= 0) {
            this.errorMessage = 'End date must be after start date';
            return;
        }
        if (!this.reason) {
            this.errorMessage = 'Please enter reason';
            return;
        }

        this.isSubmitting = true;
        try {
            await applyLeave({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason
            });
            this.closeModal();
            this.dispatchEvent(new CustomEvent('success'));
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error applying leave';
        } finally {
            this.isSubmitting = false;
        }
    }

    resetForm() {
        this.leaveType = '';
        this.startDate = '';
        this.endDate = '';
        this.reason = '';
        this.numberOfDays = 0;
        this.errorMessage = '';
    }
}
