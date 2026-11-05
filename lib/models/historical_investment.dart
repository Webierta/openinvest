class HistoricalInvestment {
  final int? id;
  final String uid;
  final String name;
  final String? isin;
  final String? description;

  HistoricalInvestment({
    this.id,
    required this.uid,
    String? name,
    this.isin,
    this.description,
  }) : name = (name == null || name.trim().isEmpty)
           ? 'No especificado'
           : name.trim() {
    _validate();
  }

  static const Object _unset = Object();

  HistoricalInvestment copyWith({
    int? id,
    String? uid,
    String? name,
    Object? isin = _unset,
    Object? description = _unset,
  }) {
    return HistoricalInvestment(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      isin: identical(isin, _unset) ? this.isin : isin as String?,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
    );
  }

  void _validate() {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El UID de la inversión no puede estar vacío');
    }
  }
}
