import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Statuses offered by the admin fulfillment workflow.
const List<String> kOrderStatuses = [
  'Pending',
  'Processing',
  'Shipped',
  'Completed',
  'Cancelled',
];

/// Trusted admin-side order operations.
///
/// Completing an order deducts stock exactly once. Deduction is guarded by the
/// `inventoryDeducted` flag stored on the order, so toggling the status back
/// and forth (Completed -> Shipped -> Completed) will not deduct twice.
class AdminOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrder(String orderId) {
    return _orders.doc(orderId).snapshots();
  }

  /// Updates an order status inside a transaction.
  ///
  /// When [newStatus] is `Completed` and the order has not deducted inventory
  /// yet, every product/variant in the order has its stock reduced. All product
  /// reads happen before the first write to satisfy Firestore transaction
  /// requirements.
  Future<void> updateStatus({
    required String orderId,
    required String newStatus,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _orders.doc(orderId);
        final orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
          throw Exception('Order not found.');
        }

        final order = orderSnap.data() ?? <String, dynamic>{};
        // `false` = stock not deducted yet (new orders).
        // `true` = already deducted by a previous completion.
        // missing = legacy order that reserved stock at checkout, so treat it
        // as already deducted to avoid deducting twice.
        final inventoryFlag = order['inventoryDeducted'];
        final alreadyDeducted = inventoryFlag != false;
        final shouldDeduct = newStatus == 'Completed' && !alreadyDeducted;

        final productUpdates = <String, Map<String, dynamic>>{};

        if (shouldDeduct) {
          final rawItems = order['items'];
          final items = <Map<String, dynamic>>[];
          if (rawItems is List) {
            for (final rawItem in rawItems) {
              if (rawItem is Map) {
                items.add(Map<String, dynamic>.from(rawItem));
              }
            }
          }

          final productIds = items
              .map((item) => item['productId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

          // ===== PHASE 1: READ every product first =====
          final productSnaps =
              <String, DocumentSnapshot<Map<String, dynamic>>>{};
          for (final productId in productIds) {
            productSnaps[productId] = await transaction.get(
              _products.doc(productId),
            );
          }

          // ===== Build the writes =====
          for (final productId in productIds) {
            final snap = productSnaps[productId];
            if (snap == null || !snap.exists) {
              debugPrint(
                'AdminOrderService: product $productId no longer exists; '
                'skipping stock deduction for it.',
              );
              continue;
            }

            final product = snap.data();
            if (product == null) continue;

            final productItems = items
                .where(
                  (item) => (item['productId']?.toString() ?? '') == productId,
                )
                .toList();

            final rawVariants = product['variants'];

            if (rawVariants is List) {
              final deltas = <int, int>{};
              for (final item in productItems) {
                final quantity = _quantityOf(item);
                if (quantity <= 0) continue;
                final index = _listVariantIndex(rawVariants, item);
                if (index == null) continue;
                deltas[index] = (deltas[index] ?? 0) + quantity;
              }

              final newVariants = <dynamic>[];
              for (var i = 0; i < rawVariants.length; i++) {
                final rawVariant = rawVariants[i];
                final variant = rawVariant is Map
                    ? Map<String, dynamic>.from(rawVariant)
                    : <String, dynamic>{};
                final stock = (variant['stock'] as num?)?.toInt() ?? 0;
                variant['stock'] = math.max(0, stock - (deltas[i] ?? 0));
                newVariants.add(variant);
              }

              productUpdates[productId] = {
                'variants': newVariants,
                'updatedAt': FieldValue.serverTimestamp(),
              };
            } else if (rawVariants is Map) {
              final newVariants = Map<String, dynamic>.from(rawVariants);
              final deltas = <String, int>{};
              for (final item in productItems) {
                final quantity = _quantityOf(item);
                if (quantity <= 0) continue;
                final key = _mapVariantKey(newVariants, item);
                if (key == null) continue;
                deltas[key] = (deltas[key] ?? 0) + quantity;
              }

              deltas.forEach((key, quantity) {
                final rawVariant = newVariants[key];
                final variant = rawVariant is Map
                    ? Map<String, dynamic>.from(rawVariant)
                    : <String, dynamic>{};
                final stock = (variant['stock'] as num?)?.toInt() ?? 0;
                variant['stock'] = math.max(0, stock - quantity);
                newVariants[key] = variant;
              });

              productUpdates[productId] = {
                'variants': newVariants,
                'updatedAt': FieldValue.serverTimestamp(),
              };
            } else if (product['stock'] is num) {
              final totalQuantity = productItems.fold<int>(
                0,
                (total, item) => total + _quantityOf(item),
              );
              final stock = (product['stock'] as num).toInt();
              productUpdates[productId] = {
                'stock': math.max(0, stock - totalQuantity),
                'updatedAt': FieldValue.serverTimestamp(),
              };
            } else {
              debugPrint(
                'AdminOrderService: product $productId has no stock field; '
                'skipping stock deduction for it.',
              );
            }
          }

          // ===== PHASE 2: WRITE =====
          productUpdates.forEach((productId, update) {
            transaction.update(_products.doc(productId), update);
          });
        }

        transaction.update(orderRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          if (shouldDeduct) 'inventoryDeducted': true,
          if (shouldDeduct) 'inventoryDeductedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error, stack) {
      debugPrint(
        'AdminOrderService.updateStatus: FirebaseException '
        'code=${error.code} message=${error.message}\n$stack',
      );
      throw Exception(_friendlyError(error));
    } catch (error, stack) {
      debugPrint('AdminOrderService.updateStatus: error $error\n$stack');
      rethrow;
    }
  }

  static int _quantityOf(Map<String, dynamic> item) =>
      ((item['quantity'] as num?)?.toInt() ?? 0).clamp(0, 1000000);

  static int? _listVariantIndex(
    List<dynamic> variants,
    Map<String, dynamic> item,
  ) {
    final rawVariantId = item['variantId']?.toString() ?? '';
    final parsedIndex = int.tryParse(rawVariantId.replaceFirst('var_', ''));
    if (parsedIndex != null &&
        parsedIndex >= 0 &&
        parsedIndex < variants.length) {
      return parsedIndex;
    }

    final size = item['selectedSize']?.toString();
    final color = item['selectedColor']?.toString();
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      if (variant is! Map) continue;
      if (variant['size']?.toString() == size &&
          variant['color']?.toString() == color) {
        return i;
      }
    }
    return null;
  }

  static String? _mapVariantKey(
    Map<String, dynamic> variants,
    Map<String, dynamic> item,
  ) {
    final rawVariantId = item['variantId']?.toString() ?? '';
    if (rawVariantId.isNotEmpty && variants.containsKey(rawVariantId)) {
      return rawVariantId;
    }

    final size = item['selectedSize']?.toString();
    final color = item['selectedColor']?.toString();
    for (final entry in variants.entries) {
      final variant = entry.value;
      if (variant is! Map) continue;
      if (variant['size']?.toString() == size &&
          variant['color']?.toString() == color) {
        return entry.key;
      }
    }
    return null;
  }

  static String _friendlyError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to update this order.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Network error while updating the order. Please try again.';
      case 'aborted':
        return 'The order was changed by another session. Please retry.';
      default:
        return 'Could not update the order (${error.code}). '
            '${error.message ?? 'Please try again.'}';
    }
  }
}
