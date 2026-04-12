import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/endpoints.dart';
import '../auth/token_storage.dart';

typedef NotificationCallback = void Function(Map<String, dynamic> data);

/// Manages the WebSocket connection for real-time notifications.
/// Reconnects with exponential backoff (max 60s) on disconnect.
class WsService {
  final TokenStorage _storage;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  NotificationCallback? _onNotification;
  int _reconnectDelay = 2;
  bool _intentionalClose = false;

  /// Increments each time a push notification arrives. Reset on badge tap.
  final unreadPushCount = ValueNotifier<int>(0);

  WsService(this._storage);

  void onNotification(NotificationCallback callback) {
    _onNotification = callback;
  }

  Future<void> connect() async {
    _intentionalClose = false;
    final token = await _storage.getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse(Endpoints.notificationsWs(token));
      _channel = WebSocketChannel.connect(uri);
      _reconnectDelay = 2; // reset on successful connect

      _subscription = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void markRead(String notificationId) {
    _channel?.sink.add(jsonEncode({
      'action': 'mark_read',
      'notification_id': notificationId,
    }));
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  void resetBadge() => unreadPushCount.value = 0;

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _onNotification?.call(data);
      unreadPushCount.value++;
    } catch (_) {}
  }

  void _onDisconnected() {
    if (_intentionalClose) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Future.delayed(Duration(seconds: _reconnectDelay), () {
      if (!_intentionalClose) {
        _reconnectDelay = (_reconnectDelay * 2).clamp(2, 60);
        connect();
      }
    });
  }
}
