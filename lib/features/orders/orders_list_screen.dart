import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../services/order_service.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final _service = AdminOrderService();
  String _filter = 'All';
  String? _updatingOrderId;

  Future<void> _quickUpdateStatus(String orderId, String status) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await _service.updateStatus(orderId: orderId, newStatus: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order #${orderId.substring(0, 8).toUpperCase()} updated to '
            '$status.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'View all orders and update status',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 24),
        Row(
          children:
              [
                    'All',
                    'Pending',
                    'Processing',
                    'Shipped',
                    'Completed',
                    'Cancelled',
                  ]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                        selectedColor: AppColors.primaryAccent,
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data!.docs;
                if (_filter != 'All') {
                  docs = docs
                      .where(
                        (d) => _orderStatus(
                              d.data() as Map<String, dynamic>,
                            ) ==
                            _filter,
                      )
                      .toList();
                }
                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Order ID',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Customer',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Payment',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Date',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = _orderStatus(data);
                      final created = data['createdAt'] as Timestamp?;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '#${doc.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data['customerId']?.substring(0, 8) ?? '-',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₱${(data['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(
                                color: AppColors.primaryAccent,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data['paymentMethod'] ?? 'COD',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          DataCell(_StatusChip(status: status)),
                          DataCell(
                            Text(
                              created != null
                                  ? _formatDate(created.toDate())
                                  : '-',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'View order',
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    color: AppColors.primaryAccent,
                                  ),
                                  onPressed: () =>
                                      context.go('/orders/${doc.id}'),
                                ),
                                if (_updatingOrderId == doc.id)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else
                                  PopupMenuButton<String>(
                                    tooltip: 'Update status',
                                    enabled: _updatingOrderId == null,
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: AppColors.secondaryText,
                                    ),
                                    onSelected: (value) =>
                                        _quickUpdateStatus(doc.id, value),
                                    itemBuilder: (context) => kOrderStatuses
                                        .map(
                                          (option) => PopupMenuItem<String>(
                                            value: option,
                                            child: Row(
                                              children: [
                                                _StatusChip(status: option),
                                                if (option == status) ...[
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.check,
                                                    size: 15,
                                                    color:
                                                        AppColors.primaryAccent,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _orderStatus(Map<String, dynamic> data) {
    for (final key in const ['orderStatus', 'status']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Pending';
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case 'Processing':
        return AppColors.info;
      case 'Shipped':
        return AppColors.primaryAccent;
      case 'Approved':
        return AppColors.info;
      case 'Completed':
      case 'Delivered':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
