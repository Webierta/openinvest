import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/gradient_background.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Acerca de OpenInvest'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AboutItem(
                title: 'Licencia',
                content: 'Esta aplicación es Software Libre bajo la licencia GNU General Public License v3 (GPLv3).',
              ),
              _AboutItem(
                title: 'Código Abierto',
                content: 'El código fuente está disponible públicamente en nuestro repositorio de GitHub:\ngithub.com/Webierta/openinvest',
              ),
              _AboutItem(
                title: 'Fuente de Datos',
                content: 'Los datos financieros y cotizaciones se obtienen de Yahoo Finance. OpenInvest no se responsabiliza de la exactitud de los datos proporcionados por terceros.',
              ),
              _AboutItem(
                title: 'Permisos',
                content: '• Internet: Para descargar cotizaciones en tiempo real.\n• Almacenamiento: Para exportar e importar archivos JSON de copia de seguridad.',
              ),
              _AboutItem(
                title: 'Garantía y Responsabilidad',
                content: 'La aplicación se proporciona "tal cual", sin garantía de ningún tipo. No constituye asesoramiento financiero profesional. Invierte bajo tu propio riesgo.',
              ),
              _AboutItem(
                title: 'Privacidad y Seguridad',
                content: 'OpenInvest es una aplicación 100% gratuita y sin publicidad. No recopilamos datos personales. Toda tu información financiera se guarda exclusivamente de forma local en tu dispositivo.',
              ),
              SizedBox(height: 20),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version;
                  return Center(
                    child: Text(
                      'Versión ${version ?? '...'}\nWebierta.com',
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
