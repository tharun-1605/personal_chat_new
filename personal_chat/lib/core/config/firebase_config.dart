import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';

class FirebaseConfig {
  static firebase_auth.FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseStorage? _storage;

  static Future<void> initialize() async {
    await firebase_core.Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _auth = firebase_auth.FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;

    // Set Firestore settings
    _firestore!.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static firebase_auth.FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception(
        'Firebase not initialized. Call FirebaseConfig.initialize() first.',
      );
    }
    return _auth!;
  }

  static FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception(
        'Firebase not initialized. Call FirebaseConfig.initialize() first.',
      );
    }
    return _firestore!;
  }

  static FirebaseStorage get storage {
    if (_storage == null) {
      throw Exception(
        'Firebase not initialized. Call FirebaseConfig.initialize() first.',
      );
    }
    return _storage!;
  }

  static firebase_auth.User? get currentUser => _auth?.currentUser;

  static Stream<firebase_auth.User?> get authStateChanges =>
      _auth!.authStateChanges();
}
