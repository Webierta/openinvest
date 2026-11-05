import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../widgets/gradient_background.dart';
import 'fund_search_page.dart';

class PortfolioHistoryFormPage extends StatefulWidget {
  const PortfolioHistoryFormPage({super.key});

  @override
  State<PortfolioHistoryFormPage> createState() =>
      _PortfolioHistoryFormPageState();
}

class _PortfolioHistoryFormPageState extends State<PortfolioHistoryFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _fundNameController = TextEditingController();
  final _isinController = TextEditingController();
  final _initialValueController = TextEditingController();
  final _finalValueController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  //final _dateFormat = DateFormat('dd/MM/yyyy');
  /* final _currencyFormat = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  ); */

  // GETTERS
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String get locale => Localizations.localeOf(context).toString();
  //NumberFormat get priceFormat => NumberFormat('#,##0.0000', locale);
  NumberFormat get percentFormat => NumberFormat('#,##0.00', locale);
  NumberFormat get smartFormat => NumberFormat('#,##0.##', locale);
  DateFormat get dateFormat => DateFormat.yMMMd(locale);

  double? get _initialValue => _parseAmount(_initialValueController.text);
  double? get _finalValue => _parseAmount(_finalValueController.text);

  double? get _returnPercent {
    final initial = _initialValue;
    final finalValue = _finalValue;

    if (initial == null ||
        finalValue == null ||
        initial <= 0 ||
        finalValue < 0) {
      return null;
    }

    return ((finalValue / initial) - 1) * 100;
  }

  double? _parseAmount(String value) {
    final normalized = value
        .trim()
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  @override
  void dispose() {
    _fundNameController.dispose();
    _isinController.dispose();
    _initialValueController.dispose();
    _finalValueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startDate ?? _endDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: isStart
          ? 'Seleccionar fecha de inicio'
          : 'Seleccionar fecha de fin',
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

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;

        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = null;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmount(value ?? '');

    if (amount == null) {
      return 'Introduce un importe válido';
    }

    if (!amount.isFinite || amount < 0) {
      return 'El importe no puede ser negativo';
    }

    return null;
  }

  void _savePrototype() {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona las fechas del periodo')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha de fin debe ser posterior a la de inicio'),
        ),
      );
      return;
    }

    if ((_initialValue ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El capital inicial debe ser mayor que cero'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Prototipo validado',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Los datos del formulario son válidos. '
          'En esta versión todavía no se guardan en la base de datos.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Aceptar', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
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
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Text(
                          'OpenInvest calcula la rentabilidad de la Cartera global en base a los fondos '
                          'que actualmente la componen. Pero si la inversión de alguno de estos fondos deriva de '
                          'un traspaso desde otro fondo, se pierde información acumulada por el fondo de origen. '
                          'También se pierde si se elimina un fondo con inversiones.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Para evitarlo, este regitro permite reconstruir el histórico de rentabilidades pasadas '
                          '(por ejemplo después de reembolsos o traspasos) e incorporarlas a los cálculos de '
                          'la Cartera aunque esos fondos no formen parte actualmente de la Cartera o nunca lo hicieran.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Esos cálculos serán una aproximación estimada de la rentabilidad simple calculada en base '
                          'a los importes invertido y resultante en el periodo de tiempo que dura la inversión.',
                          // ((valor final / capital inicial) - 1) × 100
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'OpenInvest permite registrar automáticamente en este histórico los fondos eliminados '
                          'y los traspasos entre fondos.',
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
    final returnPercent = _returnPercent;
    final returnColor = returnPercent == null
        ? Colors.white70
        : returnPercent >= 0
        ? Colors.greenAccent
        : Colors.redAccent[200]!;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('Nuevo registro histórico'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(onPressed: showInfo, icon: Icon(Icons.info_outline)),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _buildIntro(),
                const SizedBox(height: 20),
                // IDENTIFICACIÖN FONDO
                _buildSection(
                  title: 'Identificación',
                  icon: Icons.assessment,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _fundNameController,
                        label: 'Fondo de origen',
                        hint: 'Nombre del fondo',
                        icon: Icons.account_balance,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _isinController,
                        label: 'ISIN',
                        hint: 'Código identificativo (opcional)',
                        icon: Icons.tag,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // SELECTORES DE FECHAS
                _buildSection(
                  title: 'Periodo de inversión',
                  icon: Icons.date_range_outlined,
                  child: Column(
                    children: [
                      _buildDateField(
                        label: 'Fecha de inicio',
                        date: _startDate,
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _selectDate(isStart: true),
                      ),
                      const SizedBox(height: 12),
                      _buildDateField(
                        label: 'Fecha de fin',
                        date: _endDate,
                        icon: Icons.event_outlined,
                        onTap: () => _selectDate(isStart: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ENTRADA DE IMPORTES
                _buildSection(
                  title: 'Valor de la inversión',
                  icon: Icons.euro_outlined,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _initialValueController,
                        label: 'inversión inicial',
                        hint: '0,00 €',
                        icon: Icons.input,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final error = _validateAmount(value);
                          if (error != null) return error;
                          if ((_parseAmount(value ?? '') ?? 0) <= 0) {
                            return 'Debe ser mayor que cero';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _finalValueController,
                        label: 'Capital al cierre',
                        hint: '0,00 €',
                        icon: Icons.output,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateAmount,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // RENTABILIDAD ESTIMADA
                _buildReturnCard(returnPercent, returnColor),
                const SizedBox(height: 24),
                // BOTONES
                Row(
                  mainAxisAlignment: .spaceAround,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _savePrototype,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'Guardar histórico',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          //backgroundColor: Colors.amber,
                          //foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.history, color: Colors.amber, size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conserva la historia de tu inversión',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Registra un periodo cerrado para mantener '
                  'su rentabilidad en el histórico de la Cartera.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (title == 'Identificación') ...[
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    final searchFund = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const FundSearchPage(isOnlySearch: true),
                      ),
                    );
                    if (searchFund != null) {
                      _fundNameController.text = searchFund.name ?? '';
                      _isinController.text = searchFund.isin ?? '';
                    }
                  },
                  icon: Icon(Icons.search),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber, width: 1.2),
        ),
        errorMaxLines: 2,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          date == null ? 'Seleccionar fecha' : dateFormat.format(date),
          style: TextStyle(
            color: date == null ? Colors.white38 : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildReturnCard(double? returnPercent, Color returnColor) {
    final returnText = returnPercent == null
        ? '—'
        : '${returnPercent >= 0 ? '+' : ''}'
              '${percentFormat.format(returnPercent)} %';

    /* : '${returnPercent >= 0 ? '+' : ''}'
              '${returnPercent.toStringAsFixed(2)} %'; */

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.show_chart, color: Colors.amber),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rentabilidad estimada',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'Periodo completo',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            returnText,
            style: TextStyle(
              color: returnColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
