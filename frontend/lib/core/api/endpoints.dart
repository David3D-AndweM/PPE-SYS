import '../config/app_config.dart';

class Endpoints {
  static String get base => AppConfig.instance.apiBaseUrl;
  static String get wsBase => AppConfig.instance.wsBaseUrl;

  // Auth
  static String get login => '$base/auth/login/';
  static String get tokenRefresh => '$base/auth/token/refresh/';
  static String get profile => '$base/auth/me/';
  static String get users => '$base/auth/users/';
  static String userDetail(String id) => '$base/auth/users/$id/';
  static String userRoles(String userId) => '$base/auth/users/$userId/roles/';
  static String get roles => '$base/auth/roles/';
  static String get passwordReset => '$base/auth/password-reset/';
  static String get impersonateUser => '$base/auth/impersonate/';

  // My PPE
  static String get myPpe => '$base/ppe/my-ppe/';
  static String get myPpeCompliance => '$base/ppe/my-ppe/compliance/';

  // PPE catalogue
  static String get ppeItems => '$base/ppe/items/';
  static String ppeItemDetail(String id) => '$base/ppe/items/$id/';
  static String get ppeConfigurations => '$base/ppe/configurations/';
  static String ppeConfigurationDetail(String id) =>
      '$base/ppe/configurations/$id/';
  static String get ppeRequirements => '$base/ppe/requirements/';
  static String ppeRequirementDetail(String id) =>
      '$base/ppe/requirements/$id/';
  static String get assignments => '$base/ppe/assignments/';

  // Picking slips
  static String get pickingSlips => '$base/picking/slips/';
  static String get createPickingSlip => '$base/picking/slips/create/';
  static String get autoCreatePickingSlip => '$base/picking/slips/auto-create/';
  static String get validateScan => '$base/picking/slips/validate-scan/';
  static String get finalizeIssue => '$base/picking/slips/finalize-issue/';

  // Approvals
  static String get pendingApprovals => '$base/approvals/pending/';
  static String approveSlip(String id) => '$base/approvals/$id/approve/';
  static String rejectSlip(String id) => '$base/approvals/$id/reject/';

  // Notifications
  static String get notifications => '$base/notifications/';
  static String get unreadCount => '$base/notifications/unread-count/';
  static String get markAllRead => '$base/notifications/mark-all-read/';
  static String markRead(String id) => '$base/notifications/$id/mark-read/';

  // Organization
  static String get employees => '$base/org/employees/';
  static String get departments => '$base/org/departments/';
  static String departmentDetail(String id) => '$base/org/departments/$id/';
  static String get sites => '$base/org/sites/';

  // Inventory
  static String get stock => '$base/inventory/stock/';
  static String get warehouses => '$base/inventory/warehouses/';

  // Audit
  static String get auditLogs => '$base/audit/logs/';

  // WebSocket
  static String notificationsWs(String token) =>
      '$wsBase/notifications/?token=$token';
}
