# WattWise account verification and policy acknowledgement

Registration creates a pending Firebase Authentication account. AuthSessionGate listens to userChanges and does not open the account workspace until emailVerified is true. VerificationScreen sends a Firebase verification link, provides a 60-second resend cooldown, reloads on app resume or manual confirmation, and supports sign-out. No numeric OTP service is used.

Login and registration require unchecked Terms and Privacy acknowledgements. The current policy version and UTC acknowledgement time are saved in the signed-in account's local SQLite preferences. A restored session without a current receipt must acknowledge the policies before entering the workspace. Policies can be reopened from Settings. Contact: mirangjoshua@gmail.com.

Firebase project: iseeapp-ddf3a. Saved and read back on 2026-11-12 for verification and password-reset templates:
- Sender display name: WattWise
- Sender local part: wattwise (default domain: iseeapp-ddf3a.firebaseapp.com)
- Reply-to: mirangjoshua@gmail.com

Firebase rejected custom subjects and message bodies with EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED. Their defaults still use %APP_NAME%, which can show the existing project brand. The project itself was not renamed. These templates are shared by all apps in this Firebase project. A custom sending domain is not configured. Do not claim the full email body has been rebranded until Firebase accepts the change and an actual email is checked.

Validation: Flutter widget tests cover unverified gating, verification refresh, sign-out, unchecked consent rejection, account database isolation, and receipt persistence. Real inbox delivery and a link click on a phone still require a user registration test. No email was sent to the support address during development.

The verification gate protects navigation in this app. Any future backend/Firestore/Storage endpoints that require verified email must also validate the Firebase token's email_verified claim server-side; a client navigation gate is not a server security rule. SQLite storage remains local and per account, without cloud sync.
