import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../services/database_service.dart';
import '../widgets/gradient_background.dart';

class HistoricalInvestmentsPage extends StatefulWidget {
  const HistoricalInvestmentsPage({super.key});

  @override
  State<HistoricalInvestmentsPage> createState() =>
      _HistoricalInvestmentsPageState();
}

class _HistoricalInvestmentsPageState extends State<HistoricalInvestmentsPage> {
  late Future<List<HistoricalInvestment>> _investmentsFuture;

  final _numberFormat = NumberFormat('#,##0.00', 'es_ES');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  void _loadInvestments() {
    _investmentsFuture = DatabaseService.getHistoricalInvestments();
  }

  Future<void> _refresh() async {
    setState(_loadInvestments);
    await _investmentsFuture;
  }

  String _operationTypeLabel(HistoricalOperationType type) {
    switch (type) {
      case HistoricalOperationType.subscription:
        return 'Suscripción';
      case HistoricalOperationType.redemption:
        return 'Reembolso';
      case HistoricalOperationType.transferIn:
        return 'Traspaso recibido';
      case HistoricalOperationType.transferOut:
        return 'Traspaso enviado';
    }
  }

  IconData _operationTypeIcon(HistoricalOperationType type) {
    switch (type) {
      case HistoricalOperationType.subscription:
        return Icons.add_circle_outline;
      case HistoricalOperationType.redemption:
        return Icons.remove_circle_outline;
      case HistoricalOperationType.transferIn:
        return Icons.call_received;
      case HistoricalOperationType.transferOut:
        return Icons.call_made;
    }
  }

  Widget _buildOperation(HistoricalOperation operation) {
    return ListTile(
      dense: true,
      leading: Icon(_operationTypeIcon(operation.type), size: 21),
      title: Text(_operationTypeLabel(operation.type)),
      subtitle: Text(
        [
          _dateFormat.format(operation.date),
          if (operation.units != null)
            '${_numberFormat.format(operation.units)} participaciones',
          if (operation.price != null)
            'Precio: ${_numberFormat.format(operation.price)}',
          if (operation.description?.isNotEmpty == true) operation.description!,
        ].join(' · '),
      ),
      trailing: Text(
        _numberFormat.format(operation.amount),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInvestment(HistoricalInvestment investment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: FutureBuilder<List<HistoricalOperation>>(
        future: DatabaseService.getHistoricalOperations(investment.uid),
        builder: (context, snapshot) {
          final operations = snapshot.data ?? [];

          return ExpansionTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(
              investment.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (investment.isin?.isNotEmpty == true) investment.isin!,
                '${operations.length} operaciones',
              ].join(' · '),
            ),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (snapshot.hasError)
                const ListTile(title: Text('Error al cargar las operaciones'))
              else if (operations.isEmpty)
                const ListTile(title: Text('No hay operaciones registradas'))
              else
                ...operations.map(_buildOperation),
              if (investment.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      investment.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de inversiones')),
      body: GradientBackground(
        child: FutureBuilder<List<HistoricalInvestment>>(
          future: _investmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el histórico'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(_loadInvestments);
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final investments = snapshot.data ?? [];

            if (investments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay inversiones históricas guardadas.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: investments.length,
                itemBuilder: (context, index) {
                  return _buildInvestment(investments[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
