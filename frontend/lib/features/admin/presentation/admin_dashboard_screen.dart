// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_bloc.dart';
import '../../../injection.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _departments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        sl<ApiClient>().get(Endpoints.users),
        sl<ApiClient>().get(Endpoints.roles),
        sl<ApiClient>().get(Endpoints.departments),
      ]);
      final usersPayload = responses[0].data;
      final rolesPayload = responses[1].data;
      final departmentsPayload = responses[2].data;

      final users = _extractList(usersPayload);
      final roles = _extractList(rolesPayload);
      final departments = _extractList(departmentsPayload);
      setState(() {
        _users = users;
        _roles = roles;
        _departments = departments;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load admin data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is List) {
      return payload.cast<Map<String, dynamic>>();
    }
    if (payload is Map<String, dynamic>) {
      final results = payload['results'];
      if (results is List) {
        return results.cast<Map<String, dynamic>>();
      }
    }
    return const [];
  }

  Future<void> _openCreateUserDialog() async {
    final emailCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Demo1234!');
    final mineNumberCtrl = TextEditingController();
    final roleTitleCtrl = TextEditingController();

    String? selectedRoleId = _roles.isNotEmpty ? _roles.first['id'] as String : null;
    String? selectedDepartmentId;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) {
          final roleName = _roleNameById(selectedRoleId);
          final deptRequired = roleName != 'Admin';
          final needsEmployeeRecord = roleName == 'Employee' || roleName == 'Manager';
          return AlertDialog(
            title: const Text('Create User'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Temporary Password'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedRoleId,
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r['id'] as String,
                              child: Text(r['name'] as String? ?? 'Role'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialog(() {
                          selectedRoleId = v;
                          if (!deptRequired) {
                            selectedDepartmentId = null;
                          }
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: selectedDepartmentId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No department'),
                        ),
                        ..._departments.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d['id'] as String,
                            child: Text(d['name'] as String? ?? 'Department'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialog(() => selectedDepartmentId = v),
                      decoration: InputDecoration(
                        labelText: deptRequired ? 'Department (Required)' : 'Department',
                      ),
                    ),
                    if (needsEmployeeRecord) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: mineNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mine Number (Required)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: roleTitleCtrl,
                        decoration: const InputDecoration(labelText: 'Role Title'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim().toLowerCase();
                  final firstName = firstNameCtrl.text.trim();
                  final lastName = lastNameCtrl.text.trim();
                  final password = passwordCtrl.text.trim();
                  final roleId = selectedRoleId;
                  final roleNameNow = _roleNameById(roleId);
                  final needsDept = roleNameNow != 'Admin';
                  final createEmployeeRecord =
                      roleNameNow == 'Employee' || roleNameNow == 'Manager';
                  if (email.isEmpty ||
                      firstName.isEmpty ||
                      lastName.isEmpty ||
                      password.isEmpty ||
                      roleId == null) {
                    return;
                  }
                  if (needsDept &&
                      (selectedDepartmentId == null || mineNumberCtrl.text.trim().isEmpty)) {
                    return;
                  }
                  setState(() => _saving = true);
                  try {
                    final createUserResp = await sl<ApiClient>().post(
                      Endpoints.users,
                      data: {
                        'email': email,
                        'first_name': firstName,
                        'last_name': lastName,
                        'password': password,
                        'confirm_password': password,
                      },
                    );
                    final createdUser = createUserResp.data as Map<String, dynamic>;
                    final userId = createdUser['id'] as String;

                    await sl<ApiClient>().post(
                      Endpoints.userRoles(userId),
                      data: {
                        'role': roleId,
                        if (selectedDepartmentId != null) 'department': selectedDepartmentId,
                      },
                    );

                    if (createEmployeeRecord && selectedDepartmentId != null) {
                      await sl<ApiClient>().post(
                        Endpoints.employees,
                        data: {
                          'user': userId,
                          'department': selectedDepartmentId,
                          'mine_number': mineNumberCtrl.text.trim(),
                          'role_title': roleTitleCtrl.text.trim(),
                          'status': 'active',
                        },
                      );
                    }
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create user: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created successfully')),
      );
    }
  }

  String _roleNameById(String? roleId) {
    if (roleId == null) return '';
    for (final role in _roles) {
      if (role['id'] == roleId) return role['name'] as String? ?? '';
    }
    return '';
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await sl<ApiClient>().post(
        Endpoints.passwordReset,
        data: {'email': email},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send password reset: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Control Center'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'Operations'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Overview'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _openCreateUserDialog,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Create User'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final user = _users[i];
                            final roles = (user['user_roles'] as List? ?? const [])
                                .cast<Map<String, dynamic>>();
                            final roleLabel = roles.isEmpty
                                ? 'No role'
                                : roles.map((r) => r['role_name'] ?? '').join(', ');
                            final departments = roles
                                .map((r) => r['department_name'] as String?)
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .toSet()
                                .join(', ');
                            final subtitle = departments.isEmpty
                                ? roleLabel
                                : '$roleLabel • Dept: $departments';
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                title: Text(user['full_name'] as String? ?? 'User'),
                                subtitle: Text(subtitle),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton(
                                      tooltip: 'Send password reset',
                                      onPressed: () =>
                                          _sendPasswordReset(user['email'] as String? ?? ''),
                                      icon: const Icon(Icons.lock_reset_outlined),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.verified_user_outlined),
                          title: Text('Department-based user control'),
                          subtitle: Text(
                            'Admin creates users, assigns roles, and ensures Employee/Manager users are linked to departments.',
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.password_outlined),
                          title: Text('Password support'),
                          subtitle: Text(
                            'Use reset action from Users tab to send reset links and help users recover access.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text('Users'),
                          trailing: Text('${_users.length}'),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Departments'),
                          trailing: Text('${_departments.length}'),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Roles'),
                          trailing: Text('${_roles.length}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
