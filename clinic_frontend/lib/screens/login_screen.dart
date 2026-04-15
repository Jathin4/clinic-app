import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';
import '../services/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPass = false, _loading = false;
  String _error = '';

  bool _showSetPassword = false;
  Map<String, dynamic>? _pendingUser;
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showNewPass = false, _showConfirmPass = false;
  String _passError = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _error = '');
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Email and Password are required');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth_login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'email': _emailCtrl.text.trim(), 'password': _passwordCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        final user = data['user'] as Map<String, dynamic>;
        _passwordCtrl.clear();
        if (user['last_login'] == null) {
          setState(() {
            _pendingUser = user;
            _showSetPassword = true;
          });
        } else {
          // AFTER
          await Session.setFromLoginResponse({
            'clinic_id': user['clinic_id'],
            'user_id': user['id'], // note: backend sends 'id', not 'user_id'
            'role': user['role'],
          });
          if (mounted) context.read<AppProvider>().setUser(user);
        }
      } else {
        _passwordCtrl.clear();
        setState(() => _error =
            data['detail'] ?? 'Invalid credentials. Please try again.');
      }
    } catch (e) {
      _passwordCtrl.clear();
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSetPassword() async {
    setState(() => _passError = '');
    if (_newPassCtrl.text.isEmpty || _confirmPassCtrl.text.isEmpty) {
      setState(() => _passError = 'Both fields are required');
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() => _passError = 'Password must be at least 6 characters');
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passError = 'Passwords do not match');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth_set_password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _pendingUser!['id'],
          'new_password': _newPassCtrl.text
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        if (mounted) {
          setState(() => _showSetPassword = false);
          await Session.setFromLoginResponse({
  'clinic_id': _pendingUser!['clinic_id'],
  'user_id':   _pendingUser!['id'],
  'role':      _pendingUser!['role'],
});
context.read<AppProvider>().setUser(_pendingUser!);
        }
      } else {
        setState(
            () => _passError = data['detail'] ?? 'Failed to set password.');
      }
    } catch (e) {
      _passwordCtrl.clear();
      setState(() => _error = 'Error: $e'); // show actual error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1024;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Row(children: [
          if (isWide) const _LeftPanel(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand mark
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.teal, AppColors.teal2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.favorite_border,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 28),
                        const Text('Welcome back',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        const Text('Sign in to your clinic dashboard',
                            style: AppTextStyles.bodyMuted),
                        const SizedBox(height: 32),
                        if (_error.isNotEmpty) AppErrorBanner(message: _error),

                        // Email
                        const Text('EMAIL ADDRESS', style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: AppInput.deco('your@clinic.com',
                                icon: Icons.email_outlined)),
                        const SizedBox(height: 18),

                        // Password
                        const Text('PASSWORD', style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: !_showPass,
                          decoration: AppInput.deco('Enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _showPass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textMuted,
                                    size: 20),
                                onPressed: () =>
                                    setState(() => _showPass = !_showPass),
                              )),
                        ),
                        const SizedBox(height: 28),
                        AppPrimaryButton(
                            label: 'Sign in to ClinicOS',
                            loading: _loading,
                            onPressed: _handleLogin),
                      ]),
                ),
              ),
            ),
          ),
        ]),
        if (_showSetPassword)
          _SetPasswordOverlay(
            pendingUser: _pendingUser,
            newPassCtrl: _newPassCtrl,
            confirmPassCtrl: _confirmPassCtrl,
            showNewPass: _showNewPass,
            showConfirmPass: _showConfirmPass,
            passError: _passError,
            loading: _loading,
            onToggleNew: () => setState(() => _showNewPass = !_showNewPass),
            onToggleConfirm: () =>
                setState(() => _showConfirmPass = !_showConfirmPass),
            onSubmit: _handleSetPassword,
          ),
      ]),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.45,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealDark, AppColors.teal, AppColors.teal2]),
      ),
      padding: const EdgeInsets.all(52),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Logo
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.favorite_border,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('ClinicOS',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        // Accent bar
        Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
                color: Colors.white30, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 28),
        const Text('Modern Healthcare\nManagement Platform',
            style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.5)),
        const SizedBox(height: 18),
        const Text(
            'Manage patients, appointments, billing, and revenue — all in one intelligent clinic platform.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.7)),
        const SizedBox(height: 44),
        // Stats row
        Row(children: [
          for (final item in [
            ['1,842', 'Patients'],
            ['24', 'Daily Apts'],
            ['₹2.1L', 'Monthly Rev']
          ])
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  Text(item[1],
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
        ]),
        const SizedBox(height: 40),
        // Tags
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tag in [
            'HIPAA Compliant',
            '256-bit Encrypted',
            '99.9% Uptime'
          ])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(9999)),
              child: Text(tag,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
        ]),
      ]),
    );
  }
}

class _SetPasswordOverlay extends StatelessWidget {
  final Map<String, dynamic>? pendingUser;
  final TextEditingController newPassCtrl, confirmPassCtrl;
  final bool showNewPass, showConfirmPass, loading;
  final String passError;
  final VoidCallback onToggleNew, onToggleConfirm, onSubmit;

  const _SetPasswordOverlay({
    required this.pendingUser,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.showNewPass,
    required this.showConfirmPass,
    required this.loading,
    required this.passError,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF001F26).withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 20))
              ]),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  AppGradientIcon(icon: Icons.lock_open_outlined),
                  const SizedBox(width: 12),
                  const Text('Set Your Password',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Text(
                    'Welcome, ${pendingUser?['full_name'] ?? ''}! Since this is your first login, please set a new password.',
                    style: AppTextStyles.bodyMuted),
                const SizedBox(height: 24),
                if (passError.isNotEmpty) AppErrorBanner(message: passError),
                const Text('NEW PASSWORD', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextField(
                    controller: newPassCtrl,
                    obscureText: !showNewPass,
                    decoration: AppInput.deco('Enter new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              showNewPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted,
                              size: 20),
                          onPressed: onToggleNew,
                        ))),
                const SizedBox(height: 16),
                const Text('CONFIRM PASSWORD', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextField(
                    controller: confirmPassCtrl,
                    obscureText: !showConfirmPass,
                    decoration: AppInput.deco('Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              showConfirmPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted,
                              size: 20),
                          onPressed: onToggleConfirm,
                        ))),
                const SizedBox(height: 28),
                AppPrimaryButton(
                    label: 'Set Password & Continue',
                    loading: loading,
                    onPressed: onSubmit),
              ]),
        ),
      ),
    );
  }
}
