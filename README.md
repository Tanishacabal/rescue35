# RESCUE 35

## Language

The language selector is available in the upper navigation areas. English and
Tagalog are supported, and the selected language is saved on the device. App
text and shared form labels update with the selected language.

## Push notifications

The app registers each signed-in device's Firebase Cloud Messaging token and
shows incoming messages as system notifications. Request status updates are also
saved to the in-app **Alerts** tab for citizens and responders.

Remote notifications are sent by the Firebase Cloud Functions in `functions/`.
Deploy them to the configured Firebase project:

```powershell
cd functions
npm install
cd ..
firebase deploy --only functions --project rescue35-951fc
```

The deployer needs Firebase CLI access and permission to deploy Cloud Functions.
The Firebase project must use the Blaze (pay-as-you-go) plan to deploy these
functions. Until then, the app shows request-based alerts and local
notifications only while the app is open; background/closed-app push requires
the deployed functions. Do not put a Firebase Admin SDK service-account key in
the Flutter app.

Before deployment, merge this rule into the project's existing Firestore
rules. Do not replace the existing rules, which protect the rest of the app:

```text
match /users/{userId}/notifications/{notificationId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null
    && request.auth.uid == userId
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead'])
    && request.resource.data.isRead is bool;
  allow create, delete: if false;
}
```

For iOS devices, configure an APNs authentication key in Firebase Console
(Project Settings > Cloud Messaging) and enable Push Notifications for the iOS
app's provisioning profile. Android uses the FCM configuration already included
in this project and requests notification permission on the device.

The functions send responders a system notification when a transport request
is submitted, and send the requesting citizen a system notification when its
status changes. Both are stored in the recipient's in-app Alerts list.
