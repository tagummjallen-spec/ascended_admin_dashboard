import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/layout/admin_shell.dart';
import '../../features/auth/admin_login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/products/products_list_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/orders/orders_list_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/reviews/reviews_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/support/support_chats_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: 'edit/:productId',
                builder: (context, state) => ProductFormScreen(
                  productId: state.pathParameters['productId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersListScreen(),
            routes: [
              GoRoute(
                path: ':orderId',
                builder: (context, state) => OrderDetailScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const AdminNotificationsScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => const SupportChatsScreen(),
          ),
        ],
      ),
    ],
  );
});
