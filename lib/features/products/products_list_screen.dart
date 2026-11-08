import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final _service = ProductService();
  final _reviewService = AdminReviewService();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Products',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage catalog, variants, stock and images',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('ADD PRODUCT'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: StreamBuilder<QuerySnapshot>(
              stream: _reviewService.watchAllReviews(),
              builder: (context, reviewSnap) {
                final reviewDocs = reviewSnap.data?.docs ?? [];
                // Compute stats per product
                final Map<String, List<double>> ratingsByProduct = {};
                for (final rd in reviewDocs) {
                  final d = rd.data() as Map<String, dynamic>;
                  final pid = d['productId']?.toString();
                  if (pid == null || pid.isEmpty) continue;
                  final r = d['rating'];
                  final rating = r is num ? r.toDouble() : double.tryParse(r?.toString() ?? '') ?? 0.0;
                  ratingsByProduct.putIfAbsent(pid, () => []).add(rating);
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _service.watchProducts(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load products: ${snap.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = snap.data!.docs;
                    if (_search.isNotEmpty) {
                      docs = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        return name.contains(_search);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products found.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 64,
                          ),
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 20,
                            columns: const [
                              DataColumn(
                                label: Text('Product', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Category', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Price', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Stock', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Rating', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Reviews', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Status', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                              DataColumn(
                                label: Text('Actions', style: TextStyle(color: AppColors.secondaryText)),
                              ),
                            ],
                            rows: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final variants = data['variants'] as List? ?? [];

                          int totalStock = 0;
                          for (var v in variants) {
                            if (v is Map) {
                              final s = v['stock'];
                              if (s is num) {
                                totalStock += s.toInt();
                              } else if (s != null) {
                                totalStock += int.tryParse(s.toString()) ?? 0;
                              }
                            }
                          }

                          final isActive = data['isActive'] is bool
                              ? data['isActive'] as bool
                              : true;
                          final images = data['images'] is List
                              ? (data['images'] as List)
                                    .where((e) => e != null)
                                    .map((e) => e.toString())
                                    .toList()
                              : <String>[];
                          final firstImage = images.isNotEmpty
                              ? images.first
                              : '';

                          final price = data['price'];
                          final priceText = price is num
                              ? price.toStringAsFixed(2)
                              : (double.tryParse(price?.toString() ?? '') ??
                                        0.0)
                                    .toStringAsFixed(2);

                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Row(
                                    children: [
                                      _ProductThumbnail(
                                        imagePath: firstImage,
                                        width: 44,
                                        height: 44,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              (data['name'] ?? 'Unnamed')
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.primaryText,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${variants.length} variant(s)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.tertiaryText,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    (data['categoryId'] ?? '-').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₱$priceText',
                                  style: const TextStyle(
                                    color: AppColors.primaryAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 110),
                                  child: Text(
                                    '$totalStock in stock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.secondaryText),
                                  ),
                                ),
                              ),
                              DataCell(
                                Builder(builder: (context) {
                                  final ratings = ratingsByProduct[doc.id] ?? [];
                                  if (ratings.isEmpty) {
                                    return const Text('—', style: TextStyle(color: AppColors.tertiaryText));
                                  }
                                  final avg = ratings.reduce((a, b) => a + b) / ratings.length;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: AppColors.warning, size: 14),
                                      const SizedBox(width: 4),
                                      Text(avg.toStringAsFixed(1), style: const TextStyle(color: AppColors.primaryText)),
                                    ],
                                  );
                                }),
                              ),
                              DataCell(
                                Text(
                                  '${(ratingsByProduct[doc.id] ?? []).length}',
                                  style: const TextStyle(color: AppColors.secondaryText),
                                ),
                              ),
                              DataCell(
                                Switch(
                                  value: isActive,
                                  onChanged: (_) => _service.toggleActive(doc.id, isActive),
                                  activeTrackColor: AppColors.primaryAccent,
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 96,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: 'Edit',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.secondaryText,
                                          size: 18,
                                        ),
                                        onPressed: () => context.go(
                                          '/products/edit/${doc.id}',
                                        ),
                                      ),
                                      IconButton(
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        tooltip: 'Delete',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _confirmDelete(context, doc.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondarySurface,
        title: const Text(
          'Delete Product',
          style: TextStyle(color: AppColors.primaryText),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              _service.deleteProduct(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail for product images.
/// - `data:image/...;base64,...` -> Image.memory (Firestore-stored photo)
/// - `assets/...` -> Image.asset (bundled local assets; no Storage billing)
/// - `http(s)://...` -> Image.network
class _ProductThumbnail extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;

  const _ProductThumbnail({
    required this.imagePath,
    this.width = 48,
    this.height = 48,
  });

  Widget _buildImage(String path) {
    if (path.startsWith('data:image/')) {
      try {
        final commaIndex = path.indexOf(',');
        if (commaIndex >= 0 && commaIndex < path.length - 1) {
          final bytes = base64Decode(path.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          );
        }
      } catch (e) {
        debugPrint('THUMBNAIL DATA URL ERROR: $e');
      }
      return _fallback();
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('THUMBNAIL ASSET ERROR: $error for $path');
          return _fallback();
        },
      );
    }

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('THUMBNAIL NETWORK ERROR: $error for $path');
          return _fallback();
        },
      );
    }

    return _fallback();
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath.trim();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: path.isEmpty ? _fallback() : _buildImage(path),
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.tertiaryText,
        size: 20,
      ),
    );
  }
}
