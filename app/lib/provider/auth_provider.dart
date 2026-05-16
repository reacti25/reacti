import 'package:flutter/material.dart';

/// [ChangeNotifier] holding transient UI state for the authentication screens.
///
/// Tracks password-field obscure toggles and the terms-acceptance checkbox so
/// login, signup, password-reset, and change-password forms can react to user
/// taps. Each mutation calls [notifyListeners] to rebuild listening widgets.
class AuthProvider extends ChangeNotifier {
  /// Whether the login password field is obscured.
  bool _isLoginPassVisible = true;

  /// Whether the signup password field is obscured.
  bool _isSignupPassVisible = true;

  /// Whether the reset-flow new-password field is obscured.
  bool _isResetNewPassVisible = true;

  /// Whether the reset-flow confirm-new-password field is obscured.
  bool _isResetConfNewPassVisible = true;

  /// Whether the user has accepted the terms and conditions.
  bool _isAccept = false;

  /// Whether the login password is currently obscured.
  bool get isLoginPassVisible => _isLoginPassVisible;

  /// Whether the signup password is currently obscured.
  bool get isSignupPassVisible => _isSignupPassVisible;

  /// Whether the reset-flow new password is currently obscured.
  bool get isResetNewPassVisible => _isResetNewPassVisible;

  /// Whether the reset-flow confirm password is currently obscured.
  bool get isResetConfNewPassVisible => _isResetConfNewPassVisible;

  /// Whether the terms have been accepted.
  bool get isAccept => _isAccept;

  /// Toggles obscuring of the login password field.
  void toggleLoginPass() {
    _isLoginPassVisible = !_isLoginPassVisible;
    notifyListeners();
  }

  /// Toggles obscuring of the signup password field.
  void toggleSignupPass() {
    _isSignupPassVisible = !_isSignupPassVisible;
    notifyListeners();
  }

  /// Toggles obscuring of the reset-flow new-password field.
  void toggleResetNewPass() {
    _isResetNewPassVisible = !_isResetNewPassVisible;
    notifyListeners();
  }

  /// Toggles obscuring of the reset-flow confirm-password field.
  void toggleResetConfNewPass() {
    _isResetConfNewPassVisible = !_isResetConfNewPassVisible;
    notifyListeners();
  }

  /// Toggles the terms-and-conditions acceptance flag.
  void toggleIsAccept() {
    _isAccept = !_isAccept;
    notifyListeners();
  }

  /// Whether the change-password "old password" field is obscured.
  bool _isOldPassVisible = true;

  /// Whether the old-password field is currently obscured.
  bool get isOldPassVisible => _isOldPassVisible;

  /// Toggles obscuring of the change-password old-password field.
  void toggleOldPassVisiable() {
    _isOldPassVisible = !_isOldPassVisible;
    notifyListeners();
  }

  /// Whether the change-password "new password" field is obscured.
  bool _isNewPassVisible = true;

  /// Whether the new-password field is currently obscured.
  bool get isNewPassVisible => _isNewPassVisible;

  /// Toggles obscuring of the change-password new-password field.
  void toggleNewPassVisiable() {
    _isNewPassVisible = !_isNewPassVisible;
    notifyListeners();
  }

  /// Whether the change-password "confirm password" field is obscured.
  bool _isConfirmPassVisible = true;

  /// Whether the confirm-password field is currently obscured.
  bool get isConfirmPassVisible => _isConfirmPassVisible;

  /// Toggles obscuring of the change-password confirm-password field.
  void toggleConfirmPassVisiable() {
    _isConfirmPassVisible = !_isConfirmPassVisible;
    notifyListeners();
  }
}
