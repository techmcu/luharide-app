import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand_config.dart';
import '../../core/config/env_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _openWhatsApp() async {
    final u = BrandConfig.whatsAppUri;
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEmail() async {
    final u = Uri(
      scheme: 'mailto',
      path: BrandConfig.supportEmail,
      queryParameters: {'subject': '${BrandConfig.appName} support'},
    );
    if (await canLaunchUrl(u)) await launchUrl(u);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);

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
            leading: const Icon(Icons.email_outlined),
            title: Text(loc.t('help.email.label')),
            subtitle: const Text(BrandConfig.supportEmail),
            onTap: _openEmail,
          ),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            title: Text(loc.t('help.whatsapp.label')),
            subtitle: Text(
              '${BrandConfig.whatsAppDisplay}\n${loc.t('help.whatsapp.tap')}',
            ),
            isThreeLine: true,
            onTap: _openWhatsApp,
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
              final suffix = EnvConfig.versionDisplaySuffix;
              final sub = suffix.isEmpty
                  ? '${p.version} (${p.buildNumber})'
                  : '${p.version} (${p.buildNumber}) · $suffix';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.t('help.about.version')),
                subtitle: Text(sub),
              );
            },
          ),
          Builder(
            builder: (context) {
              final u = BrandConfig.privacyPolicyUri;
              if (u != null) {
                return ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(loc.t('help.about.privacy')),
                  subtitle: Text(u.toString()),
                  onTap: () async {
                    if (await canLaunchUrl(u)) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  },
                );
              }
              return ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(loc.t('help.about.privacy')),
                subtitle: Text(loc.t('help.about.privacy_hint')),
              );
            },
          ),
        ],
      ),
    );
  }
}
