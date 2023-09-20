# Password Expiry Email Notifications Guide
Last updated **22-02-2018** for ManageEngine</br>
How to setup & configure ManageEngine to send staff email notifications leading up to their passwords expiring.
</br>
[ManageEngine ADSelfService Plus - Free Password Expiry Reminder Tool](https://www.manageengine.com.au/products/self-service-password/free-password-expiry-notification-tool.html)

</br>

## **Overview**
---




---

## Email Templates

Attachments:
- How to change your school password
- Curric network password requirements (Complex-7)

Send notifications at:
- 28 days out
- 14 days out
- 7 days out
- 3 days out
- 1 days out
- 0 days out

**X Days > 0**
---
Mooroopna Park PS - Password Expiry Notification
---
Dear %givenName%,

The password for your Mooroopna Park Primary School account (%sAMAccountName%) is due to expire in %noOfDays% days.

Please change your domain password as soon as possible.

Regards,
Your Specialist Technician


**0 Days**
---
[URGENT] Mooroopna Park PS - Password Expiry Notification
---
Dear %givenName%,

Despite all of the reminders, you still have not changed the password for your Mooroopna Park Primary School account (%userName%) which expires today.

If you do not change it now, you may find yourself locked out of your computer!

Please change your domain password immediately.

Regards,
Your Specialist Technician




# NOTES
---
To install and start ADSelfService Plus as a service:
1. Please stop the ADSelfService Plus if it is running. (Start-->All Programs-->ADSelfService Plus-->Stop ADSelfService Plus)
2. Install as a Service. (Start-->All Programs-->ADSelfService Plus-->NT Service-->Install ADSelfService Plus as Service)
3. Start as a service
     • Start-->Run and type "services.msc"
     • Right-click on "ManageEngine ADSelfService Plus" and Click on Start.


SMTP Server
smtp.edumail.vic.gov.au

E-Mail Address
no-reply@edumail.vic.gov.au


Password complexity requirements summary:
     • Unique from your 8 most recent passwords
     • Minimum 7 characters
     • At least one character from at least three of the four sets below:
          • Lowercase characters (a - z)
          • Uppercase characters (A - Z)
          • Numeric characters (0 - 9)
          • Special characters and punctuations (e.g. ! @ # $ % ^ & .)


Replace with scheduled PowerShell script?