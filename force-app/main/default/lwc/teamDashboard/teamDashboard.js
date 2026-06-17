import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeamEmployees from '@salesforce/apex/TeamDashboardController.getTeamEmployees';
import getTeamLeaves from '@salesforce/apex/TeamDashboardController.getTeamLeaves';
import getTeamExpenses from '@salesforce/apex/TeamDashboardController.getTeamExpenses';
import getMyTeamInfo from '@salesforce/apex/TeamDashboardController.getMyTeamInfo';
import checkIsManager from '@salesforce/apex/TeamDashboardController.checkIsManager';
import updateLeaveStatus from '@salesforce/apex/TeamDashboardController.updateLeaveStatus';
import updateExpenseStatus from '@salesforce/apex/TeamDashboardController.updateExpenseStatus';

import getCurrentEmployeeInfo from '@salesforce/apex/HRMSDashboardController.getCurrentEmployeeInfo';
import getMyLeaves from '@salesforce/apex/HRMSDashboardController.getMyLeaves';
import getMyExpenses from '@salesforce/apex/HRMSDashboardController.getMyExpenses';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';

export default class TeamDashboard extends LightningElement {

    @track isLoading = true;
    @track isManager = false;
    @track myTeamInfo = null;
    @track teamEmployees = [];
    @track teamLeaves = [];
    @track teamExpenses = [];

    // --- Employee Dashboard Properties ---
    @track employeeName = '';
    @track myLeaves = [];
    @track filteredMyLeaves = [];
    @track myExpenses = [];
    @track filteredMyExpenses = [];
    @track myLeaveBalance = null;
    
    @track leaveFilter = 'All';
    @track expenseFilter = 'All';

    get leaveStatusOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Submitted', value: 'Submitted' },
            { label: 'Manager Approved', value: 'Manager Approved' },
            { label: 'Manager Rejected', value: 'Manager Rejected' },
            { label: 'HR Approval Pending', value: 'HR Approval Pending' },
            { label: 'HR Approved', value: 'HR Approved' },
            { label: 'HR Rejected', value: 'HR Rejected' },
            { label: 'Withdrawn', value: 'Withdrawn' }
        ];
    }

    get expenseStatusOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Submitted', value: 'Submitted' },
            { label: 'HOD Approved / HR Assignment Pending', value: 'HOD Approved / HR Assignment Pending' },
            { label: 'Rejected', value: 'Rejected' },
            { label: 'Finance User Assigned', value: 'Finance User Assigned' },
            { label: 'Paid', value: 'Paid' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get totalLeavesApplied() { return this.myLeaves ? this.myLeaves.length : 0; }
    
    get totalExpensesApplied() { return this.myExpenses ? this.myExpenses.length : 0; }

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
        
        Promise.all([
            checkIsManager(),
            getCurrentEmployeeInfo(),
            getMyLeaves(),
            getMyExpenses(),
            getLeaveBalance(),
            getMyTeamInfo()
        ])
        .then(([isMgr, empInfo, leaves, expenses, balance, teamInfo]) => {
            this.isManager = isMgr;
            
            if(empInfo) {
                this.employeeName = `${empInfo.firstName || ''} ${empInfo.lastName || ''}`.trim();
            }
            
            this.myLeaves = (leaves || []).map(l => ({
                ...l,
                statusClass: this.getStatusClass(l.Status__c)
            }));
            this.filteredMyLeaves = [...this.myLeaves];
            
            this.myExpenses = (expenses || []).map(e => ({
                ...e,
                statusClass: this.getStatusClass(e.Status__c)
            }));
            this.filteredMyExpenses = [...this.myExpenses];
            
            this.myLeaveBalance = balance;
            this.myTeamInfo = teamInfo;
            
            if (this.isManager) {
                this.loadManagerData();
            } else {
                this.isLoading = false;
            }
        })
        .catch(error => {
            this.handleError(error, 'Error initializing personal dashboard');
        });
    }

    loadManagerData() {
        Promise.all([
            getTeamEmployees(),
            getTeamLeaves(),
            getTeamExpenses()
        ])
        .then(([employees, leaves, expenses]) => {
            this.teamEmployees = employees;
            this.teamLeaves = leaves.map(leave => {
                return {
                    ...leave,
                    employeeName: leave.Employee__r?.First_Name__c + ' ' + leave.Employee__r?.Last_Name__c,
                    statusClass: this.getStatusClass(leave.Status__c)
                };
            });
            this.teamExpenses = expenses.map(exp => {
                return {
                    ...exp,
                    employeeName: exp.Employee__r?.First_Name__c + ' ' + exp.Employee__r?.Last_Name__c,
                    statusClass: this.getStatusClass(exp.Status__c)
                };
            });
            this.isLoading = false;
        })
        .catch(error => {
            this.handleError(error, 'Error loading team data');
        });
    }

    handleLeaveFilterChange(event) {
        this.leaveFilter = event.detail.value;
        this.filterData();
    }

    handleExpenseFilterChange(event) {
        this.expenseFilter = event.detail.value;
        this.filterData();
    }

    filterData() {
        if (this.leaveFilter === 'All') {
            this.filteredMyLeaves = [...this.myLeaves];
        } else {
            this.filteredMyLeaves = this.myLeaves.filter(l => l.Status__c === this.leaveFilter);
        }

        if (this.expenseFilter === 'All') {
            this.filteredMyExpenses = [...this.myExpenses];
        } else {
            this.filteredMyExpenses = this.myExpenses.filter(e => e.Status__c === this.expenseFilter);
        }
    }

    handleError(error, defaultMsg) {
        console.error(defaultMsg + ':', JSON.stringify(error));
        let errMsg = defaultMsg;
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
                this.initializeDashboard();
            })
            .catch(error => {
                this.handleError(error, 'Error updating leave');
            });
        } else if(type === 'expense') {
            updateExpenseStatus({
                expenseId: id,
                status: status,
                remarks: ''
            })
            .then(() => {
                this.showToast('Success', 'Expense ' + status + ' successfully', 'success');
                this.initializeDashboard();
            })
            .catch(error => {
                this.handleError(error, 'Error updating expense');
            });
        }
    }

    getStatusClass(status) {
        let cls = 'status-pill ';
        if(status === 'Approved' ||
            status === 'Manager Approved' ||
            status === 'HR Approved' ||
            status === 'HOD Approved / HR Assignment Pending' ||
            status === 'Finance User Assigned' ||
            status === 'Paid') {
            cls += 'approved';
        } else if(status === 'Rejected' ||
            status === 'Manager Rejected' ||
            status === 'HR Rejected') {
            cls += 'rejected';
        } else if(status === 'Submitted' ||
            status === 'HR Approval Pending') {
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
