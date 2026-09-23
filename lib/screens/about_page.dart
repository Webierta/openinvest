import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../widgets/gradient_background.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.aboutOpenInvest),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AboutItem(
                title: l10n.licenseTitle,
                content: l10n.licenseDesc,
              ),
              _AboutItem(
                title: l10n.openSourceTitle,
                content: l10n.openSourceDesc,
              ),
              _AboutItem(
                title: l10n.dataSourceTitle,
                content: l10n.dataSourceDesc,
              ),
              _AboutItem(
                title: l10n.permissionsTitle,
                content: l10n.permissionsDesc,
              ),
              _AboutItem(
                title: l10n.warrantyTitle,
                content: l10n.warrantyDesc,
              ),
              _AboutItem(
                title: l10n.privacyTitle,
                content: l10n.privacyDesc,
              ),
              const SizedBox(height: 20),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version;
                  return Center(
                    child: Text(
                      '${l10n.versionLabel} ${version ?? '...'}\nhttps://github.com/Webierta/openinvest',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final String title;
  final String content;

  const _AboutItem({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
