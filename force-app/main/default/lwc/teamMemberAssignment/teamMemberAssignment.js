import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTeamEmployees from '@salesforce/apex/TeamMemberAssignmentController.getTeamEmployees';
import saveTeamMembers from '@salesforce/apex/TeamMemberAssignmentController.saveTeamMembers';

export default class TeamMemberAssignment extends LightningElement {

    @api recordId;
    @track showModal = false;
    @track isLoading = false;
    @track isSaving = false;
    @track errorMessage = '';
    @track searchTerm = '';
    @track employees = [];
    @track selectedIds = new Set();

    // ── Open Modal ────────────────────────────────────────────────────────────
    async openModal() {
        this.showModal = true;
        this.isLoading = true;
        this.errorMessage = '';
        this.searchTerm = '';

        try {
            const result = await getTeamEmployees({ 
                teamId: this.recordId 
            });

            this.employees = (result.employees || []).map(emp => ({
                ...emp,
                isCurrentTeam: emp.Team__c === this.recordId,
                isOtherTeam: emp.Team__c != null && 
                             emp.Team__c !== this.recordId
            }));

            // Pre-select current members
            this.selectedIds = new Set(
                result.currentMembers || []
            );

        } catch(err) {
            this.errorMessage = err.body?.message || 
                'Error loading employees';
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.showModal = false;
        this.employees = [];
        this.selectedIds = new Set();
        this.errorMessage = '';
    }

    // ── Toggle Selection ──────────────────────────────────────────────────────
    handleToggle(event) {
        const empId = event.currentTarget.dataset.id;
        if(this.selectedIds.has(empId)) {
            this.selectedIds.delete(empId);
        } else {
            this.selectedIds.add(empId);
        }
        this.selectedIds = new Set(this.selectedIds);
    }

    // ── Search ────────────────────────────────────────────────────────────────
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get filteredEmployees() {
        return this.employees
            .filter(emp => {
                if(!this.searchTerm) return true;
                const name = (
                    (emp.First_Name__c || '') + ' ' + 
                    (emp.Last_Name__c || '') + ' ' +
                    (emp.Email__c || '') + ' ' +
                    (emp.Designation__c || '')
                ).toLowerCase();
                return name.includes(this.searchTerm);
            })
            .map(emp => ({
                ...emp,
                isSelected: this.selectedIds.has(emp.Id),
                rowClass: this.selectedIds.has(emp.Id)
                    ? 'emp-row selected'
                    : 'emp-row',
                checkClass: this.selectedIds.has(emp.Id)
                    ? 'check-icon checked'
                    : 'check-icon',
                checkIcon: this.selectedIds.has(emp.Id)
                    ? '✅' : '⬜'
            }));
    }

    get hasEmployees() {
        return this.filteredEmployees.length > 0;
    }
    
    get totalCount() {
        return this.filteredEmployees.length;
    }

    get selectedCount() {
        return this.selectedIds.size;
    }

    // ── Save ──────────────────────────────────────────────────────────────────
    async handleSave() {
        this.isSaving = true;
        this.errorMessage = '';

        try {
            await saveTeamMembers({
                teamId: this.recordId,
                selectedEmpIds: [...this.selectedIds]
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Team members updated successfully!',
                variant: 'success'
            }));

            this.closeModal();

        } catch(err) {
            this.errorMessage = err.body?.message || 
                'Error saving team members';
        } finally {
            this.isSaving = false;
        }
    }
}