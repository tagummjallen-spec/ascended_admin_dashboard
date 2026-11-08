import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../services/review_service.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _service = AdminReviewService();
  int _ratingFilter = 0; // 0 = all

  static const double _minTableWidth = 1100;

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      date = DateTime.tryParse(value.toString());
    }
    if (date == null) return '—';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'View, verify and moderate customer reviews',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 20),
        Row(
          children: [0, 5, 4, 3, 2, 1].map((r) {
            final label = r == 0 ? 'All' : '$r★';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _ratingFilter == r,
                onSelected: (_) => setState(() => _ratingFilter = r),
                selectedColor: AppColors.primaryAccent,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<Map<String, String>>(
            stream: _service.watchProductNames(),
            builder: (context, productSnap) {
              final productNames = productSnap.data ?? const <String, String>{};

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.watchAllReviews(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading reviews: ${snap.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = snap.data!.docs;
                    if (_ratingFilter != 0) {
                      docs = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final r = data['rating'];
                        final rating = r is num ? r.toInt() : 0;
                        return rating == _ratingFilter;
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No reviews found.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final tableWidth =
                            constraints.maxWidth < _minTableWidth
                                ? _minTableWidth
                                : constraints.maxWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              children: [
                                const _ReviewsTableHeader(),
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: docs.length,
                                    separatorBuilder: (_, _) => const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                    itemBuilder: (context, i) {
                                      final doc = docs[i];
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final productId =
                                          data['productId']?.toString() ?? '';
                                      final hidden =
                                          data['isHidden'] == true;

                                      return _ReviewRow(
                                        productName: productNames[productId] ??
                                            (productId.isEmpty
                                                ? 'Unknown product'
                                                : productId),
                                        userName: data['userName']
                                                ?.toString() ??
                                            'Anonymous',
                                        userId: data['userId']?.toString() ??
                                            '—',
                                        rating:
                                            (data['rating'] as num?)
                                                    ?.toDouble() ??
                                                0.0,
                                        comment:
                                            data['comment']?.toString() ?? '',
                                        date: _formatDate(data['createdAt']),
                                        hidden: hidden,
                                        onToggleHidden: () {
                                          _service.setHidden(doc.id, !hidden);
                                        },
                                        onDelete: () =>
                                            _confirmDelete(context, doc.id),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondarySurface,
        title: const Text(
          'Delete Review',
          style: TextStyle(color: AppColors.primaryText),
        ),
        content: const Text(
          'This will permanently remove the review.',
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
              _service.deleteReview(reviewId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsTableHeader extends StatelessWidget {
  const _ReviewsTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: const Row(
        children: [
          _HeaderCell('PRODUCT', flex: 3),
          _HeaderCell('CUSTOMER', flex: 2),
          _HeaderCell('RATING', flex: 2),
          _HeaderCell('COMMENT', flex: 3),
          _HeaderCell('DATE', flex: 2),
          _HeaderCell('ACTIONS', flex: 2),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;

  const _HeaderCell(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String productName;
  final String userName;
  final String userId;
  final double rating;
  final String comment;
  final String date;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;

  const _ReviewRow({
    required this.productName,
    required this.userName,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.date,
    required this.hidden,
    required this.onToggleHidden,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: hidden
          ? AppColors.primaryBackground.withValues(alpha: 0.35)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hidden
                        ? AppColors.tertiaryText
                        : AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (hidden ? AppColors.warning : AppColors.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hidden ? 'HIDDEN' : 'VISIBLE',
                    style: TextStyle(
                      color:
                          hidden ? AppColors.warning : AppColors.success,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userId,
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
          Expanded(
            flex: 2,
            child: _StarRating(rating: rating),
          ),
          Expanded(
            flex: 3,
            child: Text(
              comment.trim().isEmpty ? '—' : comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: const TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: hidden
                      ? 'Moderate: show this review to customers'
                      : 'Moderate: hide this review from customers',
                  child: OutlinedButton.icon(
                    onPressed: onToggleHidden,
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 14,
                    ),
                    label: Text(
                      hidden ? 'SHOW' : 'HIDE',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          hidden ? AppColors.success : AppColors.secondaryText,
                      side: BorderSide(
                        color: hidden
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Delete review',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < filled;
        return Icon(
          active ? Icons.star : Icons.star_border,
          size: 16,
          color: active ? AppColors.warning : AppColors.borderLight,
        );
      }),
    );
  }
}
