import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fund_provider.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';

class FundSearchPage extends StatefulWidget {
  const FundSearchPage({super.key});
  @override
  State<FundSearchPage> createState() => _FundSearchPageState();
}

class _FundSearchPageState extends State<FundSearchPage> {
  final TextEditingController _controller = TextEditingController();
  Future<void> _handleSearch() async {
    final provider = context.read<FundProvider>();
    final result = await provider.fetchFundOnly(_controller.text);
    if (result.data != null && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fondo Encontrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se ha encontrado el siguiente fondo:'),
              const SizedBox(height: 16),
              Text(
                result.data!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                result.data!.isin,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('¿Deseas añadirlo a tu cartera?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Añadir a Cartera'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await provider.addToPortfolio(result.data!);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FundDetailsPage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Añadir Fondo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.search_rounded,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Introduce el ISIN para añadirlo a tu cartera',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Código ISIN',
                    hintText: 'Ej: ES0152743003',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _handleSearch,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _handleSearch(),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                if (provider.isBusy)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else if (provider.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
