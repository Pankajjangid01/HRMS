import { LightningElement, track }
from 'lwc';

import isGuest
from '@salesforce/user/isGuest';

import getCurrentUser
from '@salesforce/apex/UserInfoController.getCurrentUser';

export default class CurrentUserMenu
extends LightningElement {

    @track userName;
    @track profileName;
    @track photoUrl;

    isGuestUser = isGuest;

    connectedCallback() {

        if(this.isGuestUser) {
            return;
        }

        getCurrentUser()
        .then(result => {

            this.userName = result.Name;

            this.profileName =
                result.Profile.Name;

            this.photoUrl =
                result.SmallPhotoUrl;
        });
    }

    handleLogout() {

        window.location.href =
            '/secur/logout.jsp';
    }
}