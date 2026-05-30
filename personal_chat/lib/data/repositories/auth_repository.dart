import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/firebase_config.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../../core/services/notification_service.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseConfig.auth;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final Uuid _uuid = const Uuid();

  String _generateUniqueUserId() {
    final random = _uuid.v4().substring(0, 8).toUpperCase();
    return '${AppConstants.userIdPrefix}$random';
  }

  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data()!);
      }
      return null;
    });
  }

  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .get();

    if (userDoc.exists) {
      return UserModel.fromMap(userDoc.data()!);
    }
    return null;
  }

  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    // Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Generate unique user ID
    final uniqueUserId = _generateUniqueUserId();

    // Create user document in Firestore
    final user = UserModel(
      id: userCredential.user!.uid,
      userId: uniqueUserId,
      username: username,
      email: email,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
      fcmToken: await NotificationService().getToken(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toMap());

    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last seen and FCM token
    final fcmToken = await NotificationService().getToken();
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userCredential.user!.uid)
        .update({
          'lastSeen': DateTime.now().toIso8601String(),
          'isOnline': true,
          'fcmToken': fcmToken,
        });

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userCredential.user!.uid)
        .get();

    return UserModel.fromMap(userDoc.data()!);
  }

  Future<void> logout() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUser.uid)
          .update({
            'lastSeen': DateTime.now().toIso8601String(),
            'isOnline': false,
          });
    }
    await _auth.signOut();
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'fcmToken': token});
  }

  Future<UserModel> updateProfile({
    required String userId,
    required String username,
    required String bio,
    String? photoUrl,
  }) async {
    final updates = {
      'username': username,
      'usernameLowercase': username.toLowerCase(),
      'bio': bio,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update(updates);

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    return UserModel.fromMap(userDoc.data()!);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> isEmailTaken(String email) async {
    final result = await _firestore
        .collection(AppConstants.usersCollection)
        .where('email', isEqualTo: email)
        .get();
    return result.docs.isNotEmpty;
  }

  Future<bool> isUsernameTaken(String username) async {
    final result = await _firestore
        .collection(AppConstants.usersCollection)
        .where('username', isEqualTo: username)
        .get();
    return result.docs.isNotEmpty;
  }
}
