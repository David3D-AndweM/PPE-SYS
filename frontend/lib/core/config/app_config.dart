import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ServerEnv { local, network, custom }

/// Runtime-switchable server configuration.
/// Defaults to [ServerEnv.local] so the app works out of the box
/// when everything is running on the same machine (make dev + flutter run).
class AppConfig extends ChangeNotifier {
  AppConfig._();
  static final AppConfig instance = AppConfig._();

  ServerEnv _env = ServerEnv.local;
  String _customApiUrl = '';
  String _customWsUrl = '';

  ServerEnv get env => _env;

  /// The API base URL for the currently selected environment.
  String get apiBaseUrl {
    switch (_env) {
      case ServerEnv.local:
        return 'http://localhost/api/v1';
      case ServerEnv.network:
        return dotenv.env['API_BASE_URL'] ?? 'http://localhost/api/v1';
      case ServerEnv.custom:
        return _customApiUrl.isNotEmpty
            ? _customApiUrl
            : 'http://localhost/api/v1';
    }
  }

  /// The WebSocket base URL for the currently selected environment.
  String get wsBaseUrl {
    switch (_env) {
      case ServerEnv.local:
        return 'ws://localhost/ws';
      case ServerEnv.network:
        return dotenv.env['WS_BASE_URL'] ?? 'ws://localhost/ws';
      case ServerEnv.custom:
        return _customWsUrl.isNotEmpty ? _customWsUrl : 'ws://localhost/ws';
    }
  }

  String get label {
    switch (_env) {
      case ServerEnv.local:
        return 'Local (localhost)';
      case ServerEnv.network:
        return 'Network (${dotenv.env['API_BASE_URL'] ?? '?'})';
      case ServerEnv.custom:
        return 'Custom';
    }
  }

  void switchTo(ServerEnv env, {String customApi = '', String customWs = ''}) {
    _env = env;
    _customApiUrl = customApi;
    _customWsUrl = customWs;
    notifyListeners();
  }
}
