import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> watchAllNotifications() {
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> broadcastNotification({
    required String title,
    required String body,
    String type = 'promo',
  }) async {
    // Get all users and create a notification for each
    final users = await _firestore.collection('users').get();
    final batch = _firestore.batch();
    for (final user in users.docs) {
      final ref = _firestore.collection('notifications').doc();
      batch.set(ref, {
        'userId': user.id,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
