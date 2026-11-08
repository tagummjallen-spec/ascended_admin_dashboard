import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Aggregated analytics used by the admin dashboard.
class AnalyticsData {
  final double totalRevenue;
  final int totalOrders;
  final int totalUsers;
  final int completedOrders;
  final int pendingOrders;
  final List<RevenuePoint> revenueTrend;
  final List<TopProduct> topProducts;

  const AnalyticsData({
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalUsers,
    required this.completedOrders,
    required this.pendingOrders,
    required this.revenueTrend,
    required this.topProducts,
  });
}

/// A single day in the revenue trend chart.
class RevenuePoint {
  final DateTime date;
  final double revenue;

  const RevenuePoint({required this.date, required this.revenue});
}

/// A product ranked by quantity sold across completed orders.
class TopProduct {
  final String productId;
  final String name;
  final int quantitySold;
  final double revenue;

  const TopProduct({
    required this.productId,
    required this.name,
    required this.quantitySold,
    required this.revenue,
  });
}

/// Reads orders/users and aggregates them client-side.
///
/// Client-side aggregation avoids composite indexes and keeps the dashboard in
/// sync in real time as orders change status.
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int trendDays;

  AnalyticsService({this.trendDays = 7});

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Combines the orders and users streams into one analytics snapshot.
  Stream<AnalyticsData> watchAnalytics() {
    late StreamController<AnalyticsData> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSub;
    QuerySnapshot<Map<String, dynamic>>? ordersSnap;
    QuerySnapshot<Map<String, dynamic>>? usersSnap;

    void emit() {
      if (ordersSnap == null || usersSnap == null) return;
      if (controller.isClosed) return;
      controller.add(_aggregate(ordersSnap!, usersSnap!));
    }

    controller = StreamController<AnalyticsData>(
      onListen: () {
        ordersSub = _orders.snapshots().listen(
          (snap) {
            ordersSnap = snap;
            emit();
          },
          onError: (Object error, StackTrace stack) {
            debugPrint('AnalyticsService: orders stream error $error');
            if (!controller.isClosed) controller.addError(error, stack);
          },
        );
        usersSub = _users.snapshots().listen(
          (snap) {
            usersSnap = snap;
            emit();
          },
          onError: (Object error, StackTrace stack) {
            debugPrint('AnalyticsService: users stream error $error');
            if (!controller.isClosed) controller.addError(error, stack);
          },
        );
      },
      onCancel: () async {
        await ordersSub?.cancel();
        await usersSub?.cancel();
      },
    );

    return controller.stream;
  }

  AnalyticsData _aggregate(
    QuerySnapshot<Map<String, dynamic>> ordersSnap,
    QuerySnapshot<Map<String, dynamic>> usersSnap,
  ) {
    double totalRevenue = 0;
    int completedOrders = 0;
    int pendingOrders = 0;

    // productId -> {name, quantity, revenue}
    final productTotals =
        <String, ({String name, int quantity, double revenue})>{};

    final completedDocs = <Map<String, dynamic>>[];

    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      final status = _statusOf(data);
      if (status == 'pending') pendingOrders++;
      if (!_isCompleted(status)) continue;

      completedOrders++;
      final orderTotal = _numberOf(data['total'], fallback: data['totalPrice']);
      totalRevenue += orderTotal;
      completedDocs.add(data);

      final items = data['items'];
      if (items is! List) continue;
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final productId = rawItem['productId']?.toString() ?? '';
        final name = rawItem['productName']?.toString().trim() ?? '';
        final quantity = _numberOf(rawItem['quantity']).round();
        if (productId.isEmpty || quantity <= 0) continue;

        final itemRevenue = _numberOf(
          rawItem['totalPrice'],
          fallback: _numberOf(rawItem['unitPrice']) * quantity,
        );
        final existing = productTotals[productId];
        productTotals[productId] = (
          name: existing == null || existing.name.isEmpty
              ? (name.isEmpty ? productId : name)
              : existing.name,
          quantity: (existing?.quantity ?? 0) + quantity,
          revenue: (existing?.revenue ?? 0) + itemRevenue,
        );
      }
    }

    final topProducts =
        productTotals.entries
            .map(
              (entry) => TopProduct(
                productId: entry.key,
                name: entry.value.name,
                quantitySold: entry.value.quantity,
                revenue: entry.value.revenue,
              ),
            )
            .toList()
          ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    return AnalyticsData(
      totalRevenue: totalRevenue,
      totalOrders: ordersSnap.docs.length,
      totalUsers: usersSnap.docs.length,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      revenueTrend: _buildTrend(completedDocs),
      topProducts: topProducts.take(5).toList(),
    );
  }

  List<RevenuePoint> _buildTrend(List<Map<String, dynamic>> completedOrders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final points = <RevenuePoint>[];

    for (var i = trendDays - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      double revenue = 0;

      for (final order in completedOrders) {
        final createdAt = _dateOf(order['createdAt']);
        if (createdAt == null) continue;
        if (createdAt.isBefore(day) || !createdAt.isBefore(nextDay)) continue;
        revenue += _numberOf(order['total'], fallback: order['totalPrice']);
      }

      points.add(RevenuePoint(date: day, revenue: revenue));
    }

    return points;
  }

  static bool _isCompleted(String status) =>
      status == 'completed' || status == 'delivered';

  static String _statusOf(Map<String, dynamic> data) =>
      (data['status']?.toString() ?? '').trim().toLowerCase();

  static double _numberOf(dynamic value, {dynamic fallback}) {
    final direct = _asDouble(value);
    if (direct != null) return direct;
    return _asDouble(fallback) ?? 0;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
