import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../services/order_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _service = AdminOrderService();
  bool _loading = false;
  String? _selectedStatus;

  Future<void> _applyStatus(String status) async {
    setState(() => _loading = true);
    try {
      await _service.updateStatus(orderId: widget.orderId, newStatus: status);
      if (!mounted) return;
      setState(() => _selectedStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Completed'
                ? 'Order completed. Inventory was deducted once.'
                : 'Order status updated to $status.',
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.watchOrder(widget.orderId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Could not load order: ${snap.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(
            child: Text(
              'Order not found',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final rawStatus = data['status']?.toString().trim() ?? '';
        final status = rawStatus.isEmpty ? 'Pending' : rawStatus;
        final items = data['items'] as List? ?? [];
        final shipping =
            (data['shippingAddress'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        // Missing flag = legacy order that already reserved stock at checkout.
        final inventoryDeducted = data['inventoryDeducted'] != false;

        final statusOptions = <String>[...kOrderStatuses];
        if (!statusOptions.contains(status)) statusOptions.add(status);
        final dropdownValue = _selectedStatus ?? status;
        final canUpdate = dropdownValue != status && !_loading;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/orders'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _Card(
                          title: 'Order Items',
                          child: Column(
                            children: items.map((item) {
                              final it = (item as Map).cast<String, dynamic>();
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${it['quantity']}x ${it['productName']} '
                                        '(${it['selectedSize']}/${it['selectedColor']})',
                                        style: const TextStyle(
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₱${(it['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          title: 'Shipping Information',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shipping['fullName']?.toString() ?? '',
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${shipping['street'] ?? ''}, '
                                '${shipping['city'] ?? ''}, '
                                '${shipping['province'] ?? ''} '
                                '${shipping['postalCode'] ?? ''}',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${shipping['phone'] ?? ''} • '
                                '${shipping['email'] ?? ''}',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _Card(
                          title: 'Order Summary',
                          child: Column(
                            children: [
                              _Row(
                                'Subtotal',
                                '₱${(data['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                              _Row(
                                'Shipping',
                                (data['shippingFee'] as num?) == 0
                                    ? 'FREE'
                                    : '₱${(data['shippingFee'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                              const Divider(color: AppColors.border),
                              _Row(
                                'Total',
                                '₱${(data['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                bold: true,
                              ),
                              const SizedBox(height: 8),
                              _Row(
                                'Payment Method',
                                data['paymentMethod']?.toString() ?? 'COD',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          title: 'Order Fulfillment',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Progress the order through fulfillment. '
                                'Completing the order deducts stock exactly once.',
                                style: TextStyle(
                                  color: AppColors.tertiaryText,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: dropdownValue,
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    icon: const Icon(
                                      Icons.expand_more,
                                      color: AppColors.secondaryText,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: statusOptions
                                        .map(
                                          (option) => DropdownMenuItem<String>(
                                            value: option,
                                            child: Row(
                                              children: [
                                                _StatusDot(status: option),
                                                const SizedBox(width: 10),
                                                Text(option),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _loading
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            setState(
                                              () => _selectedStatus = value,
                                            );
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: canUpdate
                                    ? () => _applyStatus(dropdownValue)
                                    : null,
                                child: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('UPDATE STATUS'),
                              ),
                              if (inventoryDeducted) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.success,
                                      size: 15,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Inventory already deducted for this order.',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.primaryText : AppColors.secondaryText,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: bold ? AppColors.primaryAccent : AppColors.primaryText,
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

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
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
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
