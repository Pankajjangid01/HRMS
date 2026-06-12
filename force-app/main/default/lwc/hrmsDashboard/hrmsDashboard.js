import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentEmployeeInfo from '@salesforce/apex/HRMSDashboardController.getCurrentEmployeeInfo';
import getDashboardStats from '@salesforce/apex/HRMSDashboardController.getDashboardStats';
import getPendingLeaves from '@salesforce/apex/HRMSDashboardController.getPendingLeaves';
import getPendingExpenses from '@salesforce/apex/HRMSDashboardController.getPendingExpenses';
import getMyEmployees from '@salesforce/apex/HRMSDashboardController.getMyEmployees';
import getTodayAttendance from '@salesforce/apex/HRMSDashboardController.getTodayAttendance';
import doCheckIn from '@salesforce/apex/HRMSDashboardController.doCheckIn';
import doCheckOut from '@salesforce/apex/HRMSDashboardController.doCheckOut';
import updateLeaveStatus from '@salesforce/apex/HRMSDashboardController.updateLeaveStatus';
import updateExpenseStatus from '@salesforce/apex/HRMSDashboardController.updateExpenseStatus';
import getMyExpenses from '@salesforce/apex/HRMSDashboardController.getMyExpenses';
import getMyLeaves from '@salesforce/apex/HRMSDashboardController.getMyLeaves';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';
import getApprovalWorkItemId from '@salesforce/apex/HRMSDashboardController.getApprovalWorkItemId';

export default class HrmsDashboard extends LightningElement {

    // ── State ─────────────────────────────────────────────────────────────────
    @track isLoading = true;
    @track stats = {};
    @track leaveRequests = [];
    @track expenses = [];
    @track employees = [];
    @track attendance = {};
    @track myLeaveBalance = null;
    @track myExpenses = [];
    @track myLeaves = [];

    // ── Employee Info ─────────────────────────────────────────────────────────
    @track employeeName = '';
    @track designation = '';
    @track department = '';
    @track team = '';
    @track userType = '';
    @track currentEmployeeId = '';

