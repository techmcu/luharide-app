import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_navigator.dart';
import '../../../../core/brand_config.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../landing/presentation/screens/landing_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguageProvider>().language;
    final loc = AppLocalizations(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('help.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            loc.t('help.faq.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(loc.t('help.faq.book.q')),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(loc.t('help.faq.book.a')),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(loc.t('help.faq.pay.q')),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(loc.t('help.faq.pay.a')),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(loc.t('help.faq.driver.q')),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(loc.t('help.faq.driver.a')),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(loc.t('help.faq.google_password.q')),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(loc.t('help.faq.google_password.a')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            loc.t('help.safety.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(loc.t('help.safety.1.title')),
            subtitle: Text(loc.t('help.safety.1.sub')),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(loc.t('help.safety.2.title')),
            subtitle: Text(loc.t('help.safety.2.sub')),
          ),
          const SizedBox(height: 24),
          Text(
            loc.t('help.contact.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.email_outlined, color: Colors.grey[800]),
            title: Text(loc.t('help.email.label')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  BrandConfig.supportEmail,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.t('help.email.display_hint'),
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.grey[700]),
                ),
              ],
            ),
            isThreeLine: true,
          ),
          const SizedBox(height: 24),
          Text(
            loc.t('help.about.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.t('help.about.version')),
                  trailing: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final p = snap.data!;
              final suffix = EnvConfig.versionDisplaySuffix.trim();
              final versionLine =
                  suffix.isEmpty ? p.version : '${p.version} $suffix';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.t('help.about.version')),
                subtitle: Text(versionLine),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(loc.t('help.about.privacy')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('help.about.privacy_hint'),
                  style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey[800]),
                ),
                if (BrandConfig.privacyPolicyUri != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    BrandConfig.privacyPolicyUrl,
                    style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            onTap: BrandConfig.privacyPolicyUri == null
                ? null
                : () async {
                    try {
                      final u = BrandConfig.privacyPolicyUri!;
                      if (await canLaunchUrl(u)) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            loc.t('help.account_management.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red[800]),
              title: Text(
                loc.t('profile.delete_account.title'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red[800],
                ),
              ),
              subtitle: Text(
                loc.t('profile.delete_account.subtitle'),
                style: TextStyle(fontSize: 12.5, color: Colors.red[700]),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red[600]),
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final loc = AppLocalizations.of(context);
    final passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(loc.t('delete_account.dialog_title'))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('delete_account.warning'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.t('delete_account.data_list'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  maxLength: 128,
                  decoration: InputDecoration(
                    labelText: loc.t('delete_account.password_label'),
                    hintText: loc.t('delete_account.password_hint'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
              child: Text(loc.t('delete_account.cancel_button')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: isDeleting
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      if (password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.t('delete_account.password_required'))),
                        );
                        return;
                      }

                      setState(() => isDeleting = true);

                      try {
                        await authProvider.deleteAccount(password);
                        
                        if (!ctx.mounted) return;
                        Navigator.pop(dialogCtx);

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.t('delete_account.success')),
                            backgroundColor: Colors.green,
                          ),
                        );

                        // Navigate to landing screen after a short delay
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (navigatorKey.currentState != null) {
                            navigatorKey.currentState!.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LandingScreen()),
                              (route) => false,
                            );
                          }
                        });
                      } catch (e) {
                        setState(() => isDeleting = false);
                        if (!ctx.mounted) return;

                        String errorMsg = loc.t('delete_account.failed');
                        final errorStr = e.toString();

                        if (errorStr.contains('Incorrect password')) {
                          errorMsg = loc.t('delete_account.incorrect_password');
                        } else if (errorStr.contains('OTP')) {
                          errorMsg = loc.t('delete_account.no_password_error');
                        } else if (errorStr.contains('Session expired') || errorStr.contains('login again')) {
                          errorMsg = 'Session expired. Please logout and login again to delete your account.';

                          // Auto-redirect to landing after 2 seconds
                          Future.delayed(const Duration(seconds: 2), () {
                            if (navigatorKey.currentState != null) {
                              navigatorKey.currentState!.pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LandingScreen()),
                                (route) => false,
                              );
                            }
                          });
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(loc.t('delete_account.confirm_button')),
            ),
          ],
        ),
      ),
    );
  }
}
