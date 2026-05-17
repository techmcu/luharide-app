import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final authProvider = context.read<AuthProvider>();
    final hasPassword = authProvider.user?.hasPassword ?? true;

    final ok = await authProvider.changePassword(
      current: hasPassword ? _currentController.text.trim() : null,
      newPassword: _newController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    AppFeedback.show(
      context,
      ok
          ? (hasPassword ? 'Password updated successfully' : 'Password set successfully')
          : (authProvider.error ?? 'Failed to update password'),
      kind: ok ? AppFeedbackKind.success : AppFeedbackKind.error,
    );

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = context.watch<AuthProvider>().user?.hasPassword ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasPassword ? 'Change Password' : 'Set Password'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!hasPassword)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You signed in with Google. Set a password to also log in with email & password.',
                          style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasPassword)
              TextFormField(
                controller: _currentController,
                maxLength: InputLimits.password,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
              ),
            if (hasPassword) const SizedBox(height: 16),
            TextFormField(
              controller: _newController,
              maxLength: InputLimits.password,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'New password is required';
                if (v.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              maxLength: InputLimits.password,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm new password';
                if (v != _newController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasPassword ? 'Update Password' : 'Set Password',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
