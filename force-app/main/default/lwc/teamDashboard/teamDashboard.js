import { LightningElement, track } from 'lwc';
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
    @track errorMessage = '';
    @track successMessage = '';

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
                this.errorMessage =
                    error.body?.message ||
                    'Error checking role';
                this.isLoading = false;
            });
    }

    loadData() {
        this.errorMessage = '';
        this.successMessage = '';

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
                            + leave.Employee__r.Last_Name__c
                    };
                });
                this.teamExpenses = expenses.map(exp => {
                    return {
                        ...exp,
                        employeeName:
                            exp.Employee__r.First_Name__c
                            + ' '
                            + exp.Employee__r.Last_Name__c
                    };
                });
                this.myTeamInfo = teamInfo;
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage =
                    error.body?.message ||
                    'Error loading team data';
                this.isLoading = false;
            });
        } else {
            // Employee — sirf team info lo
            getMyTeamInfo()
                .then(result => {
                    this.myTeamInfo = result;
                    this.isLoading = false;
                })
                .catch(error => {
                    this.errorMessage =
                        error.body?.message ||
                        'Error loading team info';
                    this.isLoading = false;
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
        this.errorMessage = '';
        this.successMessage = '';

        if(type === 'leave') {
            updateLeaveStatus({
                leaveId: id,
                status: status,
                remarks: ''
            })
            .then(() => {
                this.successMessage =
                    'Leave ' + status + ' successfully';
                this.loadData();
            })
            .catch(error => {
                let errMsg = 'Error updating leave';
                if(error.body) {
                    if(error.body.message) {
                        errMsg = error.body.message;
                    } else if(
                        error.body.pageErrors &&
                        error.body.pageErrors.length > 0
                    ) {
                        errMsg =
                            error.body.pageErrors[0].message;
                    }
                }
                this.errorMessage = errMsg;
                this.isLoading = false;
            });
        } else if(type === 'expense') {
            updateExpenseStatus({
                expenseId: id,
                status: status,
                remarks: ''
            })
            .then(() => {
                this.successMessage =
                    'Expense ' + status + ' successfully';
                this.loadData();
            })
            .catch(error => {
                let errMsg = 'Error updating expense';
                if(error.body) {
                    if(error.body.message) {
                        errMsg = error.body.message;
                    } else if(
                        error.body.pageErrors &&
                        error.body.pageErrors.length > 0
                    ) {
                        errMsg =
                            error.body.pageErrors[0].message;
                    }
                }
                this.errorMessage = errMsg;
                this.isLoading = false;
            });
        }
    }
}