import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class PpeRepository {
  final ApiClient _api;
  PpeRepository(this._api);

  Future<List<Map<String, dynamic>>> getMyPpe() async {
    final response = await _api.get(Endpoints.myPpe);
    final data = response.data as Map<String, dynamic>;
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getComplianceSummary() async {
    final response = await _api.get(Endpoints.myPpeCompliance);
    return response.data as Map<String, dynamic>;
  }
}
