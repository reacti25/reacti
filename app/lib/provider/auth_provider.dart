import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoginPassVisible = true;
  bool _isSignupPassVisible = true;
  bool _isResetNewPassVisible = true;
  bool _isResetConfNewPassVisible = true;
  bool _isAccept = false;

  bool get isLoginPassVisible => _isLoginPassVisible;
  bool get isSignupPassVisible => _isSignupPassVisible;
  bool get isResetNewPassVisible => _isResetNewPassVisible;
  bool get isResetConfNewPassVisible => _isResetConfNewPassVisible;
  bool get isAccept => _isAccept;

  void toggleLoginPass() {
    _isLoginPassVisible = !_isLoginPassVisible;
    notifyListeners();
  }

  void toggleSignupPass() {
    _isSignupPassVisible = !_isSignupPassVisible;
    notifyListeners();
  }

  void toggleResetNewPass() {
    _isResetNewPassVisible = !_isResetNewPassVisible;
    notifyListeners();
  }

  void toggleResetConfNewPass() {
    _isResetConfNewPassVisible = !_isResetConfNewPassVisible;
    notifyListeners();
  }

  void toggleIsAccept() {
    _isAccept = !_isAccept;
    notifyListeners();
  }

  bool _isOldPassVisible = true;
  bool get isOldPassVisible => _isOldPassVisible;
  void toggleOldPassVisiable() {
    _isOldPassVisible = !_isOldPassVisible;
    notifyListeners();
  }

  bool _isNewPassVisible = true;
  bool get isNewPassVisible => _isNewPassVisible;
  void toggleNewPassVisiable() {
    _isNewPassVisible = !_isNewPassVisible;
    notifyListeners();
  }

  bool _isConfirmPassVisible = true;
  bool get isConfirmPassVisible => _isConfirmPassVisible;
  void toggleConfirmPassVisiable() {
    _isConfirmPassVisible = !_isConfirmPassVisible;
    notifyListeners();
  }
}
