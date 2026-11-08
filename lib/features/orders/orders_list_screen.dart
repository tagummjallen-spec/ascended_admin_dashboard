import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _filter = 'All';

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
                        (d) =>
                            (d.data() as Map<String, dynamic>)['status'] ==
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
                      final status = data['status'] ?? 'Pending';
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
                            IconButton(
                              icon: const Icon(
                                Icons.visibility_outlined,
                                color: AppColors.primaryAccent,
                              ),
                              onPressed: () => context.go('/orders/${doc.id}'),
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
