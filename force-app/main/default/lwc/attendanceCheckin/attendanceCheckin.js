import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTodayAttendance from '@salesforce/apex/AttendanceController.getTodayAttendance';
import doCheckIn from '@salesforce/apex/AttendanceController.doCheckIn';
import doCheckOut from '@salesforce/apex/AttendanceController.doCheckOut';

export default class AttendanceCheckin extends LightningElement {

    @track isLoading = true;
    @track attendanceRecord = null;

    // Getters
    get todayDate() {
        return new Date().toLocaleDateString('en-IN');
    }

    get hasCheckedIn() {
        return this.attendanceRecord &&
            this.attendanceRecord.Is_Check_In_Done__c;
    }

    get hasCheckedOut() {
        return this.attendanceRecord &&
            this.attendanceRecord.Is_Check_Out_Done__c;
    }

    get checkInTime() {
        if (!this.attendanceRecord?.Check_In__c)
            return '';
        return new Date(this.attendanceRecord.Check_In__c)
            .toLocaleTimeString('en-IN');
    }

    get checkOutTime() {
        if (!this.attendanceRecord?.Check_Out__c)
            return '';
        return new Date(this.attendanceRecord.Check_Out__c)
            .toLocaleTimeString('en-IN');
    }

    get workingHours() {
        return this.attendanceRecord?.Working_Hours__c
            ? this.attendanceRecord.Working_Hours__c + ' hrs'
            : '';
    }

    get attendanceStatus() {
        return this.attendanceRecord?.Attendance_Status__c
            || '';
    }

    connectedCallback() {
        this.loadTodayAttendance();
    }

    loadTodayAttendance() {
        this.isLoading = true;
        getTodayAttendance()
            .then(result => {
                this.attendanceRecord = result;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Load Attendance Error:', JSON.stringify(error));
                let errMsg = 'Error loading attendance';
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

    // Check In
    handleCheckIn() {
        this.isLoading = true;
        doCheckIn()
            .then(result => {
                this.attendanceRecord = result;
                this.isLoading = false;
                this.showToast(
                    'Success',
                    'Checked In Successfully',
                    'success'
                );
            })
            .catch(error => {
                console.error('Check In Error:', JSON.stringify(error));
                let errMsg = 'Error during Check In';
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

    // Check Out
    handleCheckOut() {
        this.isLoading = true;
        doCheckOut()
            .then(result => {
                this.attendanceRecord = result;
                this.isLoading = false;
                this.showToast(
                    'Success',
                    'Checked Out Successfully',
                    'success'
                );
            })
            .catch(error => {
                console.error('Check Out Error:', JSON.stringify(error));
                let errMsg = 'Error during Check Out';
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

    // Toast
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