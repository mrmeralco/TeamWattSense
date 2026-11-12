# Authentication and request limits

WattWise registration requires 10+ characters, an uppercase letter, a number and a non-whitespace special character. Existing logins are not revalidated against new registration rules. Per user instruction, the shared iseeapp-ddf3a Firebase password policy was NOT changed; this is WattWise client-side validation. Other clients and Firebase-hosted reset pages are not subject to this local validator.

Successful registration creates the pending Firebase user, attempts display-name update and verification delivery, signs out and shows an Account created dialog inviting the user to log in and verify. Verification failure is reported separately from account creation. The auth gate prevents temporary Firebase auto-sign-in from opening the workspace during registration.

Persistent per-installation limits count attempted network actions, including failures:
- Registration: 3/hour, at least 60 seconds apart.
- Login: 10/10 minutes, at least 3 seconds apart.
- Reset email and verification email: 5/hour each, at least 60 seconds apart.
- Verification refresh: 30/10 minutes, at least 5 seconds apart.
- Cloud sync: one cycle at a time and at least 10 seconds between starts; automatic retry every 30 seconds.
- Existing Mira/bill-reader limits remain 20 chats and 5 scans per day per local account database, with 10-second cooldowns.

Authentication counters use a separate SQLite database and survive app restart/sign-out. They contain action names/counts/times only, not passwords or email addresses. Client-side limits can be bypassed by clearing app data or modifying the app; Firebase's server protections remain in force. A shared cross-device AI quota/backend proxy has not been introduced in this change.

POP now applies on today's date when toggled, clears superseded future toggles, shows time-on/time-off fields immediately, and atomically saves sessions plus their peak/off-peak splits. Time input currently represents one same-day interval; overnight use must be entered separately for each day. Existing entries without time information are not assigned an invented split.
