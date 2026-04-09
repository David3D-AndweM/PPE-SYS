import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import 'endpoints.dart';

/// Injects the Bearer token on every request.
/// On 401, silently refreshes the token and retries.
/// If refresh fails, clears tokens (triggers login redirect via AuthBloc).
class AuthInterceptor extends Interceptor {
  final TokenStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearTokens();
        handler.next(err);
        return;
      }

      // Attempt silent token refresh
      final refreshDio = Dio();
      final response = await refreshDio.post(
        Endpoints.tokenRefresh,
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'] as String;
      final newRefresh = response.data['refresh'] as String? ?? refreshToken;
      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      // Retry the original request with the new token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      // Refresh failed — force logout
      await _storage.clearTokens();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
