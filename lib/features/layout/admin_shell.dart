import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/products')) {
      _index = 1;
    } else if (location.startsWith('/orders')) {
      _index = 2;
    } else if (location.startsWith('/reviews')) {
      _index = 3;
    } else if (location.startsWith('/notifications')) {
      _index = 4;
    } else if (location.startsWith('/support')) {
      _index = 5;
    } else {
      _index = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: AppColors.secondarySurface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.primaryAccent, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppConstants.appName.toUpperCase(), style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
                            const Text('Web Admin', style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', selected: _index == 0, onTap: () => context.go('/dashboard')),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'Products', selected: _index == 1, onTap: () => context.go('/products')),
                _NavItem(icon: Icons.receipt_long_outlined, label: 'Orders', selected: _index == 2, onTap: () => context.go('/orders')),
                _NavItem(icon: Icons.star_outline, label: 'Reviews', selected: _index == 3, onTap: () => context.go('/reviews')),
                _NavItem(icon: Icons.notifications_outlined, label: 'Notifications', selected: _index == 4, onTap: () => context.go('/notifications')),
                _NavItem(icon: Icons.support_agent_outlined, label: 'Customer Support', selected: _index == 5, onTap: () => context.go('/support')),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ascended Athletics • Admin', style: TextStyle(color: AppColors.tertiaryText, fontSize: 11)),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBackground,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_getTitle(location), style: const TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.w600)),
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined, color: AppColors.secondaryText),
                          SizedBox(width: 8),
                          Text('Administrator', style: TextStyle(color: AppColors.secondaryText)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: Padding(padding: const EdgeInsets.all(32), child: widget.child)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(String location) {
    if (location.startsWith('/products')) return 'Product Management';
    if (location.startsWith('/orders')) return 'Order Management';
    if (location.startsWith('/reviews')) return 'Reviews Management';
    if (location.startsWith('/notifications')) return 'Notifications';
    if (location.startsWith('/support')) return 'Customer Support';
    return 'Dashboard';
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected ? AppColors.primaryAccent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppColors.primaryAccent : AppColors.secondaryText, size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: selected ? AppColors.primaryText : AppColors.secondaryText, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
