enum FundCategories {
  monetarios(name: 'MONETARIOS'),
  rentaFija(name: 'RENTA FIJA'),
  mixtos(name: 'MIXTOS'),
  rentaVariable(name: 'RENTA VARIABLE'),
  rentabilidadAbsoluta(name: 'RENTABILIDAD ABSOLUTA'),
  //garantizados(name: 'GARANTIZADOS'),
  //inversionLibre(name: 'INVERSIÓN LIBRE'),
  inmobiliarios(name: 'INMOBILIARIOS'),
  otros(name: 'OTROS');

  const FundCategories({required this.name});
  final String name;
}
