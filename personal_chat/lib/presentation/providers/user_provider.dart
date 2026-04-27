import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();

  List<UserModel> _searchResults = [];
  UserModel? _selectedUser;
  bool _isSearching = false;
  String? _errorMessage;

  List<UserModel> get searchResults => _searchResults;
  UserModel? get selectedUser => _selectedUser;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  Future<UserModel?> searchUser(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return null;
    }

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _userRepository.searchUsers(query);
      _searchResults = results;
      _selectedUser = results.isNotEmpty ? results.first : null;
      _isSearching = false;
      notifyListeners();
      return _selectedUser;
    } catch (e) {
      _errorMessage = e.toString();
      _isSearching = false;
      notifyListeners();
      return null;
    }
  }

  Future<UserModel?> getUserByUniqueId(String uniqueUserId) async {
    _isSearching = true;
    notifyListeners();

    try {
      final user = await _userRepository.getUserByUniqueId(uniqueUserId);
      _selectedUser = user;
      _isSearching = false;
      notifyListeners();
      return user;
    } catch (e) {
      _errorMessage = e.toString();
      _isSearching = false;
      notifyListeners();
      return null;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      return await _userRepository.getUserById(uid);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProfile(UserModel user) async {
    try {
      await _userRepository.updateUserProfile(user);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfilePhoto(String userId, String photoUrl) async {
    try {
      await _userRepository.updateUserPhoto(userId, photoUrl);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearSearch() {
    _searchResults = [];
    _selectedUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