    // ── Pagination ────────────────────────────────────────────────────────────
    @track currentLeaveRequestPage = 1;
    @track currentExpensePage = 1;
    @track currentEmployeePage = 1;
    @track itemsPerPage = 10;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        try {
            const emp = await getCurrentEmployeeInfo();
            if (emp) {
                this.employeeName = (emp.firstName || '') + ' ' + (emp.lastName || '');
                this.designation = emp.designation || '';
                this.department = emp.departmentName || '';
                this.team = emp.teamName || '';
                this.userType = emp.userType || '';
                console.log('User Type => ', this.userType);
                console.log('isFinance => ', this.isFinance);
                this.currentEmployeeId = emp.id || '';
            }

            const [stats, leaves, exps, emps, att] = await Promise.all([
                getDashboardStats(),
                getPendingLeaves(),
                getPendingExpenses(),
                getMyEmployees(),
                getTodayAttendance()
            ]);

            this.stats = {
                totalEmployees: stats.totalEmployees || 0,
                presentToday: stats.presentToday || 0,
                pendingLeaves: stats.pendingLeaves || 0,
                pendingExpenses: stats.pendingExpenses || 0,
                approvedThisMonth: stats.approvedThisMonth || 0,
                totalPendingAmount: stats.totalPendingAmount || 0
            };

            this.leaveRequests = (leaves || []).map(l => ({
                ...l,
                empName: (l.Employee__r?.First_Name__c || '') + ' ' + (l.Employee__r?.Last_Name__c || ''),
                showLeaveApproveBtn: [
                    'HR Approval Pending',
                    'Manager Approved',
                    'Manager Rejected'
                ].includes(l.Status__c)
            }));

            this.expenses = (exps || []).map(e => ({
                ...e,
                empName: (e.Employee__r?.First_Name__c || '') + ' ' + (e.Employee__r?.Last_Name__c || '')
            }));

            this.employees = (emps || []).map(emp => ({
                ...emp,
                teamName: emp.Team__r ? emp.Team__r.Name : ''
            }));
            this.attendance = att || {};

            // Personal data for HOD / Manager / Finance
            if (this.showPersonalSection) {
                const [lb, myExp, myLv] = await Promise.all([
                    getLeaveBalance(),
                    getMyExpenses(),
                    getMyLeaves()
                ]);
                this.myLeaveBalance = lb;
                this.myExpenses = (myExp || []).slice(0, 5).map(e => ({
                    ...e,
                    statusClass: this.getStatusClass(e.Status__c)
                }));
                this.myLeaves = (myLv || []).slice(0, 5).map(l => ({
                    ...l,
                    statusClass: this.getStatusClass(l.Status__c)
                }));
            }

        } catch (err) {
            console.error('Dashboard load error:', err);
            this.showToast('Error loading dashboard', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Role Getters ──────────────────────────────────────────────────────────
    get isHRRole() {
        const role = this.userType || '';
        return role.includes('HR');
    }

    get isHOD() {
        return this.userType === 'HOD';
    }

    get isManager() {
        const role = (this.userType || '').trim().toLowerCase();
        return role === 'manager' || role === 'team manager';
    }

    get isFinance() {
        return this.userType && this.userType.toLowerCase().includes('finance');
    }

    get showPersonalSection() {
        return this.isHRRole || this.isHOD || this.isManager || this.isFinance;
    }

    get showApprovalSection() {
        return this.isHRRole || this.isHOD || this.isManager || this.isFinance;
    }

    get hasLeaves() {
        return this.leaveRequests && this.leaveRequests.length > 0;
    }

    get hasExpenses() {
        return this.expenses && this.expenses.length > 0;
    }

    get hasEmployees() {
        return this.employees && this.employees.length > 0;
    }

    get hasMyExpenses() {
        return this.myExpenses && this.myExpenses.length > 0;
    }

    get hasMyLeaves() {
        return this.myLeaves && this.myLeaves.length > 0;
    }

    // ── Pagination Getters ────────────────────────────────────────────────────
    get paginatedLeaveRequests() {
        const start = (this.currentLeaveRequestPage - 1) * this.itemsPerPage;
        return this.leaveRequests.slice(start, start + this.itemsPerPage);
    }

    get totalLeavePages() {
        return Math.ceil(this.leaveRequests.length / this.itemsPerPage) || 1;
    }

    get currentLeavePageInfo() {
        const start = (this.currentLeaveRequestPage - 1) * this.itemsPerPage + 1;
        const end = Math.min(this.currentLeaveRequestPage * this.itemsPerPage, this.leaveRequests.length);
        return `${start}-${end} of ${this.leaveRequests.length}`;
    }

    get paginatedExpenses() {
        const start = (this.currentExpensePage - 1) * this.itemsPerPage;
        return this.expenses.slice(start, start + this.itemsPerPage);
    }

    get totalExpensePages() {
        return Math.ceil(this.expenses.length / this.itemsPerPage) || 1;
    }

    get currentExpensePageInfo() {
        const start = (this.currentExpensePage - 1) * this.itemsPerPage + 1;
        const end = Math.min(this.currentExpensePage * this.itemsPerPage, this.expenses.length);
        return `${start}-${end} of ${this.expenses.length}`;
    }

    get paginatedEmployees() {
        const start = (this.currentEmployeePage - 1) * this.itemsPerPage;
        return this.employees.slice(start, start + this.itemsPerPage);
    }

    get totalEmployeePages() {
        return Math.ceil(this.employees.length / this.itemsPerPage) || 1;
    }

    get currentEmployeePageInfo() {
        const start = (this.currentEmployeePage - 1) * this.itemsPerPage + 1;
        const end = Math.min(this.currentEmployeePage * this.itemsPerPage, this.employees.length);
        return `${start}-${end} of ${this.employees.length}`;
    }

    // ── Pagination Button States ──────────────────────────────────────────────
    get disableLeaveFirstPrev() {
        return this.currentLeaveRequestPage === 1;
    }

    get disableLeaveNextLast() {
        return this.currentLeaveRequestPage === this.totalLeavePages;
    }

    get previousLeaveRequestPage() {
        return this.currentLeaveRequestPage - 1;
    }

    get nextLeaveRequestPage() {
        return this.currentLeaveRequestPage + 1;
    }

    get disableExpenseFirstPrev() {
        return this.currentExpensePage === 1;
    }

    get disableExpenseNextLast() {
        return this.currentExpensePage === this.totalExpensePages;
    }

    get previousExpensePage() {
        return this.currentExpensePage - 1;
    }

    get nextExpensePage() {
        return this.currentExpensePage + 1;
    }

    get disableEmployeeFirstPrev() {
        return this.currentEmployeePage === 1;
    }

    get disableEmployeeNextLast() {
        return this.currentEmployeePage === this.totalEmployeePages;
    }

    get previousEmployeePage() {
        return this.currentEmployeePage - 1;
    }

    get nextEmployeePage() {
        return this.currentEmployeePage + 1;
    }

    get employeeSectionTitle() {
        if (this.isHRRole) return 'All Employees';
        if (this.isHOD) return 'Department Employees';
        return 'Team Members';
    }

    // ── Attendance Getters ────────────────────────────────────────────────────
    get showCheckInButton() {
        return !this.attendance?.Is_Check_In_Done__c;
    }

    get showCheckOutButton() {
        return this.attendance?.Is_Check_In_Done__c && !this.attendance?.Is_Check_Out_Done__c;
    }

    get checkInTime() {
        if (!this.attendance?.Check_In__c) return '';
        return new Date(this.attendance.Check_In__c).toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit'
        });
    }

