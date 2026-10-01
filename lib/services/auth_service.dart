import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for handling Firebase Authentication operations.
///
/// This singleton service manages:
/// - Google Sign-In flow
/// - User authentication state
/// - Sign-out operations
///
/// All Firestore data is scoped to the authenticated user's UID.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of authentication state changes.
  /// Emits User object when signed in, null when signed out.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Signs in user with Google account.
  ///
  /// Throws an [Exception] if user cancels the sign-in process.
  /// Returns [UserCredential] on successful authentication.
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Always sign out first to force a fresh Google sign-in (prevents token errors after account deletion)
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Sign-in was cancelled by user");
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw Exception("Google Sign-In failed: No access token or ID token returned. Please try again.");
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception("Google Sign-In failed: \\${e.toString()}");
    }
  }

  /// Signs out the current user from both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception("Sign-out failed: ${e.toString()}");
    }
  }

  /// Gets the currently authenticated user, or null if not signed in.
  User? get currentUser => _auth.currentUser;

  /// Gets the current user's ID.
  /// Returns 'demo-user' as fallback if no user is authenticated.
  /// WARNING: This fallback should only be used for development/testing.
  String get currentUserId => _auth.currentUser?.uid ?? 'demo-user';
}