import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTodayAttendance from '@salesforce/apex/AttendanceController.getTodayAttendance';
import doCheckIn from '@salesforce/apex/AttendanceController.doCheckIn';
import doCheckOut from '@salesforce/apex/AttendanceController.doCheckOut';

export default class AttendanceCheckin extends LightningElement {

    @track isLoading = true;
    @track error = null;
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

    get hasError() {
        return this.error !== null
            && this.error !== undefined;
    }
    // Load today attendance on component load
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
                this.error = error.body?.message
                    || 'Error loading attendance';
                this.isLoading = false;
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
                this.error = error.body?.message
                    || 'Error during Check In';
                this.isLoading = false;
                this.showToast(
                    'Error',
                    this.error,
                    'error'
                );
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
                this.error = error.body?.message
                    || 'Error during Check Out';
                this.isLoading = false;
                this.showToast(
                    'Error',
                    this.error,
                    'error'
                );
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