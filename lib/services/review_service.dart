import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> watchAllReviews() {
    return _firestore
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> watchProductReviews(String productId) {
    return _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .snapshots();
  }

  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection('reviews').doc(reviewId).delete();
  }

  /// Moderates a review: `true` hides it from customers, `false` restores it.
  Future<void> setHidden(String reviewId, bool hidden) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'isHidden': hidden,
    });
  }

  /// Live map of `productId -> product name` used to enrich the reviews table.
  Stream<Map<String, String>> watchProductNames() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      final names = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString().trim() ?? '';
        names[doc.id] = name.isEmpty ? 'Unknown product' : name;
      }
      return names;
    });
  }

  Future<Map<String, dynamic>> getReviewStatsForProduct(String productId) async {
    final snap = await _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .get();
    if (snap.docs.isEmpty) return {'average': 0.0, 'count': 0};
    double sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final r = data['rating'];
      if (r is num) sum += r.toDouble();
    }
    return {
      'average': sum / snap.docs.length,
      'count': snap.docs.length,
    };
  }
}
