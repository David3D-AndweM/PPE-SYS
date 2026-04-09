import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class ApprovalsRepository {
  final ApiClient _api;
  ApprovalsRepository(this._api);

  Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final response = await _api.get(Endpoints.pendingApprovals);
    final data = response.data as Map<String, dynamic>;
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> approve(String approvalId, {String comment = ''}) async {
    await _api.post(Endpoints.approveSlip(approvalId), data: {'comment': comment});
  }

  Future<void> reject(String approvalId, {required String comment}) async {
    await _api.post(Endpoints.rejectSlip(approvalId), data: {'comment': comment});
  }
}