    get checkOutTime() {
        if (!this.attendance?.Check_Out__c) return '';
        return new Date(this.attendance.Check_Out__c).toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit'
        });
    }

    get workingHours() {
        return this.attendance?.Working_Hours__c
            ? this.attendance.Working_Hours__c + ' hrs'
            : '';
    }

    get attendanceStatusLabel() {
        if (!this.attendance?.Is_Check_In_Done__c) return 'Not Checked In';
        if (!this.attendance?.Is_Check_Out_Done__c) return 'Checked In';
        return this.attendance?.Attendance_Status__c || 'Present';
    }

    get attendanceBadgeClass() {
        const status = this.attendanceStatusLabel;
        if (status === 'Present') return 'badge-att green';
        if (status === 'Checked In') return 'badge-att blue';
        if (status === 'Half Day') return 'badge-att orange';
        return 'badge-att grey';
    }

    // ── Toast ─────────────────────────────────────────────────────────────────
    get showActionColumn() {
        return this.isHOD;
    }

    get showLeaveActionColumn() {
        return !this.isHOD && !this.isManager;
    }

    showToast(message, type = 'success') {
        const title = type === 'error' ? 'Error' : 'Success';
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: type
            })
        );
    }

    // ── Check In / Out ────────────────────────────────────────────────────────
    async handleCheckIn() {
        try {
            const result = await doCheckIn();
            this.attendance = result || {};
            this.showToast('Checked in successfully!');
        } catch (err) {
            this.showToast(err.body?.message || 'Check in failed', 'error');
        }
    }

    async handleCheckOut() {
        try {
            const result = await doCheckOut();
            this.attendance = result || {};
            this.showToast('Checked out successfully!');
        } catch (err) {
            this.showToast(err.body?.message || 'Check out failed', 'error');
        }
    }

    // ── Leave Modal ───────────────────────────────────────────────────────────
    openLeaveModal() {
        this.template.querySelector('c-leave-apply-modal')?.openModal();
    }

    async handleLeaveApplied() {
        this.showToast('Leave applied successfully!');
        await this.loadDashboard();
    }

    // ── Expense Modal ─────────────────────────────────────────────────────────
    openExpenseModal() {
        this.template.querySelector('c-expense-apply-modal')?.openModal();
    }

    async handleExpenseSubmitted() {
        this.showToast('Expense submitted successfully! 🎉');
        await this.loadDashboard();
    }

    // ── Approve / Reject ──────────────────────────────────────────────────────
    async handleApprove(event) {
        const id = event.target.dataset.id;
        const type = event.target.dataset.type;
        try {
            if (type === 'leave') {
                await updateLeaveStatus({ leaveId: id, status: 'Manager Approved' });
            } else {
                await updateExpenseStatus({ expenseId: id, status: 'Approved' });
            }
            this.showToast('Approved successfully!');
            await this.loadDashboard();
        } catch (err) {
            this.showToast(err.body?.message || 'Error approving', 'error');
        }
    }

    async handleReject(event) {
        const id = event.target.dataset.id;
        const type = event.target.dataset.type;
        try {
            if (type === 'leave') {
                await updateLeaveStatus({ leaveId: id, status: 'Rejected' });
            } else {
                await updateExpenseStatus({ expenseId: id, status: 'Rejected' });
            }
            this.showToast('Rejected successfully!');
            await this.loadDashboard();
        } catch (err) {
            this.showToast(err.body?.message || 'Error rejecting', 'error');
        }
    }

    // ── Pagination Handlers ───────────────────────────────────────────────────
    handleLeaveRequestPageChange(event) {
        const page = parseInt(event.target.dataset.page, 10);
        if (page >= 1 && page <= this.totalLeavePages) {
            this.currentLeaveRequestPage = page;
        }
    }

    handleExpensePageChange(event) {
        const page = parseInt(event.target.dataset.page, 10);
        if (page >= 1 && page <= this.totalExpensePages) {
            this.currentExpensePage = page;
        }
    }

    handleEmployeePageChange(event) {
        const page = parseInt(event.target.dataset.page, 10);
        if (page >= 1 && page <= this.totalEmployeePages) {
            this.currentEmployeePage = page;
        }
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    getStatusClass(status) {
        if (status === 'Approved') return 'badge-status green';
        if (status === 'Rejected') return 'badge-status red';
        if (status === 'Submitted') return 'badge-status orange';
        return 'badge-status grey';
    }

    async handleViewApproval(event) {
        const recordId = event.target.dataset.id;
        try {
            const workItemId = await getApprovalWorkItemId({
                recordId: recordId
            });
            if (workItemId) {
                window.open(`/p/process/ProcessInstanceWorkitemWizardStageManager?id=${workItemId}`,'_blank'
                );
            }
        } catch (err) {
            console.error(err);
            this.showToast('Unable to open approval request', 'error');
        }
    }
}
