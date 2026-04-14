import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_bloc.dart';
import '../websocket/ws_service.dart';
import '../../injection.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/my_ppe/presentation/my_ppe_screen.dart';
import '../../features/picking_slips/presentation/slip_list_screen.dart';
import '../../features/picking_slips/presentation/slip_detail_screen.dart';
import '../../features/picking_slips/presentation/create_slip_screen.dart';
import '../../features/scanning/presentation/scan_screen.dart';
import '../../features/scanning/presentation/issue_confirm_screen.dart';
import '../../features/approvals/presentation/approvals_screen.dart';
import '../../features/compliance/presentation/compliance_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_audit_log_screen.dart';
import '../../features/admin/presentation/admin_inventory_screen.dart';
import '../../features/admin/presentation/admin_ppe_catalogue_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/safety/presentation/department_ppe_standards_screen.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          // Employee
          GoRoute(path: '/my-ppe', builder: (_, __) => const MyPpeScreen()),
          GoRoute(
              path: '/my-ppe/slips',
              builder: (_, __) => const SlipListScreen()),
          GoRoute(
              path: '/my-ppe/slips/create',
              builder: (_, state) => CreateSlipScreen(
                    initialRequestType: state.uri.queryParameters['type'],
                  )),
          GoRoute(
            path: '/my-ppe/slips/:id',
            builder: (_, state) =>
                SlipDetailScreen(slipId: state.pathParameters['id']!),
          ),

          // Store officer
          GoRoute(path: '/store/scan', builder: (_, __) => const ScanScreen()),
          GoRoute(
            path: '/store/issue-confirm',
            builder: (_, state) => IssueConfirmScreen(
                slipData: state.extra as Map<String, dynamic>),
          ),

          // Manager / Safety
          GoRoute(
              path: '/approvals',
              builder: (_, state) => ApprovalsScreen(
                    initialApprovalId: state.uri.queryParameters['focus'],
                  )),
          GoRoute(
              path: '/compliance',
              builder: (_, __) => const ComplianceScreen()),
          GoRoute(
            path: '/safety/standards',
            builder: (_, __) => const DepartmentPpeStandardsScreen(),
          ),

          // Admin
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(
              path: '/admin/catalogue',
              builder: (_, __) => const AdminPpeCatalogueScreen()),
          GoRoute(
              path: '/admin/inventory',
              builder: (_, __) => const AdminInventoryScreen()),
          GoRoute(
              path: '/admin/audit',
              builder: (_, __) => const AdminAuditLogScreen()),

          // Shared
          GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = authBloc.state;
    final loc = state.matchedLocation;
    final isLogin = loc == '/login';

    if (auth is AuthLoading || auth is AuthInitial) return null;

    // Not logged in → go to login
    if (auth is AuthUnauthenticated || auth is AuthError) {
      return isLogin ? null : '/login';
    }

    if (auth is! AuthAuthenticated) {
      return null;
    }

    // On login page → go to role home
    if (isLogin) return _homeForRole(auth.primaryRole);

    // Shared routes accessible to all authenticated users
    if (loc == '/notifications' || loc == '/profile') return null;

    // Role-based guards — prevent wrong role landing on wrong section
    final role = auth.primaryRole;
    switch (role) {
      case 'Admin':
        if (loc.startsWith('/admin') ||
            loc.startsWith('/approvals') ||
            loc.startsWith('/compliance')) {
          return null;
        }
        return '/admin';

      case 'Manager':
        if (loc.startsWith('/compliance') || loc.startsWith('/approvals')) {
          return null;
        }
        return '/compliance';

      case 'Safety':
        if (loc.startsWith('/safety/standards') ||
            loc.startsWith('/approvals') ||
            loc.startsWith('/compliance')) {
          return null;
        }
        return '/safety/standards';

      case 'Store':
        if (loc.startsWith('/store')) return null;
        return '/store/scan';

      default: // Employee
        if (loc.startsWith('/my-ppe')) return null;
        return '/my-ppe';
    }
  }

  String _homeForRole(String role) {
    switch (role) {
      case 'Admin':
        return '/admin';
      case 'Manager':
        return '/compliance';
      case 'Safety':
        return '/safety/standards';
      case 'Store':
        return '/store/scan';
      default:
        return '/my-ppe';
    }
  }
}

