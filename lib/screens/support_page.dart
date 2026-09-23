import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../widgets/gradient_background.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const String paypalUrl =
      'https://www.paypal.com/donate?hosted_button_id=986PSAHLH6N4L';
  static const String githubUrl = 'https://github.com/Webierta/openinvest';
  static const String btcAddress = '15ZpNzqbYFx9P7wg4U438JMwZr2q3W6fkS';

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.supportOpenInvest),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.helloDeveloper,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.supportDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Sugerencias / GitHub
                _SupportCard(
                  icon: Icons.bug_report_outlined,
                  title: l10n.githubTitle,
                  description: l10n.githubDescription,
                  buttonLabel: l10n.githubButton,
                  color: Colors.white12,
                  onPressed: () => _launchUrl(githubUrl),
                ),

                const SizedBox(height: 24),

                // PayPal
                _SupportCard(
                  icon: Icons.payment_rounded,
                  title: l10n.paypalTitle,
                  description: l10n.paypalDescription,
                  buttonLabel: l10n.paypalButton,
                  color: const Color(0xFF003087).withValues(alpha: 0.3),
                  onPressed: () => _launchUrl(paypalUrl),
                ),

                const SizedBox(height: 24),

                // Bitcoin
                _SupportCard(
                  icon: Icons.currency_bitcoin_rounded,
                  title: l10n.bitcoinTitle,
                  description: l10n.bitcoinDescription,
                  content: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            btcAddress,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.orangeAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.orangeAccent,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(text: btcAddress),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.bitcoinCopied),
                              ),
                            );
                          },
                          tooltip: l10n.copyAddress,
                        ),
                      ],
                    ),
                  ),
                  buttonLabel: l10n.copyAddress,
                  color: Colors.orangeAccent.withValues(alpha: 0.1),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: btcAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.bitcoinCopied),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),
                Text(
                  l10n.thanksForUsing,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Color color;
  final Widget? content;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.color,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          if (content != null) ...[const SizedBox(height: 16), content!],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
