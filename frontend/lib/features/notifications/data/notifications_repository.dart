import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class NotificationsRepository {
  final ApiClient _api;
  NotificationsRepository(this._api);

  Future<List<Map<String, dynamic>>> getNotifications({bool unreadOnly = false}) async {
    final response = await _api.get(
      Endpoints.notifications,
      queryParams: unreadOnly ? {'unread': 'true'} : null,
    );
    final data = response.data as Map<String, dynamic>;
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get(Endpoints.unreadCount);
    return (response.data as Map<String, dynamic>)['unread_count'] as int;
  }

  Future<void> markRead(String id) => _api.post(Endpoints.markRead(id));
  Future<void> markAllRead() => _api.post(Endpoints.markAllRead);
}
