import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../models/fund_data.dart';
import '../models/fund_search_mode.dart';
import '../providers/fund_provider.dart';
import '../utils/isin_search_query.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';

enum _SearchStatus { initial, invalidQuery, searching, completed }

class FundSearchPage extends StatefulWidget {
  const FundSearchPage({super.key});

  @override
  State<FundSearchPage> createState() => _FundSearchPageState();
}

class _FundSearchPageState extends State<FundSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<FundSearchMatch> _matches = [];
  FundSearchMode _selectedMode = FundSearchMode.name;
  String? _searchWarning;
  _SearchStatus _searchStatus = _SearchStatus.initial;
  int _searchGeneration = 0;

  Future<void> _search(String value) async {
    final generation = ++_searchGeneration;
    final l10n = AppLocalizations.of(context)!;
    final minimumLength = _selectedMode == FundSearchMode.isin ? 5 : 2;
    if (value.trim().length < minimumLength) {
      setState(() {
        _matches = [];
        _searchStatus = _SearchStatus.invalidQuery;
        _searchWarning = _selectedMode == FundSearchMode.isin
            ? l10n.fundSearchIsinTooShort
            : l10n.fundSearchNameTooShort;
      });
      return;
    }

    if (_selectedMode == FundSearchMode.isin &&
        IsinSearchQuery.prefix(value) == null) {
      final normalized = IsinSearchQuery.normalize(value);
      setState(() {
        _matches = [];
        _searchStatus = _SearchStatus.invalidQuery;
        _searchWarning = normalized.length >= 12
            ? l10n.fundSearchInvalidIsinComplete
            : l10n.fundSearchInvalidIsinPrefix;
      });
      return;
    }

    setState(() {
      _searchStatus = _SearchStatus.searching;
      _searchWarning = null;
    });
    final matches = await context.read<FundProvider>().searchFunds(
      value,
      mode: _selectedMode,
    );
    if (!mounted || generation != _searchGeneration) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _matches = matches;
      _searchStatus = _SearchStatus.completed;
    });
  }

  Future<void> _handleSearch([FundSearchMatch? match]) async {
    final provider = context.read<FundProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (match == null) {
      await _search(_controller.text);
      return;
    }

    // Ocultamos el teclado y limpiamos estados para asegurar que
    // el indicador de carga sea visible
    FocusScope.of(context).unfocus();
    provider.clearError();

    if (match.isin == null) {
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
      if (confirm != true) {
        return;
      }
    }

    final result = await provider.fetchFundMatch(match);

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
        var overwrite = false;
        if (exists) {
          final decision = await _confirmOverwrite(context, fund.name);
          if (decision != true || !mounted) {
            //restoreMatches();
            return;
          }
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
    _controller.dispose();
    super.dispose();
  }

  void resetSearch() {
    setState(() {
      _searchStatus = _SearchStatus.initial;
      _matches = [];
      _searchWarning = null;
    });
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
                Text(
                  l10n.fundSearchModeLabel,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<FundSearchMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: FundSearchMode.name,
                        label: Text(l10n.fundSearchNameOption),
                      ),
                      ButtonSegment(
                        value: FundSearchMode.isin,
                        label: Text(l10n.fundSearchIsinOption),
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      setState(() {
                        _searchGeneration++;
                        _selectedMode = selection.first;
                        _controller.clear();
                        _matches = [];
                        _searchStatus = _SearchStatus.initial;
                        _searchWarning = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: _selectedMode == FundSearchMode.name
                        ? l10n.fundSearchNameLabel
                        : l10n.fundSearchIsinLabel,
                    hintText: _selectedMode == FundSearchMode.name
                        ? l10n.fundSearchNameHint
                        : l10n.fundSearchIsinHint,
                    errorText: _searchWarning,
                    errorMaxLines: 3,
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
                  textCapitalization: _selectedMode == FundSearchMode.isin
                      ? TextCapitalization.characters
                      : TextCapitalization.words,
                  onSubmitted: (_) => _handleSearch(),
                  onChanged: (_) {
                    if (_searchWarning != null ||
                        _searchStatus != _SearchStatus.initial) {
                      resetSearch();
                    }
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                if (_searchStatus == _SearchStatus.initial)
                // estado inicial
                ...[
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
                ] else if (_matches.isNotEmpty && provider.isBusy)
                  // nueva búsqueda sobre resultados
                  ProviderIsBusy(l10n: l10n)
                else if (_matches.isNotEmpty)
                  // resultados
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
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                match.isin == null
                                    ? l10n.isinNotAvailable
                                    : '${match.isin}',
                                style: TextStyle(
                                  color: match.isin == null
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                            ),
                            //const SizedBox(width: 8),
                            _buildSourceBadge(match.source),
                          ],
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
                  )
                else if (provider.isBusy)
                  // buscando / procesando
                  ProviderIsBusy(l10n: l10n)
                else if (provider.error != null)
                  // error
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
                  )
                else if (_searchStatus == _SearchStatus.completed)
                  // sin resultados
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l10n.noFundSearchResults,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
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
                source: FundSource.ecb,
                title: l10n.ecbSource,
                description: l10n.ecbSourceDesc,
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
      case FundSource.ecb:
        color = Colors.deepPurpleAccent;
        label = 'ECB';
        break;
      case FundSource.morningstar:
        color = Colors.orangeAccent;
        label = 'MORNINGSTAR';
        break;
      case FundSource.yahoo:
        color = Colors.blueAccent;
        label = 'YAHOO';
        break;
      case FundSource.queFondos:
        color = Colors.green;
        label = 'QUEFONDOS';
      case FundSource.financialTimes:
        color = Colors.brown;
        label = 'FT';
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

class ProviderIsBusy extends StatelessWidget {
  const new({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
