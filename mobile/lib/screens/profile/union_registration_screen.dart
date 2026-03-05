import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/union_service.dart';

class UnionRegistrationScreen extends StatefulWidget {
  const UnionRegistrationScreen({super.key});

  @override
  State<UnionRegistrationScreen> createState() =>
      _UnionRegistrationScreenState();
}

class _UnionRegistrationScreenState extends State<UnionRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _loadingStatus = true;
  String? _statusError;
  String _status = 'none';
  Map<String, dynamic>? _union;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _statusError = null;
    });

    final service = UnionService();
    final result = await service.getMyUnion();

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _status = (result['status'] ?? 'none').toString();
        _union = result['union'] as Map<String, dynamic>?;
        _loadingStatus = false;
      });
      _configureAutoRefresh();
    } else {
      setState(() {
        _statusError = result['message']?.toString();
        _loadingStatus = false;
      });
    }
  }

  void _configureAutoRefresh() {
    // Auto-poll while request is pending so that as soon as
    // admin approves, screen updates without app restart.
    if (_status == 'pending') {
      _statusTimer ??= Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!mounted) {
          timer.cancel();
          _statusTimer = null;
          return;
        }
        // Only poll while still pending; stops automatically once approved/rejected.
        if (_status == 'pending') {
          _loadStatus();
        } else {
          timer.cancel();
          _statusTimer = null;
        }
      });
    } else {
      _statusTimer?.cancel();
      _statusTimer = null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final service = UnionService();
    final result = await service.registerUnion(
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final auth = context.read<AuthProvider>();

    if (result['success'] == true) {
      // Refresh user so role/flags are up to date if backend sets them.
      await auth.refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Union registered',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Failed to register union',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Taxi Union'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // If there is a pending or approved union, show status instead of form
    if (_status == 'pending' && _union != null) {
      final name = (_union!['name'] ?? '').toString();
      final location = (_union!['address'] ?? _union!['location'] ?? '').toString();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request submitted',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isNotEmpty ? name : 'Your taxi union',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Your union registration is pending.\n'
                      'App admin will review and approve/cancel this request.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Check again'),
            ),
          ],
        ),
      );
    }

    if (_status == 'approved' && _union != null) {
      final name = (_union!['name'] ?? '').toString();
      final location = (_union!['address'] ?? _union!['location'] ?? '').toString();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Union approved',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isNotEmpty ? name : 'Your taxi union',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Your union is approved.\n'
                      'You can use the Union Dashboard from your profile.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to profile'),
            ),
          ],
        ),
      );
    }

    // Default: show registration form
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusError != null) ...[
            Text(
              _statusError!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Union Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Union name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter union name';
              if (value.length < 3) return 'Name must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location (town / stand)',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter location';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Contact email (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit for Approval',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

