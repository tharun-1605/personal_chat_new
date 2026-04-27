import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/services/encryption_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final EncryptionService _encryptionService = EncryptionService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _authRepository.authStateChanges.listen((user) {
        if (user != null) {
          _currentUser = user;
          _status = AuthStatus.authenticated;
          _encryptionService.initialize(user.id);
        } else {
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
      });
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Register user
      final user = await _authRepository.register(
        username: username,
        email: email,
        password: password,
      );

      _currentUser = user;
      _status = AuthStatus.authenticated;
      await _encryptionService.initialize(user.id);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage = 'This email is already registered';
          break;
        case 'invalid-email':
          _errorMessage = 'Invalid email format';
          break;
        case 'weak-password':
          _errorMessage = 'Password is too weak';
          break;
        default:
          _errorMessage = e.message ?? 'Registration failed';
      }
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _errorMessage = 'Database access denied. Check Firestore rules.';
      } else {
        _errorMessage = e.message ?? 'Registration failed';
      }
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );

      _currentUser = user;
      _status = AuthStatus.authenticated;
      await _encryptionService.initialize(user.id);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _errorMessage = 'No account found for this email';
          break;
        case 'wrong-password':
          _errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          _errorMessage = 'Invalid email format';
          break;
        case 'user-disabled':
          _errorMessage = 'This account has been disabled';
          break;
        case 'invalid-credential':
          _errorMessage = 'Email or password is incorrect';
          break;
        default:
          _errorMessage = e.message ?? 'Authentication failed';
      }
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authRepository.logout();
      await _encryptionService.clearKeys();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authRepository.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
