import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
              _AboutItem(title: l10n.licenseTitle, content: l10n.licenseDesc),
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
              _AboutItem(title: l10n.warrantyTitle, content: l10n.warrantyDesc),
              _AboutItem(title: l10n.privacyTitle, content: l10n.privacyDesc),
              _AboutItem(
                title: l10n.creditsTitle,
                content: l10n.creditsDesc,
                isCredits: true,
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
  final bool? isCredits;

  const _AboutItem({
    required this.title,
    required this.content,
    this.isCredits = false,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

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
            (isCredits == false)
                ? Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  )
                : RichText(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(context).textScaler.scale(1),
                    ),
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      children: [
                        TextSpan(
                          text: 'OpenInvest — Proyecto de código abierto desarrollado por Webierta.\n\n',
                        ),
                        const TextSpan(text: 'Asistencia de desarrollo — '),
                        TextSpan(
                          text: 'ChatGPT · OpenAI',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _openUrl('https://chatgpt.com');
                            },
                        ),
                        const TextSpan(
                          text: ' — Asistencia en arquitectura de software, investigación técnica, implementación, pruebas, depuración, revisión de código, seguridad y automatización CI/CD. Parte de las decisiones técnicas, implementación final y validación del código corresponden al autor del proyecto.\n\n',
                        ),
                        const TextSpan(text: 'Herramientas de IA — '),
                        TextSpan(
                          text: 'GitHub Copilot',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _openUrl('https://github.com/features/copilot');
                            },
                        ),
                        const TextSpan(text: ' y '),
                        TextSpan(
                          text: 'Google Gemini',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _openUrl('https://gemini.google.com');
                            },
                        ),
                        const TextSpan(
                          text: ' — Utilizadas como herramientas complementarias durante el desarrollo del proyecto para asistencia en programación, generación y revisión de código, investigación y resolución de problemas técnicos.',
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
