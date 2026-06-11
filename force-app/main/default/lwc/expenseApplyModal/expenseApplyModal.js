import { api, LightningElement, track } from 'lwc';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import attachReceiptToExpense from '@salesforce/apex/ExpenseController.attachReceiptToExpense';
import deleteDraftExpense from '@salesforce/apex/ExpenseController.deleteDraftExpense';

export default class ExpenseApplyModal extends LightningElement {
    @track isOpen = false;
    @track showUploadStep = false;
    @track claimTitle = '';
    @track expenseDate = '';
    @track remarks = '';
    @track lineItems = [];
    @track contentDocumentId = '';
    @track receiptUploaded = false;
    @track errorMessage = '';
    @track currentExpenseId = '';

    @api openModal() {
        this.resetForm();
        this.handleAddLineItem();
        this.isOpen = true;
    }

    @api async closeModal() {
        await this.cleanupDraftExpense();
        this.isOpen = false;
        this.resetForm();
    }

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
        this.lineItems = [...this.lineItems, {
            key: Date.now() + Math.random(),
            category: '',
            amount: '',
            description: ''
        }];
    }

    handleRemoveLineItem(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.lineItems = this.lineItems.filter((item, i) => i !== index);
    }

    handleCategoryChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, category: event.target.value } : item
        );
    }

    handleAmountChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, amount: event.target.value } : item
        );
    }

    handleDescriptionChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.lineItems = this.lineItems.map((item, i) =>
            i === index ? { ...item, description: event.target.value } : item
        );
    }

    async handleCreateExpense() {
        this.errorMessage = '';
        if (!this.claimTitle) {
            this.errorMessage = 'Please enter claim title';
            return;
        }
        if (!this.expenseDate) {
            this.errorMessage = 'Please select expense date';
            return;
        }
        if (this.lineItems.length === 0) {
            this.errorMessage = 'Please add at least one line item';
            return;
        }
        if (parseFloat(this.totalAmount) <= 0) {
            this.errorMessage = 'Total amount must be greater than 0';
            return;
        }

        for (let i = 0; i < this.lineItems.length; i++) {
            const item = this.lineItems[i];
            if (!item.category) {
                this.errorMessage = `Please select category for line item ${i + 1}`;
                return;
            }
            if (!item.amount || parseFloat(item.amount) <= 0) {
                this.errorMessage = `Please enter valid amount for line item ${i + 1}`;
                return;
            }
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
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error creating expense';
        }
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        if (files.length > 0) {
            this.contentDocumentId = files[0].documentId;
            this.receiptUploaded = true;
            this.errorMessage = '';
        }
    }

    async handleFinalSubmit() {
        this.errorMessage = '';
        if (!this.receiptUploaded || !this.contentDocumentId) {
            this.errorMessage = 'Please upload a receipt first';
            return;
        }

        try {
            await attachReceiptToExpense({
                expenseId: this.currentExpenseId,
                contentDocumentId: this.contentDocumentId
            });
            this.isOpen = false;
            this.resetForm();
            this.dispatchEvent(new CustomEvent('success'));
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error submitting expense';
        }
    }

    async handleBackToForm() {
        await this.cleanupDraftExpense();
        this.showUploadStep = false;
        this.errorMessage = '';
    }

    async cleanupDraftExpense() {
        if (!this.currentExpenseId) {
            return;
        }

        try {
            await deleteDraftExpense({
                expenseId: this.currentExpenseId
            });
        } catch (error) {
            // Ignore cleanup failures so the user can keep working.
            // The parent refresh after submission handles the happy path.
        }

        this.currentExpenseId = '';
        this.contentDocumentId = '';
        this.receiptUploaded = false;
    }

    resetForm() {
        this.showUploadStep = false;
        this.claimTitle = '';
        this.expenseDate = '';
        this.remarks = '';
        this.lineItems = [];
        this.contentDocumentId = '';
        this.receiptUploaded = false;
        this.errorMessage = '';
        this.currentExpenseId = '';
    }
}
