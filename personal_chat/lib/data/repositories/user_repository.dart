import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/firebase_config.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  Future<UserModel?> getUserById(String uid) async {
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (userDoc.exists) {
      return UserModel.fromMap(userDoc.data()!);
    }
    return null;
  }

  Future<UserModel?> getUserByUniqueId(String uniqueUserId) async {
    final result = await _firestore
        .collection(AppConstants.usersCollection)
        .where('userId', isEqualTo: uniqueUserId)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      return UserModel.fromMap(result.docs.first.data());
    }
    return null;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    // Search by unique user ID
    final byUserId = await _firestore
        .collection(AppConstants.usersCollection)
        .where('userId', isEqualTo: query.toUpperCase())
        .limit(AppConstants.searchResultsLimit)
        .get();

    if (byUserId.docs.isNotEmpty) {
      return byUserId.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    }

    // Search by username (case-insensitive via lowercase field)
    final lowerQuery = query.toLowerCase();
    final byUsername = await _firestore
        .collection(AppConstants.usersCollection)
        .where('usernameLowercase', isGreaterThanOrEqualTo: lowerQuery)
        .where('usernameLowercase', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .limit(AppConstants.searchResultsLimit)
        .get();

    return byUsername.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .update(user.toMap());
  }

  Future<void> updateUserPhoto(String userId, String photoUrl) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'photoUrl': photoUrl});
  }

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
          'isOnline': isOnline,
          'lastSeen': DateTime.now().toIso8601String(),
        });
  }

  Stream<UserModel?> userStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return UserModel.fromMap(snapshot.data()!);
          }
          return null;
        });
  }
}
