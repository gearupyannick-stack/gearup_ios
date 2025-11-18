// lib/services/auth_service.dart
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// AuthService
/// - Handles Sign in with Apple, Google Sign-In, and Firebase authentication integration.
/// - Uses singleton pattern for consistent state management
/// - Generates a secure random nonce for Apple Sign-In with SHA-256 hashing
///
/// NOTE:
/// - This file includes debug prints (debugPrint) that reveal whether Apple/Google
///   returned tokens and their lengths, but intentionally does NOT print the full
///   token text to avoid leaking sensitive tokens into logs.
///   Remove or reduce logging for production.
class AuthService {
  // Singleton pattern
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In singleton (v7.x)
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  bool _initialized = false;

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
      // ignore: unnecessary_null_comparison
      debugPrint('APPLE CRED: authorizationCode present? -> ${appleCred.authorizationCode != null}');
      debugPrint('APPLE CRED: authorizationCode length -> ${appleCred.authorizationCode.length}');
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

  /// Initialize Google Sign-In (optional, auto-initializes on first use)
  Future<void> init({String? serverClientId}) async {
    if (_initialized) return;
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  /// Check if user is signed in (Firebase is source of truth)
  Future<bool> isSignedIn() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        debugPrint('AuthService: User signed in via Firebase: ${firebaseUser.email}');
        return true;
      }
    } catch (e) {
      debugPrint('AuthService.isSignedIn error: $e');
    }
    return false;
  }

  /// Sign in with Google and return Firebase UserCredential
  /// Returns null if user cancels
  Future<UserCredential?> signInWithGoogle() async {
    if (!_initialized) {
      await init();
    }

    try {
      debugPrint('AuthService: Starting Google Sign-In...');

      // Check if authenticate() is supported on this platform
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError('authenticate() not supported on this platform');
      }

      // Step 1: Trigger Google Sign-In flow using authenticate() in v7.x
      debugPrint('AuthService: Calling authenticate()...');

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      debugPrint('AuthService: Got Google user: ${googleUser.email}');

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // In v7.x, idToken is the primary credential for Firebase
      final String? idToken = googleAuth.idToken;

      debugPrint('AuthService: Got idToken: ${idToken?.substring(0, 20)}...');

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'NO_ID_TOKEN',
          message: 'Failed to get idToken from Google Sign-In',
        );
      }

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null, // Not needed in v7.x for Firebase
      );

      // Step 4: Sign in to Firebase
      debugPrint('AuthService: Signing in to Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);

      debugPrint('AuthService: SUCCESS! Firebase user: ${userCredential.user?.email}');
      return userCredential;

    } on GoogleSignInException catch (e, stack) {
      // In v7.x, authenticate() throws GoogleSignInException when user cancels
      debugPrint('AuthService: GoogleSignInException - Code: ${e.code.name}, Message: ${e.description}\n$stack');

      // Return null for user cancellation
      if (e.code.name == 'cancelled' || e.code.name == 'canceled') {
        debugPrint('AuthService: User cancelled sign-in');
        return null;
      }
      rethrow;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('AuthService: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('AuthService: Unknown error: $e\n$stack');
      rethrow;
    }
  }

  /// Link anonymous account with Google account
  /// This preserves the user's UID and upgrades them from anonymous to Google auth
  /// Returns UserCredential on success, null if user cancels
  /// Throws FirebaseAuthException if account already exists
  Future<UserCredential?> linkGoogleAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'NO_CURRENT_USER',
          message: 'No user is currently signed in',
        );
      }

      if (!currentUser.isAnonymous) {
        throw FirebaseAuthException(
          code: 'NOT_ANONYMOUS',
          message: 'Current user is not anonymous',
        );
      }

      if (!_initialized) {
        await init();
      }

      debugPrint('AuthService: Linking anonymous account to Google...');

      // Step 1: Trigger Google Sign-In
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError('authenticate() not supported on this platform');
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      debugPrint('AuthService: Got Google user for linking: ${googleUser.email}');

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'NO_ID_TOKEN',
          message: 'Failed to get idToken from Google Sign-In',
        );
      }

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null,
      );

      // Step 4: Link the credential to the anonymous account
      debugPrint('AuthService: Linking credential to anonymous account...');
      final userCredential = await currentUser.linkWithCredential(credential);

      debugPrint('AuthService: SUCCESS! Linked account: ${userCredential.user?.email}, UID preserved: ${userCredential.user?.uid}');
      return userCredential;

    } on GoogleSignInException catch (e, stack) {
      debugPrint('AuthService: GoogleSignInException during linking - Code: ${e.code.name}, Message: ${e.description}\n$stack');

      // Return null for user cancellation
      if (e.code.name == 'cancelled' || e.code.name == 'canceled') {
        debugPrint('AuthService: User cancelled account linking');
        return null;
      }
      rethrow;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('AuthService: FirebaseAuthException during linking - Code: ${e.code}, Message: ${e.message}\n$stack');

      // Special handling for account-exists error
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        debugPrint('AuthService: Google account already exists elsewhere');
      }
      rethrow;
    } catch (e, stack) {
      debugPrint('AuthService: Unknown error during account linking: $e\n$stack');
      rethrow;
    }
  }

  /// Check if the current user is anonymous
  bool isAnonymous() {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      return user.isAnonymous;
    } catch (e) {
      debugPrint('AuthService.isAnonymous error: $e');
      return false;
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        if (_initialized) _googleSignIn.signOut(),
      ]);
      debugPrint('AuthService: Signed out successfully');
    } catch (e) {
      debugPrint('AuthService.signOut error: $e');
    }
  }

  /// Disconnect Google account (revokes access) and sign out from Firebase
  Future<void> disconnectGoogle() async {
    try {
      if (_initialized) {
        await _googleSignIn.disconnect();
        debugPrint('AuthService: Disconnected Google account');
      }
    } catch (e) {
      debugPrint('AuthService.disconnect error: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut error: $e');
    }
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