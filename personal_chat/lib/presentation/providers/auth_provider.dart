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
      // Check if email is taken
      final isEmailTaken = await _authRepository.isEmailTaken(email);
      if (isEmailTaken) {
        _errorMessage = 'This email is already registered';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      // Check if username is taken
      final isUsernameTaken = await _authRepository.isUsernameTaken(username);
      if (isUsernameTaken) {
        _errorMessage = 'This username is already taken';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

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
    } catch (e) {
      _errorMessage = 'Invalid email or password';
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
