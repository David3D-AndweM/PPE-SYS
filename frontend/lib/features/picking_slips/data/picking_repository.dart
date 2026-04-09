import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class PickingRepository {
  final ApiClient _api;
  PickingRepository(this._api);

  Future<List<Map<String, dynamic>>> getSlips({String? status}) async {
    final response = await _api.get(
      Endpoints.pickingSlips,
      queryParams: status != null ? {'status': status} : null,
    );
    final data = response.data as Map<String, dynamic>;
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSlip(String id) async {
    final response = await _api.get('${Endpoints.pickingSlips}$id/');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSlip(Map<String, dynamic> data) async {
    final response = await _api.post(Endpoints.createPickingSlip, data: data);
    return response.data as Map<String, dynamic>;
  }
}
