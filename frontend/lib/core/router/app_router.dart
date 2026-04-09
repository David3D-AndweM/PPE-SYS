import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_bloc.dart';
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

class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/my-ppe', builder: (_, __) => const MyPpeScreen()),
      GoRoute(path: '/my-ppe/slips', builder: (_, __) => const SlipListScreen()),
      GoRoute(path: '/my-ppe/slips/create', builder: (_, __) => const CreateSlipScreen()),
      GoRoute(
        path: '/my-ppe/slips/:id',
        builder: (_, state) => SlipDetailScreen(slipId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/store/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(
        path: '/store/issue-confirm',
        builder: (_, state) => IssueConfirmScreen(
          slipData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(path: '/approvals', builder: (_, __) => const ApprovalsScreen()),
      GoRoute(path: '/compliance', builder: (_, __) => const ComplianceScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = authBloc.state;
    final isLoginPage = state.matchedLocation == '/login';

    if (authState is AuthLoading || authState is AuthInitial) return null;

    if (authState is AuthUnauthenticated || authState is AuthError) {
      return isLoginPage ? null : '/login';
    }

    if (authState is AuthAuthenticated && isLoginPage) {
      return _homeForRole(authState.primaryRole);
    }

    return null;
  }

  String _homeForRole(String role) {
    switch (role) {
      case 'Admin': return '/admin';
      case 'Manager': return '/compliance';
      case 'Safety': return '/approvals';
      case 'Store': return '/store/scan';
      default: return '/my-ppe';
    }
  }
}

/// Converts a BLoC stream to a Listenable for GoRouter.
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
