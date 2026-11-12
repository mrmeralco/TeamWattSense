# Firebase appliance catalog

The app reads shared catalog entries from Firestore's `appliance_catalog`
collection. The catalog is public-read and client-write-disabled by
`firestore.rules`. Appliance selections and custom household appliances still
use the app's existing local storage.

To seed or refresh the shared catalog, install the Firebase Admin SDK in this
folder, authenticate with Google Application Default Credentials for the
Firebase project, then run the seed script from the repository root:

```powershell
npm install --prefix tools/firebase-seed --no-save firebase-admin
node tools/firebase-seed/seed.mjs
```

To deploy the read-only catalog rule, use the Firebase CLI while authenticated
to the configured project:

```powershell
firebase deploy --only firestore:rules
```

The app includes a bundled copy of the same catalog so search remains usable
offline and before Firestore has been seeded.
