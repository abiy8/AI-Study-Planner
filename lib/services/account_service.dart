import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for deleting user account and all user data.
class AccountService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Deletes the user's Firestore data and authentication account.
  Future<void> deleteAccountAndData({Function(String)? onError, Function()? onRequiresRecentLogin}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final userId = user.uid;
    // Delete all user data in Firestore
    final userDoc = _db.collection('users').doc(userId);
    final courses = await userDoc.collection('courses').get();
    for (final course in courses.docs) {
      final tasks = await course.reference.collection('tasks').get();
      for (final task in tasks.docs) {
        await task.reference.delete();
      }
      await course.reference.delete();
    }
    await userDoc.delete();

    // Try to delete authentication account with explicit Google re-auth
    try {
      try {
        await user.delete();
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          // Force a fresh Google sign-in (not cached)
          final googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) throw Exception('Google re-authentication cancelled.');
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(credential);
          await user.delete();
        } else {
          if (onError != null) onError(e.toString());
          throw Exception('Failed to delete account: $e');
        }
      }
      // After deletion, sign out from Firebase and Google
      await _auth.signOut();
      await GoogleSignIn().signOut();
      // Double-check: user should be null
      if (_auth.currentUser != null) {
        throw Exception('Account deletion failed: user still exists.');
      }
    } catch (e) {
      if (onError != null) onError(e.toString());
      throw Exception('Failed to delete account: $e');
    }
  }
}
