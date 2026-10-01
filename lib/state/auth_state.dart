import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay for sign-in process
    await Future.delayed(const Duration(seconds: 2));

    // For now, just set logged in to true
    // Later this will be replaced with actual Firebase Google Sign-In
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    // Simulate sign out delay
    await Future.delayed(const Duration(milliseconds: 500));

    _isLoggedIn = false;
    _isLoading = false;
    notifyListeners();
  }
}