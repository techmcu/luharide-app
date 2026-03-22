import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Edit Profile - Name, Email, Profile Picture
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int maxBioWords = 20;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _whatsappController;
  late TextEditingController _bioController;
  late TextEditingController _luggageController;
  bool _isLoading = false;
  /// Picked image bytes (works on Web + mobile; avoids dart:io FileImage).
  Uint8List? _localImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _whatsappController = TextEditingController(text: user?.whatsappNumber ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _luggageController = TextEditingController(text: user?.luggageAllowancePerPassenger ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _bioController.dispose();
    _luggageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _localImageBytes = bytes;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final authProvider = context.read<AuthProvider>();

    String? profileImageUrl;
    if (_localImageBytes != null) {
      final b64 = base64Encode(_localImageBytes!);
      profileImageUrl = 'data:image/jpeg;base64,$b64';
    }

    final success = await authProvider.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      whatsappNumber: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
      profileImageUrl: profileImageUrl,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      luggageAllowancePerPassenger: _luggageController.text.trim().isEmpty ? null : _luggageController.text.trim(),
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Failed to update'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDriver = user?.role == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: isDriver ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ))
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            // Profile picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: (isDriver ? Colors.green : Colors.blue)[100],
                    backgroundImage: _localImageBytes != null
                        ? MemoryImage(_localImageBytes!)
                        : (user?.profileImage != null && user!.profileImage!.isNotEmpty
                            ? (user.profileImage!.startsWith('data:image')
                                ? MemoryImage(
                                    base64Decode(
                                      user.profileImage!.substring(
                                        user.profileImage!.indexOf(',') + 1,
                                      ),
                                    ),
                                  )
                                : NetworkImage(user.profileImage!) as ImageProvider)
                            : null),
                    child: (user?.profileImage == null || user!.profileImage!.isEmpty) && _localImageBytes == null
                        ? Text(
                            (user?.name ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: (isDriver ? Colors.green : Colors.blue)[800],
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.camera_alt, size: 20, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap the camera to change profile picture',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 32),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 2) return 'Name must be at least 2 characters';
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                return null;
              },
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 20),

            // Phone (read-only)
            if (user?.phone != null)
              TextFormField(
                initialValue: user!.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
            const SizedBox(height: 20),
            // WhatsApp (for Chat redirect after ride approval)
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number',
                hintText: 'e.g. 9876543210',
                prefixIcon: Icon(Icons.chat_bubble_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                if (digits.length < 10) return 'Enter valid 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Bio (max 20 words)
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio (optional)',
                hintText: 'About you in a few words (max 20 words)',
                prefixIcon: Icon(Icons.short_text),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final words = v.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                if (words > maxBioWords) return 'Maximum $maxBioWords words';
                return null;
              },
            ),
            if (isDriver) ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _luggageController,
                decoration: const InputDecoration(
                  labelText: 'Luggage per passenger',
                  hintText: 'e.g. 1 bag, 2 bags (shown to passengers)',
                  prefixIcon: Icon(Icons.luggage),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
