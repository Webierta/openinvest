import 'package:flutter/material.dart';
import '../widgets/gradient_background.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Información'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _InfoSection(
                icon: Icons.search,
                title: 'Búsqueda de Fondos',
                description: 'Busca cualquier fondo de inversión del mundo utilizando su código ISIN. Obtenemos los datos en tiempo real a través de fuentes públicas financieras.',
              ),
              _InfoSection(
                icon: Icons.history,
                title: 'Historial de Precios',
                description: 'Descarga el histórico de valores liquidativos (VL) para analizar la evolución temporal. Puedes seleccionar rangos de fechas personalizados.',
              ),
              _InfoSection(
                icon: Icons.account_balance_wallet,
                title: 'Gestión de Operaciones',
                description: 'Registra tus suscripciones (compras) y reembolsos (ventas). La aplicación calcula automáticamente tus participaciones totales y capital invertido.',
              ),
              _InfoSection(
                icon: Icons.trending_up,
                title: 'Análisis de Rentabilidad',
                description: 'Cálculo de índices avanzados:\n• TAE: Rentabilidad anualizada de tu bolsillo.\n• TWR: Rendimiento real del fondo (activo).\n• MWR/TIR: Tu éxito personal según el momento de inversión.',
              ),
              _InfoSection(
                icon: Icons.show_chart,
                title: 'Gráficos Interactivos',
                description: 'Visualiza la evolución de tus fondos con filtros de rango rápido (1M, 6M, 1Y, etc.) y líneas de tendencia media.',
              ),
              _InfoSection(
                icon: Icons.save_alt,
                title: 'Exportación e Importación',
                description: 'Lleva tus datos contigo. Exporta e importa tus fondos y operaciones en formato JSON para moverlos entre dispositivos o hacer copias de seguridad.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
