import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeamEmployees from '@salesforce/apex/TeamDashboardController.getTeamEmployees';
import getTeamLeaves from '@salesforce/apex/TeamDashboardController.getTeamLeaves';
import getTeamExpenses from '@salesforce/apex/TeamDashboardController.getTeamExpenses';
import getMyTeamInfo from '@salesforce/apex/TeamDashboardController.getMyTeamInfo';
import checkIsManager from '@salesforce/apex/TeamDashboardController.checkIsManager';
import updateLeaveStatus from '@salesforce/apex/TeamDashboardController.updateLeaveStatus';
import updateExpenseStatus from '@salesforce/apex/TeamDashboardController.updateExpenseStatus';

export default class TeamDashboard extends LightningElement {

    @track isLoading = true;
    @track isManager = false;
    @track myTeamInfo = null;
    @track teamEmployees = [];
    @track teamLeaves = [];
    @track teamExpenses = [];

    get hasTeamMembers() {
        return this.teamEmployees &&
            this.teamEmployees.length > 0;
    }

    get hasLeaves() {
        return this.teamLeaves &&
            this.teamLeaves.length > 0;
    }

    get hasExpenses() {
        return this.teamExpenses &&
            this.teamExpenses.length > 0;
    }

    get teamMemberCount() {
        return this.myTeamInfo?.members?.length || 0;
    }

    get pendingLeaveCount() {
        return this.teamLeaves?.length || 0;
    }

    get pendingExpenseCount() {
        return this.teamExpenses?.length || 0;
    }

    get totalPendingExpenseAmount() {
        const total = (this.teamExpenses || []).reduce(
            (sum, exp) => sum + (exp.Total_Amount__c || 0),
            0
        );
        return total.toFixed(2);
    }

    connectedCallback() {
        this.initializeDashboard();
    }

    initializeDashboard() {
        this.isLoading = true;
        checkIsManager()
            .then(result => {
                this.isManager = result;
                this.loadData();
            })
            .catch(error => {
                console.error('Check Role Error:', JSON.stringify(error));
                let errMsg = 'Error checking role';
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
                this.isLoading = false;
            });
    }

    loadData() {
        if(this.isManager) {
            Promise.all([
                getTeamEmployees(),
                getTeamLeaves(),
                getTeamExpenses(),
                getMyTeamInfo()
            ])
            .then(([employees, leaves,
                    expenses, teamInfo]) => {
                this.teamEmployees = employees;
                this.teamLeaves = leaves.map(leave => {
                    return {
                        ...leave,
                        employeeName:
                            leave.Employee__r.First_Name__c
                            + ' '
                            + leave.Employee__r.Last_Name__c,
                        statusClass: this.getStatusClass(
                            leave.Status__c
                        )
                    };
                });
                this.teamExpenses = expenses.map(exp => {
                    return {
                        ...exp,
                        employeeName:
                            exp.Employee__r.First_Name__c
                            + ' '
                            + exp.Employee__r.Last_Name__c,
                        statusClass: this.getStatusClass(
                            exp.Status__c
                        )
                    };
                });
                this.myTeamInfo = teamInfo;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Load Team Data Error:', JSON.stringify(error));
                let errMsg = 'Error loading team data';
                if(error.body) {
                    if(error.body.message) {
                        errMsg = error.body.message;
                    } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                        errMsg = error.body.pageErrors[0].message;
                    } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                        errMsg = error.body.output.errors[0].message;
                    }
                }
                this.isLoading = false;
                this.showToast('Error', errMsg, 'error');
            });
        } else {
            // Employee — sirf team info lo
            getMyTeamInfo()
                .then(result => {
                    this.myTeamInfo = result;
                    this.isLoading = false;
                })
                .catch(error => {
                    console.error('Load Team Info Error:', JSON.stringify(error));
                    let errMsg = 'Error loading team info';
                    if(error.body) {
                        if(error.body.message) {
                            errMsg = error.body.message;
                        } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                            errMsg = error.body.pageErrors[0].message;
                        } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                            errMsg = error.body.output.errors[0].message;
                        }
                    }
                    this.isLoading = false;
                    this.showToast('Error', errMsg, 'error');
                });
        }
    }

    handleApprove(event) {
        const id = event.target.dataset.id;
        const type = event.target.dataset.type;
        if(type === 'leave') {
            this.updateStatus(
                id, type, 'Manager Approved');
        } else {
            this.updateStatus(
                id, type, 'Approved');
        }
    }

    handleReject(event) {
        const id = event.target.dataset.id;
        const type = event.target.dataset.type;
        if(type === 'leave') {
            this.updateStatus(
                id, type, 'Manager Rejected');
        } else {
            this.updateStatus(
                id, type, 'Rejected');
        }
    }

    updateStatus(id, type, status) {
        this.isLoading = true;
        if(type === 'leave') {
            updateLeaveStatus({
                leaveId: id,
                status: status,
                remarks: ''
            })
            .then(() => {
                this.showToast('Success', 'Leave ' + status + ' successfully', 'success');
                this.loadData();
            })
            .catch(error => {
                console.error('Update Leave Error:', JSON.stringify(error));
                let errMsg = 'Error updating leave';
                if(error.body) {
                    if(error.body.message) {
                        errMsg = error.body.message;
                    } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                        errMsg = error.body.pageErrors[0].message;
                    } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                        errMsg = error.body.output.errors[0].message;
                    }
                }
                this.isLoading = false;
                this.showToast('Error', errMsg, 'error');
            });
        } else if(type === 'expense') {
            updateExpenseStatus({
                expenseId: id,
                status: status,
                remarks: ''
            })
            .then(() => {
                this.showToast('Success', 'Expense ' + status + ' successfully', 'success');
                this.loadData();
            })
            .catch(error => {
                console.error('Update Expense Error:', JSON.stringify(error));
                let errMsg = 'Error updating expense';
                if(error.body) {
                    if(error.body.message) {
                        errMsg = error.body.message;
                    } else if(error.body.pageErrors && error.body.pageErrors.length > 0) {
                        errMsg = error.body.pageErrors[0].message;
                    } else if(error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                        errMsg = error.body.output.errors[0].message;
                    }
                }
                this.isLoading = false;
                this.showToast('Error', errMsg, 'error');
            });
        }
    }

    getStatusClass(status) {
        let cls = 'status-pill ';
        if(status === 'Approved' ||
            status === 'Manager Approved') {
            cls += 'approved';
        } else if(status === 'Rejected' ||
            status === 'Manager Rejected') {
            cls += 'rejected';
        } else if(status === 'Submitted') {
            cls += 'submitted';
        } else {
            cls += 'neutral';
        }
        return cls;
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
