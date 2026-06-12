import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExpenses from
    '@salesforce/apex/ExpenseController.getExpenses';
import cancelExpense from
    '@salesforce/apex/ExpenseController.cancelExpense';
import getReceiptUrl from
    '@salesforce/apex/ExpenseController.getReceiptUrl';

export default class ExpenseModule extends LightningElement {

    @track isLoading = true;
    @track expenses = [];

    showToast(title, message, variant = 'success') {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    get hasExpenses() {
        return this.expenses && this.expenses.length > 0;
    }

    connectedCallback() {
        this.loadExpenses();
    }

    loadExpenses() {
        this.isLoading = true;
        getExpenses()
            .then(result => {
                this.expenses = result.map(exp => {
                    let statusClass = 'status-pill ';
                    const s = exp.Status__c;
                    if(s === 'Submitted') statusClass += 'submitted';
                    else if(s === 'Approved') statusClass += 'approved';
                    else if(s === 'Rejected') statusClass += 'rejected';
                    else if(s === 'Cancelled') statusClass += 'cancelled';
                    else statusClass += 'draft';

                    return {
                        ...exp,
                        statusClass,
                        canCancel: s === 'Draft' ||
                                   s === 'Submitted'
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Load Expenses Error:', JSON.stringify(error));
                let errMsg = 'Error loading expenses';
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

    // Modal Open/Close
    openModal() {
        this.template.querySelector('c-expense-apply-modal')?.openModal();
    }

    handleExpenseSubmitted() {
        this.showToast(
            'Success',
            'Expense submitted successfully!',
            'success'
        );
        this.loadExpenses();
    }

    // Cancel Expense
    handleCancelExpense(event) {
        const expenseId = event.target.dataset.id;
        this.isLoading = true;

        cancelExpense({ expenseId: expenseId })
            .then(() => {
                this.showToast('Success', 'Expense cancelled', 'success');
                this.loadExpenses();
            })
            .catch(error => {
                console.error('Cancel Expense Error:', JSON.stringify(error));
                let errMsg = 'Error cancelling expense';
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

    // View Receipt
    handleViewReceipt(event) {
        const expenseId = event.target.dataset.id;
        getReceiptUrl({ expenseId: expenseId })
            .then(url => {
                if(url) {
                    window.open(url, '_blank');
                } else {
                    this.showToast('Error', 'No receipt found', 'error');
                }
            })
            .catch(error => {
                console.error('View Receipt Error:', JSON.stringify(error));
                let errMsg = 'Error fetching receipt';
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
            });
    }

}
