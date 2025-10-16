import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// auth_service.dart — STUB for iOS: Google Sign-In & FirebaseAuth removed.
// Keeps the same API shape but does not depend on firebase_auth/google_sign_in.
import 'dart:io' show Platform;

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  /// Attempts to sign in with Google. On iOS this is disabled and throws.
  Future<Map<String, String>?> signInWithGoogle() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Google Sign-In disabled on iOS. Use Apple Sign-In later.');
    }
    // On Android, you can re-enable real implementation here.
    return null;
  }

  Future<void> signOut() async {
    // No-op for now (no real auth). Keeps signature compatibility.
    return;
  }

  /// Returns current user as a map { 'uid': ..., 'email': ... } or null.
  Map<String,String>? get currentUser => null;
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

