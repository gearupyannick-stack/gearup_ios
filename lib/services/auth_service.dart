// lib/services/auth_service.dart
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in and return the full UserCredential (Firebase)
  /// Use this if your callers expect a UserCredential variable.
  Future<UserCredential> signInWithAppleCredential() async {
    if (!Platform.isIOS) {
      throw 'Apple Sign-In is only available on iOS.';
    }

    // secure nonce generation for Firebase compatibility
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
    );

    final userCred = await _auth.signInWithCredential(oauthCredential);

    // Optional: populate displayName on first sign-in if provided by Apple
    if (userCred.additionalUserInfo?.isNewUser == true) {
      final givenName = appleCred.givenName ?? '';
      final familyName = appleCred.familyName ?? '';
      final displayName = [givenName, familyName].where((s) => s.isNotEmpty).join(' ').trim();
      if (displayName.isNotEmpty) {
        try {
          await userCred.user?.updateDisplayName(displayName);
        } catch (_) {}
      }
    }

    return userCred;
  }

  /// Simple helper returning only the User object (or null)
  Future<User?> signInWithApple() async {
    final cred = await signInWithAppleCredential();
    return cred.user;
  }

  /// Backwards-compatibility alias for code that calls signInWithAppleIOSOnly()
  Future<UserCredential> signInWithAppleIOSOnly() async {
    return signInWithAppleCredential();
  }

  /// Anonymous sign-in (guest)
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  /* -------------------- Helpers -------------------- */

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}