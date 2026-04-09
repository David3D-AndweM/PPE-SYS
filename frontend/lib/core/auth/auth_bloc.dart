import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../websocket/ws_service.dart';
import 'token_storage.dart';

// --- Events ---
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

// --- States ---
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String accessToken;
  final List<String> roles;
  final String? employeeId;
  final String fullName;
  final String email;

  AuthAuthenticated({
    required this.accessToken,
    required this.roles,
    this.employeeId,
    required this.fullName,
    required this.email,
  });

  bool get isAdmin => roles.contains('Admin');
  bool get isManager => roles.contains('Manager');
  bool get isSafety => roles.contains('Safety');
  bool get isStore => roles.contains('Store');
  bool get isEmployee => roles.contains('Employee');

  /// Primary role for routing — highest privilege wins.
  String get primaryRole {
    if (isAdmin) return 'Admin';
    if (isManager) return 'Manager';
    if (isSafety) return 'Safety';
    if (isStore) return 'Store';
    return 'Employee';
  }

  @override
  List<Object?> get props => [accessToken, roles, employeeId, email];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final TokenStorage _storage;
  final ApiClient _api;
  final WsService _ws;

  AuthBloc(this._storage, this._api, this._ws) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await _storage.getAccessToken();
    if (token == null || TokenStorage.isTokenExpired(token)) {
      // Attempt silent refresh
      final refresh = await _storage.getRefreshToken();
      if (refresh == null) {
        emit(AuthUnauthenticated());
        return;
      }
      // The interceptor will handle refresh on next API call;
      // for startup check, emit unauthenticated and let the interceptor retry.
      emit(AuthUnauthenticated());
      return;
    }
    emit(_stateFromToken(token));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _api.post(
        Endpoints.login,
        data: {'email': event.email, 'password': event.password},
      );
      final data = response.data as Map<String, dynamic>;
      final access = data['access'] as String;
      final refresh = data['refresh'] as String;
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
      emit(_stateFromToken(access));
      _ws.connect();
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _ws.disconnect();
    _ws.unreadPushCount.value = 0;
    await _storage.clearTokens();
    emit(AuthUnauthenticated());
  }

  AuthAuthenticated _stateFromToken(String token) {
    final payload = TokenStorage.decodePayload(token) ?? {};
    return AuthAuthenticated(
      accessToken: token,
      roles: TokenStorage.getRolesFromToken(token),
      employeeId: payload['employee_id'] as String?,
      fullName: payload['full_name'] as String? ?? '',
      email: payload['email'] as String? ?? '',
    );
  }

  String _parseError(Object e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return 'Login failed. Please check your credentials.';
  }
}
