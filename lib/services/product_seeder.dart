import 'package:cloud_firestore/cloud_firestore.dart';

class ProductSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> seedCatalog() async {
    final products = [
      {
        'name': 'Ascended Pro Runner',
        'description': 'Lightweight performance running shoe with responsive cushioning built for sprints and conditioning.',
        'price': 89.99,
        'categoryId': 'Footwear',
        'disciplines': ['Fitness', 'Boxing'],
        'images': ['assets/images/products/shoes-white-runner.png'],
        'isActive': true,
        'variants': [
          {'size': '7', 'color': 'White', 'stock': 12},
          {'size': '8', 'color': 'White', 'stock': 18},
          {'size': '9', 'color': 'White', 'stock': 15},
          {'size': '10', 'color': 'White', 'stock': 10},
          {'size': '11', 'color': 'White', 'stock': 6},
        ],
      },
      {
        'name': 'Ascended Chunky Trainer',
        'description': 'Bold, supportive training shoe with extra grip for gym circuits and cross-training.',
        'price': 94.99,
        'categoryId': 'Footwear',
        'disciplines': ['Fitness', 'MMA'],
        'images': ['assets/images/products/shoes-white-chunky.png'],
        'isActive': true,
        'variants': [
          {'size': '8', 'color': 'White/Black', 'stock': 14},
          {'size': '9', 'color': 'White/Black', 'stock': 16},
          {'size': '10', 'color': 'White/Black', 'stock': 12},
          {'size': '11', 'color': 'White/Black', 'stock': 8},
        ],
      },
      {
        'name': 'Ascended Black Training Tee',
        'description': 'Moisture-wicking performance tee with reinforced seams for hard training sessions.',
        'price': 34.99,
        'categoryId': 'Tops',
        'disciplines': ['MMA', 'BJJ', 'Boxing', 'Fitness'],
        'images': ['assets/images/products/shirt-black.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 20},
          {'size': 'M', 'color': 'Black', 'stock': 28},
          {'size': 'L', 'color': 'Black', 'stock': 24},
          {'size': 'XL', 'color': 'Black', 'stock': 16},
          {'size': 'XXL', 'color': 'Black', 'stock': 10},
        ],
      },
      {
        'name': 'Ascended Black Tank',
        'description': 'Sleeveless tank built for mobility and breathability during high-intensity training.',
        'price': 29.99,
        'categoryId': 'Tops',
        'disciplines': ['MMA', 'Boxing', 'Fitness'],
        'images': ['assets/images/products/tank-top-black.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 18},
          {'size': 'M', 'color': 'Black', 'stock': 26},
          {'size': 'L', 'color': 'Black', 'stock': 22},
          {'size': 'XL', 'color': 'Black', 'stock': 14},
        ],
      },
      {
        'name': 'Ascended Black Track Pants',
        'description': 'Tapered track pants with stretch fabric for warmups, cooldowns, and everyday wear.',
        'price': 49.99,
        'categoryId': 'Bottoms',
        'disciplines': ['MMA', 'BJJ', 'Boxing', 'Fitness'],
        'images': ['assets/images/products/track-pants-black.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 16},
          {'size': 'M', 'color': 'Black', 'stock': 24},
          {'size': 'L', 'color': 'Black', 'stock': 20},
          {'size': 'XL', 'color': 'Black', 'stock': 14},
          {'size': 'XXL', 'color': 'Black', 'stock': 8},
        ],
      },
      {
        'name': 'Ascended Black Jersey',
        'description': 'Athletic jersey with bold detailing for training and competition day.',
        'price': 59.99,
        'categoryId': 'Tops',
        'disciplines': ['MMA', 'BJJ'],
        'images': ['assets/images/products/jersey-black.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 12},
          {'size': 'M', 'color': 'Black', 'stock': 18},
          {'size': 'L', 'color': 'Black', 'stock': 16},
          {'size': 'XL', 'color': 'Black', 'stock': 10},
        ],
      },
      {
        'name': 'Ascended Rashguard Short Sleeve',
        'description': 'Compression short-sleeve rashguard for grappling with moisture control and durability.',
        'price': 54.99,
        'categoryId': 'Uniforms',
        'disciplines': ['BJJ', 'MMA'],
        'images': ['assets/images/products/rashguard-short.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 14},
          {'size': 'M', 'color': 'Black', 'stock': 20},
          {'size': 'L', 'color': 'Black', 'stock': 18},
          {'size': 'XL', 'color': 'Black', 'stock': 12},
        ],
      },
      {
        'name': 'Ascended Duo Tee Set',
        'description': 'Two-pack of training tees for value and versatility across any session.',
        'price': 49.99,
        'categoryId': 'Tops',
        'disciplines': ['Fitness', 'MMA', 'Boxing'],
        'images': ['assets/images/products/shirts-duo.png'],
        'isActive': true,
        'variants': [
          {'size': 'M', 'color': 'Black', 'stock': 16},
          {'size': 'L', 'color': 'Black', 'stock': 16},
          {'size': 'XL', 'color': 'Black', 'stock': 12},
        ],
      },
      {
        'name': 'Ascended Tapered Track Pants (Model Fit)',
        'description': 'Premium tapered track pants with a sleek silhouette for gym and street.',
        'price': 54.99,
        'categoryId': 'Bottoms',
        'disciplines': ['Fitness', 'Boxing'],
        'images': ['assets/images/products/track-pants-model.png'],
        'isActive': true,
        'variants': [
          {'size': 'S', 'color': 'Black', 'stock': 10},
          {'size': 'M', 'color': 'Black', 'stock': 18},
          {'size': 'L', 'color': 'Black', 'stock': 16},
          {'size': 'XL', 'color': 'Black', 'stock': 12},
        ],
      },
    ];

    final batch = _firestore.batch();
    for (final product in products) {
      final doc = _firestore.collection('products').doc();
      final data = Map<String, dynamic>.from(product);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(doc, data);
    }

    await batch.commit();
    return products.length;
  }
}
