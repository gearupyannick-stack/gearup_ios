// lib/services/auth_service.dart
// AuthService for google_sign_in 7.x with correct singleton API
// Version 7.x uses GoogleSignIn.instance and authenticate() method

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In v7.x, GoogleSignIn is a singleton accessed via .instance
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  bool _initialized = false;

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

  /// Get current Firebase user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      debugPrint('AuthService.currentUser error: $e');
      return null;
    }
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
      // In v7.x, authenticate() returns non-nullable GoogleSignInAccount or throws
      debugPrint('AuthService: Calling authenticate()...');

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      debugPrint('AuthService: Got Google user: ${googleUser.email}');

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // In v7.x, idToken is the primary credential for Firebase
      // accessToken is no longer directly available, but Firebase Auth doesn't require it
      final String? idToken = googleAuth.idToken;

      debugPrint('AuthService: Got idToken: ${idToken?.substring(0, 20)}...');

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'NO_ID_TOKEN',
          message: 'Failed to get idToken from Google Sign-In',
        );
      }

      // Step 3: Create Firebase credential (accessToken is optional for Firebase)
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null, // Not available in v7.x without additional scope requests
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

  /// Sign in anonymously to Firebase
  /// Returns the UserCredential with anonymous user
  Future<UserCredential?> signInAnonymously() async {
    try {
      debugPrint('AuthService: Starting Anonymous Sign-In...');
      final userCredential = await _auth.signInAnonymously();
      debugPrint('AuthService: SUCCESS! Anonymous user created: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('AuthService: FirebaseAuthException during anonymous sign-in - Code: ${e.code}, Message: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('AuthService: Unknown error during anonymous sign-in: $e\n$stack');
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
}