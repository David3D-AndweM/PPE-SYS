import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/auth/auth_bloc.dart';
import '../../../core/config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  void _showServerPicker() {
    final config = AppConfig.instance;
    final customApiCtrl = TextEditingController(text: config.apiBaseUrl);
    final customWsCtrl = TextEditingController(text: config.wsBaseUrl);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Select Server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _serverTile(ctx, setS, ServerEnv.local, 'Local (this machine)',
                  'http://localhost/api/v1', config),
              _serverTile(ctx, setS, ServerEnv.network, 'Network / Deployed',
                  _dotenvUrl, config),
              const Divider(),
              _serverTile(ctx, setS, ServerEnv.custom, 'Custom URL', '', config),
              if (config.env == ServerEnv.custom) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: customApiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API base URL',
                    hintText: 'http://192.168.x.x/api/v1',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customWsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WebSocket base URL',
                    hintText: 'ws://192.168.x.x/ws',
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (config.env == ServerEnv.custom) {
                  config.switchTo(
                    ServerEnv.custom,
                    customApi: customApiCtrl.text.trim(),
                    customWs: customWsCtrl.text.trim(),
                  );
                }
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  String get _dotenvUrl =>
      dotenv.env['API_BASE_URL'] ?? 'set API_BASE_URL in .env';

  Widget _serverTile(BuildContext ctx, StateSetter setS, ServerEnv env,
      String label, String subtitle, AppConfig config) {
    final selected = config.env == env;
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(ctx).colorScheme.primary : Colors.grey,
      ),
      title: Text(label),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      onTap: () {
        config.switchTo(env);
        setS(() {});
      },
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthLoginRequested(_emailCtrl.text.trim(), _passwordCtrl.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 72, color: Color(0xFF1A5276)),
                    const SizedBox(height: 16),
                    Text(
                      'EPPEP',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A5276),
                          ),
                    ),
                    const Text(
                      'Enterprise PPE Compliance Platform',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 48),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Enter your password' : null,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: state is AuthLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _submit,
                                    child: const Text('Sign In'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Server selector
                    GestureDetector(
                      onTap: _showServerPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppConfig.instance.env == ServerEnv.local
                                  ? Icons.computer
                                  : Icons.cloud_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppConfig.instance.label,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.expand_more,
                                size: 14, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
