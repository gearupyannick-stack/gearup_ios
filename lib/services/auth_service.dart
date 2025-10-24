// lib/services/auth_service.dart
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';

/// AuthService
/// - Handles Sign in with Apple and Firebase authentication integration.
/// - Generates a secure random nonce, computes its SHA-256, passes the hashed
///   nonce to Apple and the raw nonce to Firebase as required.
///
/// NOTE:
/// - This file includes debug prints (debugPrint) that reveal whether Apple
///   returned an identityToken / authorizationCode and the token lengths.
///   It intentionally does NOT print the full token text to avoid leaking
///   sensitive tokens into logs. Remove or reduce logging for production.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in and return the full UserCredential (Firebase)
  /// Throws descriptive exceptions when flows fail.
  Future<UserCredential> signInWithAppleCredential() async {
    if (!Platform.isIOS) {
      throw StateError('Apple Sign-In is only available on iOS.');
    }

    // secure nonce generation for Firebase compatibility
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    try {
      // Acquire Apple credential (ASAuthorization)
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      // Debugging: print presence and lengths (do NOT print tokens themselves)
      debugPrint('APPLE CRED: identityToken present? -> ${appleCred.identityToken != null}');
      debugPrint('APPLE CRED: identityToken length -> ${appleCred.identityToken?.length ?? 0}');
      debugPrint('APPLE CRED: authorizationCode present? -> ${appleCred.authorizationCode != null}');
      debugPrint('APPLE CRED: authorizationCode length -> ${appleCred.authorizationCode?.length ?? 0}');
      debugPrint('DEBUG NONCE: rawNonce length=${rawNonce.length}, sha256 length=${hashedNonce.length}');

      if (appleCred.identityToken == null || appleCred.identityToken!.isEmpty) {
        throw FirebaseAuthException(
          code: 'APPLE_IDENTITY_TOKEN_MISSING',
          message: 'Apple returned an empty identity token.',
        );
      }

      // Build Firebase OAuth credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credential
      final userCred = await _auth.signInWithCredential(oauthCredential);

      // Optional: populate displayName on first sign-in if provided by Apple
      if (userCred.additionalUserInfo?.isNewUser == true) {
        final givenName = appleCred.givenName ?? '';
        final familyName = appleCred.familyName ?? '';
        final displayName = [givenName, familyName].where((s) => s.isNotEmpty).join(' ').trim();
        if (displayName.isNotEmpty) {
          try {
            await userCred.user?.updateDisplayName(displayName);
          } catch (e) {
            // Non-blocking: log but continue
            debugPrint('Could not update displayName: $e');
          }
        }
      }

      return userCred;
    } catch (e, st) {
      // Print helpful debug info; rethrow an appropriate exception
      debugPrint('APPLE SIGN-IN ERROR: ${e.runtimeType} -> $e');
      debugPrint('STACKTRACE: $st');

      // If it's already a FirebaseAuthException, bubble it up
      if (e is FirebaseAuthException) {
        rethrow;
      }

      // If it's a SignInWithApple-related exception, include its text
      if (e is SignInWithAppleAuthorizationException) {
        throw FirebaseAuthException(
          code: 'APPLE_AUTH_FAILED',
          message: 'Sign in with Apple failed: ${e.toString()}',
        );
      }

      // Generic fallback
      throw FirebaseAuthException(
        code: 'APPLE_SIGNIN_UNKNOWN',
        message: 'Unknown error during Apple sign-in: ${e.toString()}',
      );
    }
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

  /// Generates a secure random nonce of [length] characters.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  /// Returns the SHA-256 hash of [input] as a hex string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}