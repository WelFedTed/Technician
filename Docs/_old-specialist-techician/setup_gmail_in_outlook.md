# How to Add Gmail Accounts to Outlook
Last updated **28-05-2018** for Outlook 2016</br>
How to add Gmail accounts to an Outlook client for sending & recieving emails.

</br>

## **Overview**
---

### Google Account
- Enable Basic Authentication
- Generate 2-Step Authentication App-Specific Password

### Gmail Account
- Enable IMAP Access

### Outlook Client
- Add Gmail Account

---

</br>

## **Google Account**
---
### Enable Basic Authentication
_If you do not have 2-Step Authentication enabled on your Google account:_

- Log in to your Google account: [Google: My Account](https://myaccount.google.com/)
- Navigate to: [Less secure apps](https://myaccount.google.com/lesssecureapps)
    - Turn on 'Allow less secure apps'.

### Generate 2-Step Authentication App-Specific Password
_If you do have 2-Step Authentication enabled on your Google account:_

- Log in to your Google account: [Google: My Account](https://myaccount.google.com/)
- Navigate to: [App passwords](https://security.google.com/settings/security/apppasswords/)
- Click 'Select app'
    - Select 'Other _(Custom name)_'
- Type the app name 'Outlook'
- Click 'Generate'

A app-specific 16 character password will then be generated and presented to you. </br>
Use this password in place of your regular Gmail account password when setting up the account in an Outlook client.

</br>

## **Gmail Account**
---
### Enable IMAP Access
- Log in to your Gmail account: [Gmail](https://mail.google.com/)
- Click the Gear icon in the upper right corner
    - Select 'Settings' menu item
- Select the 'Forwarding and POP/IMAP' tab
    - In the 'IMAP Access' section:
        - Select 'Enable IMAP'
        - Select 'Auto-Expunge on'
- Click 'Save Changes'

## **Outlook Client**
---
### Add Gmail Account
- Open Outlook client
- Click 'File'
- Click 'Add Account'
- Select 'Manual setup or additional server types'
- Click 'Next'
- Select 'POP or IMAP'
- Click 'Next'
- Complete the account form:
    - Your Name: John Smith
    - Email Address: john.smith@gmail.com
    - Account Type: IMAP
    - Incoming mail server: imap.gmail.com
    - Outgoing mail server (SMTP): smtp.gmail.com
    - User Name: john.smith@gmail.com
    - Password:
        - _If you do not have 2-Step Authentication enabled on your Google account:_
            - Enter your Gmail account password
        - _If you do have 2-Step Authentication enabled on your Google account:_
            - Enter your app-specific 16 character password for Outlook
    - Tick 'Remember password'
- Click 'More Settings...'
- Select the 'Outgoing Server' tab
    - Tick 'My outgoing server (SMTP) requires authentication'
        - Select 'Use same settings as my incoming mail server'
- Select the 'Advanced' tab
    - Set 'Incoming server (IMAP)' to: 993
        - Set 'Use the following type of encrypted connection' to: SSL
    - Set 'Outgoing server (SMTP)' to: 25
        - Set 'Use the following type of encrypted connection' to: AUTO
- Click 'OK'
- Click 'Next'
- Wait for setup tests to complete
- Click 'Close'
- Click 'Finish'