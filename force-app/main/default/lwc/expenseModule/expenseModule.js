import { LightningElement, track } from 'lwc';
import getExpenses from '@salesforce/apex/ExpenseController.getExpenses';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import cancelExpense from '@salesforce/apex/ExpenseController.cancelExpense';
import getReceiptUrl from '@salesforce/apex/ExpenseController.getReceiptUrl';

export default class ExpenseModule extends LightningElement {

    @track isLoading = true;
    @track expenses = [];
    @track claimTitle = '';
    @track expenseDate = '';
    @track remarks = '';
    @track lineItems = [];
    @track errorMessage = '';
    @track successMessage = '';
    @track contentDocumentId = '';
    @track receiptUploaded = false;

    // Dummy record id for file upload
    // Will be replaced after expense creation
    dummyRecordId = null;

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    get categoryOptions() {
        return [
            { label: 'Travel', value: 'Travel' },
            { label: 'Food', value: 'Food' },
            { label: 'Accommodation', value: 'Accommodation' },
            { label: 'Fuel', value: 'Fuel' },
            { label: 'Internet', value: 'Internet' },
            { label: 'Training', value: 'Training' },
            { label: 'Office Supplies', value: 'Office Supplies' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get totalAmount() {
        let total = 0;
        this.lineItems.forEach(item => {
            total += parseFloat(item.amount) || 0;
        });
        return total.toFixed(2);
    }

    connectedCallback() {
        this.loadExpenses();
        // Add one empty line item by default
        this.handleAddLineItem();
    }

    loadExpenses() {
        this.isLoading = true;
        getExpenses()
            .then(result => {
                this.expenses = result.map(exp => {
                    return {
                        ...exp,
                        canCancel: exp.Status__c === 'Draft' ||
                                   exp.Status__c === 'Submitted'
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error(error);
                this.isLoading = false;
            });
    }

    handleClaimTitleChange(event) {
        this.claimTitle = event.target.value;
    }

    handleExpenseDateChange(event) {
        this.expenseDate = event.target.value;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    // Line Item Handlers
    handleAddLineItem() {
        this.lineItems = [
            ...this.lineItems,
            {
                key: Date.now(),
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
            (item, i) => {
                if(i === index) {
                    return {
                        ...item,
                        category: event.target.value
                    };
                }
                return item;
            }
        );
    }

    handleAmountChange(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map(
            (item, i) => {
                if(i === index) {
                    return {
                        ...item,
                        amount: event.target.value
                    };
                }
                return item;
            }
        );
    }

    handleDescriptionChange(event) {
        const index =
            parseInt(event.target.dataset.index);
        this.lineItems = this.lineItems.map(
            (item, i) => {
                if(i === index) {
                    return {
                        ...item,
                        description: event.target.value
                    };
                }
                return item;
            }
        );
    }

    // Receipt Upload
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if(uploadedFiles.length > 0) {
            this.contentDocumentId =
                uploadedFiles[0].documentId;
            this.receiptUploaded = true;
        }
    }

    // Submit Expense
    handleSubmitExpense() {

        this.errorMessage = '';
        this.successMessage = '';

        // Validations
        if(!this.claimTitle) {
            this.errorMessage =
                'Please enter claim title';
            return;
        }
        if(!this.expenseDate) {
            this.errorMessage =
                'Please select expense date';
            return;
        }
        if(this.lineItems.length === 0) {
            this.errorMessage =
                'Please add at least one line item';
            return;
        }
        if(!this.contentDocumentId) {
            this.errorMessage =
                'Please upload receipt';
            return;
        }

        this.isLoading = true;

        createExpense({
            claimTitle: this.claimTitle,
            expenseDate: this.expenseDate,
            remarks: this.remarks,
            lineItemsJson: JSON.stringify(
                this.lineItems
            ),
            contentDocumentId: this.contentDocumentId
        })
        .then(() => {
            this.successMessage =
                'Expense submitted successfully';
            this.resetForm();
            this.loadExpenses();
        })
        .catch(error => {
            let errMsg = 'Error submitting expense';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors &&
                    error.body.pageErrors.length > 0) {
                    errMsg =
                        error.body.pageErrors[0].message;
                } else if(error.body.output &&
                    error.body.output.errors &&
                    error.body.output.errors.length > 0) {
                    errMsg =
                        error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
            this.isLoading = false;
        });
    }

    // Cancel Expense
    handleCancelExpense(event) {
        const expenseId = event.target.dataset.id;
        this.isLoading = true;
        cancelExpense({ expenseId: expenseId })
            .then(() => {
                this.successMessage =
                    'Expense cancelled successfully';
                this.loadExpenses();
            })
            .catch(error => {
            let errMsg = 'Error cancelling expense';
            if(error.body) {
                if(error.body.message) {
                    errMsg = error.body.message;
                } else if(error.body.pageErrors &&
                    error.body.pageErrors.length > 0) {
                    errMsg =
                        error.body.pageErrors[0].message;
                } else if(error.body.output &&
                    error.body.output.errors &&
                    error.body.output.errors.length > 0) {
                    errMsg =
                        error.body.output.errors[0].message;
                }
            }
            this.errorMessage = errMsg;
            this.isLoading = false;
        });
    }

    handleViewReceipt(event) {
        const expenseId = event.target.dataset.id;
        getReceiptUrl({ expenseId: expenseId })
            .then(url => {
                if(url) {
                    window.open(url, '_blank');
                } else {
                    this.errorMessage =
                        'No receipt found';
                }
            })
            .catch(error => {
                this.errorMessage =
                    error.body?.message ||
                    'Error fetching receipt';
            });
    }

    // Reset Form
    resetForm() {
        this.claimTitle = '';
        this.expenseDate = '';
        this.remarks = '';
        this.lineItems = [];
        this.contentDocumentId = '';
        this.receiptUploaded = false;
        this.handleAddLineItem();
    }
}