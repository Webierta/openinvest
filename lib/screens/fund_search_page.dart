import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fund_provider.dart';
import '../services/fund_scraper.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';

class FundSearchPage extends StatefulWidget {
  const FundSearchPage({super.key});
  @override
  State<FundSearchPage> createState() => _FundSearchPageState();
}

class _FundSearchPageState extends State<FundSearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _searchTimer;
  List<FundSearchMatch> _matches = [];
  int _searchVersion = 0;

  Future<void> _searchByName(String value) async {
    final version = ++_searchVersion;
    _searchTimer?.cancel();
    if (value.trim().length < 2) {
      setState(() => _matches = []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final matches = await context.read<FundProvider>().searchFunds(value);
      if (mounted && version == _searchVersion) {
        setState(() => _matches = matches);
      }
    });
  }

  bool _looksLikeIsin(String value) =>
      RegExp(r'^[A-Za-z]{2}[A-Za-z0-9]{10}$').hasMatch(value.trim());

  Future<void> _handleSearch([FundSearchMatch? match]) async {
    final provider = context.read<FundProvider>();
    
    if (match == null && !_looksLikeIsin(_controller.text)) {
      await _searchByName(_controller.text);
      return;
    }

    // Ocultamos el teclado y limpiamos estados para asegurar que el indicador de carga sea visible
    FocusScope.of(context).unfocus();
    provider.clearError();
    setState(() {
      _matches = [];
    });

    if (match != null && match.isin == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ISIN no detectado'),
          content: const Text(
            'Yahoo Finance no ha proporcionado el código ISIN para este resultado. '
            'Intentaremos obtenerlo de los metadatos o usaremos el símbolo como identificador.\n\n'
            '¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final result = match == null
        ? await provider.fetchFundOnly(_controller.text)
        : await provider.fetchFundMatch(match);

    if (result.data != null && mounted) {
      final fund = result.data!;
      final bool isResolved = result.isResolved;
      final bool isValid = fund.hasValidIsin;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isValid ? 'Fondo Encontrado' : 'ISIN no disponible'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isValid ? 'Se ha encontrado el siguiente fondo:' : 'Este activo no proporciona un código ISIN válido y no puede ser añadido a la cartera.',
              ),
              const SizedBox(height: 16),
              Text(
                fund.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Text(
                    isValid ? fund.isin : 'ID: ${fund.symbol}',
                    style: TextStyle(
                      color: isValid ? Colors.grey : Colors.redAccent,
                    ),
                  ),
                  if (isResolved) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RESUELTO',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isValid) ...[
                const SizedBox(height: 16),
                const Text('¿Deseas añadirlo a tu cartera?'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cerrar'),
            ),
            if (isValid)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Añadir a Cartera'),
              ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final exists = provider.portfolio.any((item) => item.isin == fund.isin);
        // final exists = provider.portfolio.any(
        //   (item) => item.isin == resolverISIN,
        // );
        var overwrite = false;
        if (exists) {
          final decision = await _confirmOverwrite(context, fund.name);
          if (decision != true || !mounted) return;
          overwrite = true;
        }
        try {
          if (overwrite) {
            await provider.replaceFund(fund);
          } else {
            await provider.addToPortfolio(fund);
          }
        } catch (_) {
          return;
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FundDetailsPage()),
          );
        }
      }
    }
  }

  Future<bool?> _confirmOverwrite(BuildContext context, String fundName) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fondo ya existente'),
        content: Text(
          '$fundName ya está en tu cartera. ¿Quieres sobrescribirlo? Se eliminarán sus datos actuales, incluido el historial y las operaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sobrescribir',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showBadgeInfoDialog(context),
            tooltip: 'Información sobre resultados',
          ),
        ],
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
                  'Busca un fondo para añadirlo a tu cartera',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Nombre o código ISIN',
                    hintText: 'Ej: Amundi o ES0152743003',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          tooltip: 'Buscar fondo',
                          color: Theme.of(context).colorScheme.onPrimary,
                          icon: const Icon(Icons.search),
                          onPressed: _handleSearch,
                        ),
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _handleSearch(),
                  onChanged: _searchByName,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                if (_matches.isNotEmpty)
                  ..._matches.map(
                    (match) => Card(
                      color: match.isin == null
                          ? Colors.grey.withValues(alpha: 0.12)
                          : null,
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                match.name,
                                style: TextStyle(
                                  color: match.isin == null
                                      ? Colors.grey
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSourceBadge(match.source),
                          ],
                        ),
                        subtitle: Text(
                          match.isin == null
                              ? 'ISIN no disponible'
                              : '${match.isin}',
                          style: TextStyle(
                            color: match.isin == null ? Colors.grey : null,
                          ),
                        ),
                        trailing: Icon(
                          match.isin == null
                              ? Icons.search_off
                              : Icons.add_circle_outline,
                          color: match.isin == null ? Colors.grey : null,
                        ),
                        onTap: () => _handleSearch(match),
                      ),
                    ),
                  ),
                if (provider.isBusy)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 24),
                          const Text(
                            'Procesando fondo e identificando ISIN...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Esta operación puede tardar unos segundos',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  void _showBadgeInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Origen de los Datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadgeInfoItem(
              source: FundSource.local,
              title: 'Registro CNMV',
              description: 'Fondos españoles armonizados. Los datos provienen del catálogo oficial de la Comisión Nacional del Mercado de Valores.',
            ),
            const SizedBox(height: 20),
            _buildBadgeInfoItem(
              source: FundSource.global,
              title: 'Mercado Global',
              description: 'Fondos internacionales y ETFs. Los datos se obtienen de Yahoo Finance.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeInfoItem({
    required FundSource source,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSourceBadge(source),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(FundSource source) {
    final bool isLocal = source == FundSource.local;
    final Color color = isLocal ? const Color(0xFFA50A37) : Colors.blueAccent;
    final String label = isLocal ? 'CNMV' : 'GLOBAL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
