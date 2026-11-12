import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../providers/fund_provider.dart';
import '../services/database_service.dart';
import '../utils/historical_investment_validator.dart';
import '../widgets/gradient_background.dart';
import '../widgets/historical_operation_dialog.dart';
import 'fund_search_page.dart';
import 'historical_investments_page.dart';

typedef HistoricalInvestmentSaver = Future<void> Function(
  HistoricalInvestment investment,
  List<HistoricalOperation> operations,
);

class HistoricalInvestmentFormPage extends StatefulWidget {
  const HistoricalInvestmentFormPage({super.key, this.saveInvestment});

  final HistoricalInvestmentSaver? saveInvestment;

  @override
  State<HistoricalInvestmentFormPage> createState() =>
      _HistoricalInvestmentFormPageState();
}

class _HistoricalInvestmentFormPageState
    extends State<HistoricalInvestmentFormPage> {
  late final String _investmentUid;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _isinController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<HistoricalOperationDraft> _operations = [];

  bool _saving = false;
  static int _uidCounter = 0;

  String get _locale => Localizations.localeOf(context).toString();

  DateFormat get _dateFormat => DateFormat.yMMMd(_locale);

  @override
  void initState() {
    super.initState();
    _investmentUid = _newUid('investment');
  }

  String _newUid(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '_${_uidCounter++}';
  }

  double? _parseNumber(String value) {
    var normalized = value.trim().replaceAll(' ', '').replaceAll('€', '');
    // Si hay coma, asumimos formato español:
    // 1.234,56 -> 1234.56
    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  String? _validateNumber(String? value, {required String label}) {
    final number = _parseNumber(value ?? '');
    if (number == null || !number.isFinite || number < 0) {
      return 'Introduce un $label válido';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isinController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _searchFund() async {
    final fund = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FundSearchPage(isOnlySearch: true),
      ),
    );
    if (fund == null || !mounted) return;
    setState(() {
      _nameController.text = fund.name ?? '';
      _isinController.text = fund.isin ?? '';
    });
  }

  Future<DateTime?> _pickDate(DateTime initialDate) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha de la operación',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _addOperation() async {
    final draft = await _showOperationDialog();
    if (draft == null || !mounted) return;
    setState(() => _operations.add(draft));
  }

  Future<void> _editOperation(int index) async {
    final draft = await _showOperationDialog(operation: _operations[index]);
    if (draft == null || !mounted) return;
    setState(() => _operations[index] = draft);
  }

  Future<HistoricalOperationDraft?> _showOperationDialog({
    HistoricalOperationDraft? operation,
  }) async {
    List<HistoricalOperation> transferOperations = [];
    Map<String, String> investmentNames = {};

    // En el modo de guardado inyectado (aislamiento de pruebas),
    // no se consulta SQLite para cargar los posibles traspasos.
    if (widget.saveInvestment == null) {
      final investments = await DatabaseService.getHistoricalInvestments();

      final groups = await Future.wait(
        investments.map(
          (investment) =>
              DatabaseService.getHistoricalOperations(investment.uid),
        ),
      );

      transferOperations = groups.expand((group) => group).toList();

      investmentNames = {
        for (final investment in investments) investment.uid: investment.name,
      };
    }

    if (!mounted) return null;

    return showDialog<HistoricalOperationDraft>(
      context: context,
      builder: (_) => HistoricalOperationDialog(
        operation: operation,
        dateFormat: _dateFormat,
        pickDate: _pickDate,
        parseNumber: _parseNumber,
        validateNumber: _validateNumber,
        generateTransferUid: () => _newUid('transfer'),
        receivingInvestmentUid: _investmentUid,
        transferOperations: transferOperations,
        investmentNames: investmentNames,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_operations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos una operación histórica')),
      );
      return;
    }

    setState(() => _saving = true);

    final investmentUid = _investmentUid;

    try {
      final investment = HistoricalInvestment(
        uid: investmentUid,
        name: _nameController.text,
        isin: _isinController.text.trim().isEmpty
            ? null
            : _isinController.text.trim().toUpperCase(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      final operations = _operations.map((draft) {
        return HistoricalOperation(
          uid: _newUid('operation'),
          investmentUid: investmentUid,
          date: draft.date,
          type: draft.type,
          amount: draft.amount,
          units: draft.units,
          price: draft.price,
          description: draft.description,
          transferUid: draft.transferUid,
        );
      }).toList();

      HistoricalInvestmentValidator.validate(operations);

      final saveInvestment =
          widget.saveInvestment ??
          DatabaseService.saveHistoricalInvestmentWithOperations;

      await saveInvestment(investment, operations);

      // La recarga de cartera corresponde al flujo de persistencia real.
      // Cuando se inyecta un saver (por ejemplo, en los tests), no se
      // fuerza una recarga adicional del proveedor.
      if (widget.saveInvestment == null && mounted) {
        await context.read<FundProvider>().loadPortfolio();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inversión histórica guardada correctamente'),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HistoricalInvestmentsPage()),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el histórico: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: .circular(12),
        borderSide: .none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: .circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: .circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
      errorMaxLines: 2,
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.88),
        borderRadius: .circular(18),
        border: .all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: .bold,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInvestmentFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Nombre de la inversión'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Introduce un nombre para la inversión';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _isinController,
          textCapitalization: .characters,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('ISIN (opcional)'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Descripción (opcional)'),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildOperationList() {
    if (_operations.isEmpty) {
      return const Padding(
        padding: .symmetric(vertical: 18),
        child: Center(
          child: Text(
            'Todavía no hay operaciones.\nAñade la primera para construir el histórico.',
            textAlign: .center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_operations.length, (index) {
        final operation = _operations[index];

        final title = switch (operation.type) {
          HistoricalOperationType.subscription => 'Suscripción',
          HistoricalOperationType.redemption => 'Reembolso',
          HistoricalOperationType.transferIn => 'Traspaso de entrada',
          HistoricalOperationType.transferOut => 'Traspaso de salida',
        };

        return Card(
          color: const Color(0xFF0F172A),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withValues(alpha: 0.12),
              child: Icon(
                operation.type == HistoricalOperationType.redemption ||
                        operation.type == HistoricalOperationType.transferOut
                    ? Icons.south_west
                    : Icons.north_east,
                color: Colors.amber,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: .w600),
            ),
            subtitle: Text(
              '${_dateFormat.format(operation.date)}'
              '${operation.description == null ? '' : '\n${operation.description}'}',
              style: const TextStyle(color: Colors.white60),
            ),
            isThreeLine: operation.description != null,
            trailing: Row(
              mainAxisSize: .min,
              children: [
                Text(
                  NumberFormat.currency(
                    locale: _locale,
                    symbol: '€',
                  ).format(operation.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: .bold,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editOperation(index);
                    } else if (value == 'delete') {
                      setState(() => _operations.removeAt(index));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void showInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: GradientBackground(
            child: SafeArea(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  title: Text('Histórico de inversiones'),
                ),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const .all(14),
                    child: Column(
                      children: [
                        Text(
                          'OpenInvest calcula la rentabilidad de la Cartera global en base a los fondos '
                          'que actualmente la componen. Pero cuando la inversión de alguno de estos fondos deriva de '
                          'un traspaso desde otro fondo, se pierde información acumulada por el fondo de origen. '
                          'También se pierde si se elimina un fondo con inversiones.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Para evitarlo, este regitro permite reconstruir el histórico de inversiones pasadas '
                          '(por ejemplo después de reembolsos o traspasos) e incorporar sus rentabilidades a los cálculos de '
                          'la Cartera aunque esos fondos no formen parte actualmente de la Cartera o nunca lo hicieran.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('Nueva inversión histórica'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(onPressed: showInfo, icon: Icon(Icons.info_outline)),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoricalInvestmentsPage(),
                ),
              );
            },
            icon: Icon(Icons.history),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // IDENTIFICACIÖN FONDO
                _buildSection(
                  title: 'Identificación',
                  icon: Icons.account_balance,
                  action: IconButton(
                    tooltip: 'Buscar fondo',
                    onPressed: _searchFund,
                    icon: const Icon(Icons.search, color: Colors.amber),
                  ),
                  child: _buildInvestmentFields(),
                ),
                const SizedBox(height: 16),
                // OPERACIONES
                _buildSection(
                  title: 'Operaciones históricas',
                  icon: Icons.history,
                  action: IconButton(
                    tooltip: 'Añadir operación',
                    onPressed: _addOperation,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.amber,
                    ),
                  ),
                  child: _buildOperationList(),
                ),
                const SizedBox(height: 24),
                // BOTONES
                Row(
                  mainAxisAlignment: .spaceAround,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'Guardando…' : 'Guardar',
                        style: const TextStyle(fontSize: 16, fontWeight: .bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
