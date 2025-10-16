# Sign in with Apple — iOS Setup (Flutter)

This project is configured for **Apple Sign-In** on iOS with Firebase Auth.

## Dependencies
- `firebase_core`
- `firebase_auth`
- `sign_in_with_apple`
- `crypto`

Run:
```
flutter pub get
```

## Firebase
Ensure Firebase is initialized in `lib/main.dart` with `DefaultFirebaseOptions` (already present).

## Apple Developer
1. Apple Developer → Identifiers → select your iOS App ID (`com.gearup.learn`)  
   Enable **Sign In with Apple** capability and regenerate provisioning profile if needed.
2. Xcode → Runner target → Signing & Capabilities → add **Sign In with Apple**.
3. App Store Connect → App Privacy & review notes: declare account creation/sign-in if used.

## iOS Entitlements
`ios/Runner/Runner.entitlements` includes:
```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
```
Make sure the capability is also visible in Xcode.

## UI
- `lib/pages/welcome_page.dart` → Apple-only sign-in button.
- `lib/pages/profile_page.dart` → Apple-only connect/link + disconnect.
- `lib/services/auth_service.dart` → Apple-only auth logic with nonce for Firebase.

## Notes
- The Apple full name is available only on the first authorization. We update `displayName` if provided.
- No Google Sign-In is included in this iOS project.