// ─── Shell ───────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _AppShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      return child;
    }

    final items = _navItemsForRole(auth.primaryRole);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(location, items),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          final target = items[i].route;
          if (location != target) context.go(target);
        },
        destinations: items.map((item) {
          final isAlerts = item.route == '/notifications';
          return NavigationDestination(
            icon: isAlerts
                ? ValueListenableBuilder<int>(
                    valueListenable: sl<WsService>().unreadPushCount,
                    builder: (_, count, __) => Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: Icon(item.icon),
                    ),
                  )
                : Icon(item.icon),
            selectedIcon: isAlerts
                ? ValueListenableBuilder<int>(
                    valueListenable: sl<WsService>().unreadPushCount,
                    builder: (_, count, __) => Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: Icon(item.selectedIcon),
                    ),
                  )
                : Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  int _selectedIndex(String location, List<_NavItem> items) {
    // Exact match
    for (int i = 0; i < items.length; i++) {
      if (location == items[i].route) return i;
    }
    // Prefix match (nested routes highlight parent tab)
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route) && items[i].route.length > 1) {
        return i;
      }
    }
    return 0;
  }

  List<_NavItem> _navItemsForRole(String role) {
    switch (role) {
      case 'Admin':
        return [
          const _NavItem(
              Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', '/admin'),
          const _NavItem(
              Icons.people_outline, Icons.people, 'Compliance', '/compliance'),
          const _NavItem(Icons.fact_check_outlined, Icons.fact_check,
              'Approvals', '/approvals'),
          const _NavItem(Icons.inventory_2_outlined, Icons.inventory_2,
              'Inventory', '/admin/inventory'),
          const _NavItem(Icons.notifications_outlined, Icons.notifications,
              'Alerts', '/notifications'),
          const _NavItem(
              Icons.person_outline, Icons.person, 'Profile', '/profile'),
        ];
      case 'Manager':
        return [
          const _NavItem(
              Icons.people_outline, Icons.people, 'Team', '/compliance'),
          const _NavItem(Icons.fact_check_outlined, Icons.fact_check,
              'Approvals', '/approvals'),
          const _NavItem(Icons.notifications_outlined, Icons.notifications,
              'Alerts', '/notifications'),
          const _NavItem(
              Icons.person_outline, Icons.person, 'Profile', '/profile'),
        ];
      case 'Safety':
        return [
          const _NavItem(Icons.tune_outlined, Icons.tune, 'Standards',
              '/safety/standards'),
          const _NavItem(Icons.fact_check_outlined, Icons.fact_check,
              'Approvals', '/approvals'),
          const _NavItem(
              Icons.people_outline, Icons.people, 'Compliance', '/compliance'),
          const _NavItem(Icons.notifications_outlined, Icons.notifications,
              'Alerts', '/notifications'),
          const _NavItem(
              Icons.person_outline, Icons.person, 'Profile', '/profile'),
        ];
      case 'Store':
        return [
          const _NavItem(Icons.qr_code_scanner, Icons.qr_code_scanner, 'Scan',
              '/store/scan'),
          const _NavItem(Icons.notifications_outlined, Icons.notifications,
              'Alerts', '/notifications'),
          const _NavItem(
              Icons.person_outline, Icons.person, 'Profile', '/profile'),
        ];
      default: // Employee
        return [
          const _NavItem(
              Icons.security_outlined, Icons.security, 'My PPE', '/my-ppe'),
          const _NavItem(Icons.list_alt_outlined, Icons.list_alt, 'Requests',
              '/my-ppe/slips'),
          const _NavItem(Icons.notifications_outlined, Icons.notifications,
              'Alerts', '/notifications'),
          const _NavItem(
              Icons.person_outline, Icons.person, 'Profile', '/profile'),
        ];
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.selectedIcon, this.label, this.route);
}

// ─── GoRouter stream helper ───────────────────────────────────────────────────

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    (_subscription as dynamic).cancel();
    super.dispose();
  }
}
