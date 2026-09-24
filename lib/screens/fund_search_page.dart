import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

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
          title: Text(l10n.isinNotDetected),
          content: Text(l10n.isinNotDetectedDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.continueText),
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
          title: Text(isValid ? l10n.fundFound : l10n.isinNotAvailable),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isValid ? l10n.fundFoundDesc : l10n.noValidIsinDesc),
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
                      child: Text(
                        l10n.resolved,
                        style: const TextStyle(
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
                Text(l10n.addToPortfolioPrompt),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.close),
            ),
            if (isValid)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.addToPortfolioAction),
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
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.fundAlreadyInPortfolio),
        content: Text(l10n.overwriteFundDesc(fundName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.overwrite,
              style: const TextStyle(color: Colors.redAccent),
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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.addFund),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showBadgeInfoDialog(context),
            tooltip: l10n.resultsInfo,
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
                Text(
                  l10n.searchFundPrompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.fundSearchLabel,
                    hintText: l10n.fundSearchHint,
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
                          tooltip: l10n.searchFundAction,
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
                              ? l10n.isinNotAvailable
                              : '${match.isin}',
                          style: TextStyle(
                            color: match.isin == null ? Colors.grey : null,
                          ),
                        ),
                        trailing: Icon(
                          match.isin == null
                              ? Icons.search
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
                          Text(
                            l10n.processingFund,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.processingWait,
                            style: const TextStyle(
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataSource),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadgeInfoItem(
                source: FundSource.cnmv,
                title: l10n.cnmvRegistry,
                description: l10n.cnmvDesc,
              ),
              const SizedBox(height: 16),
              _buildBadgeInfoItem(
                source: FundSource.local,
                title: l10n.localCatalog,
                description: l10n.localCatalogDesc,
              ),
              const SizedBox(height: 16),
              _buildBadgeInfoItem(
                source: FundSource.morningstar,
                title: l10n.morningstarSource,
                description: l10n.morningstarSourceDesc,
              ),
              const SizedBox(height: 16),
              _buildBadgeInfoItem(
                source: FundSource.yahoo,
                title: l10n.yahooSource,
                description: l10n.yahooSourceDesc,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSourceBadge(source),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(FundSource source) {
    Color color;
    String label;
    switch (source) {
      case FundSource.cnmv:
        color = const Color(0xFFA50A37);
        label = 'CNMV';
        break;
      case FundSource.local:
        color = Colors.teal;
        label = 'LOCAL';
        break;
      case FundSource.morningstar:
        color = Colors.orangeAccent;
        label = 'MORNINGSTAR';
        break;
      case FundSource.yahoo:
        color = Colors.blueAccent;
        label = 'YAHOO';
        break;
    }

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
