import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/brand_config.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';

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
                    final u = BrandConfig.privacyPolicyUri!;
                    if (await canLaunchUrl(u)) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
