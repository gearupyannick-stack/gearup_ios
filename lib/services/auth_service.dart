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
