import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class ScanRepository {
  final ApiClient _api;
  ScanRepository(this._api);

  Future<Map<String, dynamic>> validateScan(String qrData) async {
    final response = await _api.post(
      Endpoints.validateScan,
      data: {'qr_data': qrData},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateByReference({
    required String slipNumber,
    String? mineNumber,
    String? employeeId,
  }) async {
    final response = await _api.post(
      Endpoints.validateScan,
      data: {
        'slip_number': slipNumber,
        if (mineNumber != null && mineNumber.trim().isNotEmpty)
          'mine_number': mineNumber.trim(),
        if (employeeId != null && employeeId.trim().isNotEmpty)
          'employee_id': employeeId.trim(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> finalizeIssue({
    required String slipId,
    required String warehouseId,
  }) async {
    final response = await _api.post(
      Endpoints.finalizeIssue,
      data: {'slip_id': slipId, 'warehouse_id': warehouseId},
    );
    return response.data as Map<String, dynamic>;
  }
}
