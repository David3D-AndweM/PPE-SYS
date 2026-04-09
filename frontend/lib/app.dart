import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/auth/auth_bloc.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'injection.dart';

class PpeApp extends StatelessWidget {
  const PpeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>()..add(AuthCheckRequested()),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final router = AppRouter(authBloc: context.read<AuthBloc>()).router;
          return MaterialApp.router(
            title: 'EPPEP',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
