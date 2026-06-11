import { LightningElement, track } from 'lwc';

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
import deleteDraftExpense from '@salesforce/apex/HRMSDashboardController.deleteDraftExpense';
import getMyExpenses from '@salesforce/apex/HRMSDashboardController.getMyExpenses';
import getMyLeaves from '@salesforce/apex/HRMSDashboardController.getMyLeaves';
import applyLeave from '@salesforce/apex/LeaveController.applyLeave';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import attachReceiptToExpense from '@salesforce/apex/ExpenseController.attachReceiptToExpense';
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

    // ── Toast ─────────────────────────────────────────────────────────────────
    @track toastMessage = '';
    @track toastType = 'success';
    @track modalError = '';

    // ── Employee Info ─────────────────────────────────────────────────────────
    @track employeeName = '';
    @track designation = '';
    @track department = '';
    @track team = '';
    @track userType = '';
    @track currentEmployeeId = '';
    @track currentExpenseId = '';

    // ── Leave Modal ───────────────────────────────────────────────────────────
    @track showLeaveModal = false;
    @track leaveType = '';
    @track startDate = '';
    @track endDate = '';
    @track reason = '';
    @track numberOfDays = 0;

    // ── Expense Modal ─────────────────────────────────────────────────────────
    @track showExpenseModal = false;
    @track showUploadStep = false;
    @track claimTitle = '';
    @track expenseDate = '';
    @track remarks = '';
    @track lineItems = [];
    @track contentDocumentId = '';
    @track receiptUploaded = false;

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
                empName: (l.Employee__r?.First_Name__c || '') + ' ' + (l.Employee__r?.Last_Name__c || '')
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
        return this.userType === 'Head HR' || this.userType === 'HR Staff';
    }

    get isHOD() {
        return this.userType === 'HOD';
    }

    get isManager() {
        return this.userType === 'Team Manager';
    }

    get isFinance() {
        return this.userType && this.userType.toLowerCase().includes('finance');
    }

    get showPersonalSection() {
        return this.isHOD || this.isManager || this.isFinance;
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
    get toastClass() {
        return `toast toast-${this.toastType}`;
    }

    get showActionColumn() {
        return !(this.isFinance || this.isHRRole);
    }
    showToast(message, type = 'success') {
        this.toastMessage = message;
        this.toastType = type;
        setTimeout(() => { this.toastMessage = ''; }, 3000);
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
        this.showLeaveModal = true;
        this.modalError = '';
    }

    closeLeaveModal() {
        this.showLeaveModal = false;
        this.resetLeaveForm();
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
        } else {
            this.numberOfDays = 0;
        }
    }

    async handleApplyLeave() {
        this.modalError = '';
        if (!this.leaveType) { this.modalError = 'Please select leave type'; return; }
        if (!this.startDate) { this.modalError = 'Please select start date'; return; }
        if (!this.endDate) { this.modalError = 'Please select end date'; return; }
        if (!this.reason) { this.modalError = 'Please enter reason'; return; }
        if (this.numberOfDays <= 0) { this.modalError = 'End date must be after start date'; return; }

        try {
            await applyLeave({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason
            });
            this.closeLeaveModal();
            this.showToast('Leave applied successfully!');
            await this.loadDashboard();
        } catch (err) {
            this.modalError = err.body?.message || 'Error applying leave';
        }
    }

    resetLeaveForm() {
        this.leaveType = '';
        this.startDate = '';
        this.endDate = '';
        this.reason = '';
        this.numberOfDays = 0;
        this.modalError = '';
    }

    // ── Expense Modal ─────────────────────────────────────────────────────────
    openExpenseModal() {
        this.showExpenseModal = true;
        this.showUploadStep = false;
        this.modalError = '';
        this.receiptUploaded = false;
        this.currentExpenseId = '';
        if (this.lineItems.length === 0) {
            this.handleAddLineItem();
        }
    }

    async closeExpenseModal() {
        // Agar draft bana tha but receipt upload nahi hui toh delete karo
        if (this.currentExpenseId && !this.receiptUploaded) {
            try {
                await deleteDraftExpense({
                    expenseId: this.currentExpenseId
                });
            } catch (e) {
                console.error('Draft delete error:', e);
            }
        }
        this.showExpenseModal = false;
        this.resetExpenseForm();
    }

    handleClaimTitleChange(event) { this.claimTitle = event.target.value; }
    handleExpenseDateChange(event) { this.expenseDate = event.target.value; }
    handleRemarksChange(event) { this.remarks = event.target.value; }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    get totalAmount() {
        let total = 0;
        this.lineItems.forEach(item => {
            total += parseFloat(item.amount) || 0;
        });
        return total.toFixed(2);
    }

    handleAddLineItem() {
        this.lineItems = [...this.lineItems, {
            key: Date.now(),
            category: '',
            amount: '',
            description: ''
        }];
    }

    handleRemoveLineItem(event) {
        const index = parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.filter((item, i) => i !== index);
    }

    handleCategoryChange(event) {
        const index = parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, category: event.target.value } : item
        );
    }

    handleAmountChange(event) {
        const index = parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, amount: event.target.value } : item
        );
    }

    handleDescriptionChange(event) {
        const index = parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, description: event.target.value } : item
        );
    }

    // ── Step 1: Validate + Create Expense (Draft) ─────────────────────────────
    async handleCreateExpense() {
        this.modalError = '';
        if (!this.claimTitle) { this.modalError = 'Please enter claim title'; return; }
        if (!this.expenseDate) { this.modalError = 'Please select expense date'; return; }
        if (this.lineItems.length === 0) { this.modalError = 'Please add at least one line item'; return; }
        if (parseFloat(this.totalAmount) <= 0) { this.modalError = 'Total amount must be greater than 0'; return; }

        // Validate all line items
        for (let i = 0; i < this.lineItems.length; i++) {
            const item = this.lineItems[i];
            if (!item.category) { this.modalError = `Please select category for line item ${i + 1}`; return; }
            if (!item.amount || parseFloat(item.amount) <= 0) { this.modalError = `Please enter valid amount for line item ${i + 1}`; return; }
        }

        try {
            const expenseId = await createExpense({
                claimTitle: this.claimTitle,
                expenseDate: this.expenseDate,
                remarks: this.remarks,
                lineItemsJson: JSON.stringify(this.lineItems)
            });
            this.currentExpenseId = expenseId;
            this.showUploadStep = true;
            this.modalError = '';
        } catch (err) {
            this.modalError = err.body?.message || 'Error creating expense';
        }
    }

    // ── Step 2: File Upload Finished ──────────────────────────────────────────
    handleUploadFinished(event) {
        const files = event.detail.files;
        if (files.length > 0) {
            this.contentDocumentId = files[0].documentId;
            this.receiptUploaded = true;
        }
    }

    // ── Step 2: Final Submit — Attach Receipt + Mark Submitted ────────────────
    async handleFinalSubmit() {
        this.modalError = '';
        if (!this.receiptUploaded || !this.contentDocumentId) {
            this.modalError = 'Please upload a receipt first ⬆️';
            return;
        }

        try {
            await attachReceiptToExpense({
                expenseId: this.currentExpenseId,
                contentDocumentId: this.contentDocumentId
            });
            this.closeExpenseModal();
            this.showToast('Expense submitted successfully! 🎉');
            await this.loadDashboard();
        } catch (err) {
            this.modalError = err.body?.message || 'Error submitting expense';
        }
    }

    // ── Back to Step 1 ────────────────────────────────────────────────────────
    async handleBackToForm() {
        // Delete draft created in step 1
        if (this.currentExpenseId) {
            try {
                await deleteDraftExpense({
                    expenseId: this.currentExpenseId
                });
            } catch (e) {
                console.error('Draft delete error:', e);
            }
        }
        this.currentExpenseId = '';
        this.receiptUploaded = false;
        this.contentDocumentId = '';
        this.showUploadStep = false;
        this.modalError = '';
    }

    resetExpenseForm() {
        this.claimTitle = '';
        this.expenseDate = '';
        this.remarks = '';
        this.lineItems = [];
        this.contentDocumentId = '';
        this.receiptUploaded = false;
        this.modalError = '';
        this.currentExpenseId = '';
        this.showUploadStep = false;
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