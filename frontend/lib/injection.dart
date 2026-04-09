import 'package:get_it/get_it.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_bloc.dart';
import 'core/auth/token_storage.dart';
import 'core/websocket/ws_service.dart';
import 'features/approvals/data/approvals_repository.dart';
import 'features/my_ppe/data/ppe_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/picking_slips/data/picking_repository.dart';
import 'features/scanning/data/scan_repository.dart';

final sl = GetIt.instance;

void setupDependencies() {
  // Core
  sl.registerLazySingleton<TokenStorage>(() => TokenStorage());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));
  sl.registerLazySingleton<WsService>(() => WsService(sl()));

  // Repositories
  sl.registerLazySingleton<PpeRepository>(() => PpeRepository(sl()));
  sl.registerLazySingleton<PickingRepository>(() => PickingRepository(sl()));
  sl.registerLazySingleton<ApprovalsRepository>(() => ApprovalsRepository(sl()));
  sl.registerLazySingleton<ScanRepository>(() => ScanRepository(sl()));
  sl.registerLazySingleton<NotificationsRepository>(() => NotificationsRepository(sl()));

  // BLoCs
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl(), sl(), sl()));
}
