import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExpenses from
    '@salesforce/apex/ExpenseController.getExpenses';
import createExpense from
    '@salesforce/apex/ExpenseController.createExpense';
import attachReceiptToExpense from
    '@salesforce/apex/ExpenseController.attachReceiptToExpense';
import cancelExpense from
    '@salesforce/apex/ExpenseController.cancelExpense';
import getReceiptUrl from
    '@salesforce/apex/ExpenseController.getReceiptUrl';

export default class ExpenseModule extends LightningElement {

    @track isLoading = true;
    @track showModal = false;
    @track expenses = [];
    @track claimTitle = '';
    @track expenseDate = '';
    @track remarks = '';
    @track lineItems = [];
    @track modalError = '';
    @track contentDocumentId = '';
    @track receiptUploaded = false;
    @track createdExpenseId = null;

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    showToast(title, message, variant = 'success') {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    get totalAmount() {
        let total = 0;
        this.lineItems.forEach(item => {
            total += parseFloat(item.amount) || 0;
        });
        return total.toFixed(2);
    }

    get hasExpenses() {
        return this.expenses && this.expenses.length > 0;
    }

    get isSubmitDisabled() {
        return !this.receiptUploaded;
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
                console.error(error);
                this.isLoading = false;
            });
    }

    // Modal Open/Close
    openModal() {
        this.resetForm();
        this.handleAddLineItem();
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.resetForm();
    }

    stopProp(event) {
        event.stopPropagation();
    }

    // Form Handlers
    handleClaimTitleChange(event) {
        this.claimTitle = event.target.value;
    }

    handleExpenseDateChange(event) {
        this.expenseDate = event.target.value;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleAddLineItem() {
        this.lineItems = [
            ...this.lineItems,
            {
                key: Date.now() + Math.random(),
                category: '',
                amount: '',
                description: ''
            }
        ];
    }

    handleRemoveLineItem(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.filter(
            (item, i) => i !== index
        );
    }

    handleCategoryChange(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map(
            (item, i) => i === index
                ? { ...item, category: event.target.value }
                : item
        );
    }

    handleAmountChange(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map(
            (item, i) => i === index
                ? { ...item, amount: event.target.value }
                : item
        );
    }

    handleDescriptionChange(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map(
            (item, i) => i === index
                ? { ...item, description: event.target.value }
                : item
        );
    }

    // Step 1: Receipt Upload
    // lightning-file-upload bina record-id ke
    // File uploaded — documentId store karo
    handleUploadFinished(event) {
        const files = event.detail.files;
        if(files.length > 0) {
            this.contentDocumentId =
                files[0].documentId;
            this.receiptUploaded = true;
            this.modalError = '';
        }
    }

    // Step 2: Submit Expense
    handleSubmitExpense() {
        this.modalError = '';

        if(!this.claimTitle) {
            this.modalError = 'Claim title is required';
            return;
        }
        if(!this.expenseDate) {
            this.modalError = 'Expense date is required';
            return;
        }
        if(this.lineItems.length === 0) {
            this.modalError =
                'Add at least one line item';
            return;
        }
        if(!this.receiptUploaded) {
            this.modalError = 'Upload receipt first';
            return;
        }

        this.isLoading = true;

        // Step 1: Create expense + line items
        createExpense({
            claimTitle: this.claimTitle,
            expenseDate: this.expenseDate,
            remarks: this.remarks,
            lineItemsJson: JSON.stringify(
                this.lineItems
            )
        })
        .then(expenseId => {
            // Step 2: Attach receipt
            return attachReceiptToExpense({
                expenseId: expenseId,
                contentDocumentId:
                    this.contentDocumentId
            });
        })
        .then(() => {
            this.showToast('Success', 'Expense submitted successfully!', 'success');
            this.showModal = false;
            this.resetForm();
            this.loadExpenses();
        })
        .catch(error => {
            this.modalError =
                error.body?.message ||
                'Error submitting expense';
            this.showToast('Error', this.modalError, 'error');
            this.isLoading = false;
        });
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
                const errMsg = error.body?.message ||
                    'Error cancelling expense';
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
                this.showToast('Error',
                    error.body?.message ||
                    'Error fetching receipt', 'error');
            });
    }

    resetForm() {
        this.claimTitle = '';
        this.expenseDate = '';
        this.remarks = '';
        this.lineItems = [];
        this.contentDocumentId = '';
        this.receiptUploaded = false;
        this.modalError = '';
        this.createdExpenseId = null;
    }
}