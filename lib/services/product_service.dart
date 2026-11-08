import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get products => _db.collection('products');

  Stream<QuerySnapshot> watchProducts() => products.orderBy('createdAt', descending: true).snapshots();

  Future<void> addProduct(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await products.add(data);
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await products.doc(id).update(data);
  }

  Future<void> deleteProduct(String id) async {
    await products.doc(id).delete();
  }

  Future<void> toggleActive(String id, bool current) async {
    await products.doc(id).update({'isActive': !current});
  }
}
