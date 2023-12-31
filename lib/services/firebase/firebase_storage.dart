/*
This class defines all the possible read/write locations from the Firestore database.
In future, any new path can be added here.
This class work together with FirestoreService and FirestoreDatabase.
 */

import 'package:butler/services/firebase/firebase_storage_service.dart';

class FirebaseFileStorage {
  final _firebaseStorageService = FirebaseStorageService.instance;
  FirebaseFileStorage();

  Future<String?> getDownloadUrlAndFileName(String filePath) =>
      _firebaseStorageService.getDownloadUrlAndFileNameService(filePath);
}
