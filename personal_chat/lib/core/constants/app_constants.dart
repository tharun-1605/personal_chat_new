class AppConstants {
  static const String appName = 'Personal Chat';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String messagesCollection = 'messages';
  static const String chatsCollection = 'chats';
  static const String contactsCollection = 'contacts';

  // User ID Prefix
  static const String userIdPrefix = 'PC-';

  // Encryption Key Length
  static const int encryptionKeyLength = 32;
  static const int ivLength = 16;

  // Pagination
  static const int messagesLimit = 50;
  static const int searchResultsLimit = 20;
}
