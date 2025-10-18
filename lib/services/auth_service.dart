import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// auth_service.dart — STUB for iOS: Google Sign-In & FirebaseAuth removed.
// Keeps the same API shape but does not depend on firebase_auth/google_sign_in.
import 'dart:io' show Platform;

// Replace the existing AuthService class with this block.

class AuthService {
  // singleton factory (keeps the same API shape you already used)
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  /// Attempts to sign in with Google. On iOS this intentionally throws (disabled).
  Future<Map<String, String>?> signInWithGoogle() async {
    if (!Platform.isAndroid) {
      // Keep behavior consistent with your earlier stub.
      throw UnsupportedError('Google Sign-In disabled on iOS. Use Apple Sign-In instead.');
    }
    // If you re-enable Android Google sign-in later, implement it here.
    return null;
  }

  /// Sign out (no-op stub for now to preserve interface)
  Future<void> signOut() async {
    // No real sign-out implementation in this iOS-focused branch.
    return;
  }

  /// Returns a simple map describing a current user or `null` when no backend auth is present.
  Map<String, String>? get currentUser => null;

  // ---------------- Apple wrappers (exposed API for UI) ----------------

  /// UI-friendly wrapper: signs in with Apple and returns the Firebase UserCredential.
  /// Throws UnsupportedError on non-iOS builds.
  Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('signInWithApple is only supported on iOS in this build.');
    }
    // Delegates to the helper defined elsewhere in this file
    return await signInWithAppleIOSOnly(FirebaseAuth.instance);
  }

  /// UI-friendly wrapper: links the currently-signed-in Firebase user with Apple credentials.
  Future<UserCredential> linkWithApple() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('linkWithApple is only supported on iOS in this build.');
    }
    return await linkCurrentUserWithAppleIOSOnly(FirebaseAuth.instance);
  }
}

// === Apple Sign-In helpers (iOS only) ===

String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Convenience wrapper used by UI/dialogs to sign in with Apple.
/// Delegates to the platform helper that performs the OAuth flow and signs into Firebase.
Future<UserCredential> signInWithApple() async {
  // On non-iOS platforms you should not call this; keep for safety.
  if (!Platform.isIOS) {
    throw UnsupportedError('signInWithApple is only supported on iOS in this build.');
  }
  return await signInWithAppleIOSOnly(FirebaseAuth.instance);
}

/// Convenience wrapper to link the currently signed-in Firebase user with Apple credentials.
Future<UserCredential> linkWithApple() async {
  if (!Platform.isIOS) {
    throw UnsupportedError('linkWithApple is only supported on iOS in this build.');
  }
  return await linkCurrentUserWithAppleIOSOnly(FirebaseAuth.instance);
}

Future<UserCredential> signInWithAppleIOSOnly(FirebaseAuth auth) async {
  final rawNonce = _generateNonce();
  final nonce = _sha256ofString(rawNonce);

  final appleCred = await SignInWithApple.getAppleIDCredential(
    scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    nonce: nonce,
  );

  final oauthCred = OAuthProvider('apple.com').credential(
    idToken: appleCred.identityToken,
    rawNonce: rawNonce,
  );

  final userCred = await auth.signInWithCredential(oauthCred);
  final fullName = appleCred.givenName == null && appleCred.familyName == null
      ? null
      : '${appleCred.givenName ?? ''} ${appleCred.familyName ?? ''}'.trim();
  if (fullName != null && fullName.isNotEmpty) {
    await userCred.user?.updateDisplayName(fullName);
  }
  return userCred;
}

Future<UserCredential> linkCurrentUserWithAppleIOSOnly(FirebaseAuth auth) async {
  final user = auth.currentUser;
  if (user == null) {
    throw FirebaseAuthException(code: 'no-current-user', message: 'No current user to link.');
  }

  final rawNonce = _generateNonce();
  final nonce = _sha256ofString(rawNonce);

  final appleCred = await SignInWithApple.getAppleIDCredential(
    scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    nonce: nonce,
  );

  final oauthCred = OAuthProvider('apple.com').credential(
    idToken: appleCred.identityToken,
    rawNonce: rawNonce,
  );

  return await user.linkWithCredential(oauthCred);
}

