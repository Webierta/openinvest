// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'OpenInvest';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'Inglés';

  @override
  String get security => 'Seguridad';

  @override
  String get protectedAccess => 'Acceso Protegido';

  @override
  String get supportOpenInvest => 'Apoyar OpenInvest';

  @override
  String get helloDeveloper => '¡Hola! Soy el desarrollador de OpenInvest';

  @override
  String get supportDescription =>
      'OpenInvest es una herramienta de código abierto creada para ayudar a los inversores a gestionar sus carteras de forma gratuita y privada. Si la aplicación te resulta útil, considera apoyarla para asegurar su mantenimiento y evolución futura.';

  @override
  String get githubTitle => 'Enviar Sugerencias o Errores';

  @override
  String get githubDescription =>
      '¿Tienes alguna idea para mejorar o has encontrado un fallo? Cuéntamelo en el repositorio oficial.';

  @override
  String get githubButton => 'Ir a GitHub';

  @override
  String get paypalTitle => 'Donar vía PayPal';

  @override
  String get paypalDescription =>
      'Las donaciones ayudan a cubrir los costes de desarrollo y servidores de información.';

  @override
  String get paypalButton => 'Donar con PayPal';

  @override
  String get bitcoinTitle => 'Donar vía Bitcoin';

  @override
  String get bitcoinDescription =>
      'También puedes enviar tu apoyo a través de la red Bitcoin.';

  @override
  String get copyAddress => 'Copiar Dirección';

  @override
  String get bitcoinCopied => 'Dirección Bitcoin copiada al portapapeles';

  @override
  String get thanksForUsing => '¡Muchas gracias por usar OpenInvest!';

  @override
  String get authFailed => 'Autenticación fallida o cancelada';

  @override
  String get setAppPassword => 'Establecer Contraseña';

  @override
  String get setAppPasswordDescription =>
      'Define una contraseña para proteger el acceso a OpenInvest en este equipo.';

  @override
  String get password => 'Contraseña';

  @override
  String get minCharacters => 'Mínimo 4 caracteres';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get requirePasswordSubtitle =>
      'Requerir contraseña de aplicación para entrar.';

  @override
  String get requireBiometricSubtitle =>
      'Requerir huella, rostro o PIN del dispositivo para entrar.';

  @override
  String get noBiometricSupport =>
      'Tu dispositivo no soporta autenticación biométrica.';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get data => 'Datos';

  @override
  String get autoRefreshTitle => 'Actualizar fondos al iniciar';

  @override
  String get autoRefreshSubtitle =>
      'Actualizar cuando los datos tengan al menos un día y no se hayan actualizado en las últimas 24 horas.';

  @override
  String get protectedAccessTitle => 'Acceso protegido';

  @override
  String get appPasswordLabel => 'Contraseña de la aplicación';

  @override
  String get enterPasswordError => 'Introduce la contraseña';

  @override
  String get enter => 'Entrar';

  @override
  String get authRequiredDescription =>
      'Por favor, autentícate para continuar.';

  @override
  String get retry => 'Reintentar';

  @override
  String get info => 'Información';

  @override
  String get searchFundsTitle => 'Búsqueda de Fondos';

  @override
  String get searchFundsDesc =>
      'Busca cualquier fondo de inversión del mundo utilizando su código ISIN. Obtenemos los datos en tiempo real a través de fuentes públicas financieras.';

  @override
  String get priceHistoryTitle => 'Historial de Precios';

  @override
  String get priceHistoryDesc =>
      'Descarga el histórico de valores liquidativos (VL) para analizar la evolución temporal. Puedes seleccionar rangos de fechas personalizados.';

  @override
  String get operationsMgmtTitle => 'Gestión de Operaciones';

  @override
  String get operationsMgmtDesc =>
      'Registra tus suscripciones (compras) y reembolsos (ventas). La aplicación calcula automáticamente tus participaciones totales y capital invertido.';

  @override
  String get profitabilityAnalysisTitle => 'Análisis de Rentabilidad';

  @override
  String get profitabilityAnalysisDesc =>
      'Cálculo de índices avanzados:\n• TAE: Rentabilidad anualizada de tu bolsillo.\n• TWR: Rendimiento real del fondo (activo).\n• MWR/TIR: Tu éxito personal según el momento de inversión.';

  @override
  String get costsAuditTitle => 'Auditoría de Costes';

  @override
  String get costsAuditDesc =>
      'Introduce los Gastos Corrientes (TER) y la Comisión de Éxito de tus fondos para calcular la Ganancia Real neta, descontando el impacto de las comisiones en tu capital.';

  @override
  String get interactiveChartsTitle => 'Gráficos Interactivos';

  @override
  String get interactiveChartsDesc =>
      'Visualiza la evolución de tus fondos con filtros de rango rápido (1M, 6M, 1Y, etc.) y líneas de tendencia media.';

  @override
  String get monthlyHeatmapTitle => 'Mapa de Calor Mensual';

  @override
  String get monthlyHeatmapDesc =>
      'Analiza la estacionalidad de tus inversiones con una cuadrícula de rentabilidades mes a mes y acumulados anuales, identificando periodos de éxito y correcciones.';

  @override
  String get benchmarkComparisonTitle => 'Comparación con Benchmarks';

  @override
  String get benchmarkComparisonDesc =>
      'Superpón la evolución de los principales índices mundiales (S&P 500, MSCI World, etc.) sobre el gráfico del fondo para medir su rendimiento relativo en porcentaje.';

  @override
  String get riskAnalysisTitle => 'Análisis de Riesgo';

  @override
  String get riskAnalysisDesc =>
      'Métricas de nivel profesional para evaluar la seguridad:\n• Max Drawdown: La mayor caída histórica desde un pico.\n• Recuperación: Tiempo que el fondo tarda en sanar sus pérdidas.';

  @override
  String get exportImportTitle => 'Exportación e Importación';

  @override
  String get exportImportDesc =>
      'Lleva tus datos contigo. Exporta e importa tus fondos y operaciones en formato JSON para moverlos entre dispositivos o hacer copias de seguridad.';

  @override
  String get multicurrencySupportTitle => 'Soporte Multidivisa';

  @override
  String get multicurrencySupportDesc =>
      'Gestión automática de fondos en diversas divisas con conversión en tiempo real para una valoración precisa de tu cartera global.';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsDesc =>
      'Configura alertas personalizadas para mantenerte informado sobre tus fondos y objetivos financieros.';

  @override
  String get about => 'Acerca de';

  @override
  String get support => 'Apoyar';

  @override
  String get exit => 'Salir';

  @override
  String get aboutOpenInvest => 'Acerca de OpenInvest';

  @override
  String get licenseTitle => 'Licencia';

  @override
  String get licenseDesc =>
      'Esta aplicación es Software Libre bajo la licencia GNU General Public License v3 (GPLv3).';

  @override
  String get openSourceTitle => 'Código Abierto';

  @override
  String get openSourceDesc =>
      'El código fuente está disponible públicamente en nuestro repositorio de GitHub:\ngithub.com/Webierta/openinvest';

  @override
  String get dataSourceTitle => 'Fuente de Datos';

  @override
  String get dataSourceDesc =>
      'Los datos financieros y cotizaciones se obtienen de Yahoo Finance. OpenInvest no se responsabiliza de la exactitud de los datos proporcionados por terceros.';

  @override
  String get permissionsTitle => 'Permisos';

  @override
  String get permissionsDesc =>
      '• Internet: Para descargar cotizaciones en tiempo real.\n• Almacenamiento: Para exportar e importar archivos JSON de copia de seguridad.';

  @override
  String get warrantyTitle => 'Garantía y Responsabilidad';

  @override
  String get warrantyDesc =>
      'La aplicación se proporciona \"tal cual\", sin garantía de ningún tipo. No constituye asesoramiento financiero profesional. Invierte bajo tu propio riesgo.';

  @override
  String get privacyTitle => 'Privacidad y Seguridad';

  @override
  String get privacyDesc =>
      'OpenInvest es una aplicación 100% gratuita y sin publicidad. No recopilamos datos personales. Toda tu información financiera se guarda exclusivamente de forma local en tu dispositivo.';

  @override
  String get versionLabel => 'Versión';

  @override
  String get addFund => 'Añadir Fondo';

  @override
  String get resultsInfo => 'Información sobre resultados';

  @override
  String get searchFundPrompt => 'Busca un fondo para añadirlo a tu cartera';

  @override
  String get fundSearchLabel => 'Nombre o código ISIN';

  @override
  String get fundSearchHint => 'Ej: Amundi o ES0152743003';

  @override
  String get searchFundAction => 'Buscar fondo';

  @override
  String get isinNotAvailable => 'ISIN no disponible';

  @override
  String get fundFound => 'Fondo Encontrado';

  @override
  String get fundFoundDesc => 'Se ha encontrado el siguiente fondo:';

  @override
  String get noValidIsinDesc =>
      'Este activo no proporciona un código ISIN válido y no puede ser añadido a la cartera.';

  @override
  String get resolved => 'RESUELTO';

  @override
  String get addToPortfolioPrompt => '¿Deseas añadirlo a tu cartera?';

  @override
  String get close => 'Cerrar';

  @override
  String get addToPortfolioAction => 'Añadir a Cartera';

  @override
  String get fundAlreadyInPortfolio => 'Fondo ya existente';

  @override
  String overwriteFundDesc(String fundName) {
    return '$fundName ya está en tu cartera. ¿Quieres sobrescribirlo? Se eliminarán sus datos actuales, incluido el historial y las operaciones.';
  }

  @override
  String get overwrite => 'Sobrescribir';

  @override
  String get processingFund => 'Procesando fondo e identificando ISIN...';

  @override
  String get processingWait => 'Esta operación puede tardar unos segundos';

  @override
  String get dataSource => 'Origen de los Datos';

  @override
  String get cnmvRegistry => 'Registro CNMV';

  @override
  String get cnmvDesc =>
      'Fondos españoles armonizados. Los datos provienen del catálogo oficial de la Comisión Nacional del Mercado de Valores.';

  @override
  String get globalMarket => 'Mercado Global';

  @override
  String get globalMarketDesc =>
      'Fondos internacionales y ETFs. Los datos se obtienen de Yahoo Finance.';

  @override
  String get isinNotDetected => 'ISIN no detectado';

  @override
  String get isinNotDetectedDesc =>
      'Yahoo Finance no ha proporcionado el código ISIN para este resultado. Intentaremos obtenerlo de los metadatos o usaremos el símbolo como identificador.\n\n¿Deseas continuar?';

  @override
  String get continueText => 'Continuar';

  @override
  String get global => 'GLOBAL';

  @override
  String get updatePortfolioTooltip => 'Actualizar toda la cartera';

  @override
  String get sortPortfolioTooltip => 'Ordenar cartera';

  @override
  String get sortByAlpha => 'Nombre';

  @override
  String get sortByValue => 'Valor';

  @override
  String get sortByPerformance => 'TAE';

  @override
  String get moreOptionsTooltip => 'Más opciones';

  @override
  String get importFundJson => 'Importar fondo (JSON)';

  @override
  String get fundImportedSuccess => 'Fondo importado correctamente';

  @override
  String get clearPortfolioTitle => 'Vaciar Cartera';

  @override
  String get clearPortfolioConfirm =>
      '¿Estás seguro de que quieres eliminar todos los fondos de tu cartera?';

  @override
  String get clearPortfolioAction => 'Vaciar cartera';

  @override
  String get delete => 'Eliminar';

  @override
  String get portfolioLoadError =>
      'No se pudieron cargar los datos de la cartera.';

  @override
  String get emptyPortfolio => 'Tu cartera está vacía.';

  @override
  String get addFirstFund => 'Añadir mi primer fondo';

  @override
  String get portfolioSummary => 'RESUMEN DE CARTERA';

  @override
  String get invested => 'Invertido';

  @override
  String get gain => 'GANANCIA';

  @override
  String get totalGain => 'GANANCIA TOTAL';

  @override
  String get valueLabel => 'VALOR';

  @override
  String get performanceLabel => 'RENDIMIENTO';

  @override
  String get weightLabel => 'Peso';

  @override
  String get noQuoteData => 'Sin datos de cotización.';

  @override
  String get navLabel => 'Valor Liquidativo';

  @override
  String get toHighsLabel => 'A máximos';

  @override
  String get totalVariationLabel => 'Variación Total';

  @override
  String get sinceLabel => 'Desde';

  @override
  String get configuredAlertsLabel => 'Alertas configuradas';

  @override
  String get minLabel => 'Mínimo';

  @override
  String get maxLabel => 'Máximo';

  @override
  String get cnmvOfficialRegistryLabel => 'Consulta en el Registro Oficial';

  @override
  String get noBackupLabel =>
      'No hay backup. Se recomienda exportar este fondo.';

  @override
  String get oldBackupLabel =>
      'El último backup tiene más de un mes. Se recomienda exportar este fondo.';

  @override
  String lastBackupLabel(String date) {
    return 'Último backup: $date';
  }

  @override
  String get averageLabel => 'Media';

  @override
  String get historicalLabel => 'Histórico';

  @override
  String get volatilityLabel => 'Volatilidad';

  @override
  String get annualizedLabel => 'Anualizada';

  @override
  String get maxDrawdownLabel => 'Max Drawdown';

  @override
  String get maxDropLabel => 'Máxima Caída';

  @override
  String get recoveryLabel => 'Recuperación';

  @override
  String get fromTroughLabel => 'Desde el Trough';

  @override
  String daysCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get inProgressLabel => 'en curso';

  @override
  String get statusTab => 'Estado';

  @override
  String get balanceTab => 'Balance';

  @override
  String get chartTab => 'Gráfico';

  @override
  String get monthsTab => 'Meses';

  @override
  String get tableTab => 'Tabla';

  @override
  String get marketTab => 'Mercado';

  @override
  String get updateDataTooltip => 'Actualizar datos';

  @override
  String get downloadRangeTooltip => 'Descargar rango';

  @override
  String get exportFundAction => 'Exportar fondo';

  @override
  String get clearDataAction => 'Limpiar datos';

  @override
  String get deleteFromPortfolioAction => 'Eliminar de cartera';

  @override
  String get clearDataTitle => 'Limpiar Datos';

  @override
  String get clearDataConfirm => '¿Quieres limpiar los precios e historial?';

  @override
  String get deleteFromPortfolioTitle => 'Eliminar de Cartera';

  @override
  String get deleteFromPortfolioConfirm =>
      '¿Estás seguro de que quieres eliminar este fondo?';

  @override
  String get configureAlertsTitle => 'Configurar Alertas';

  @override
  String get configureAlertsDesc =>
      'Notificar si el Valor Liquidativo alcanza los siguientes límites:';

  @override
  String get deleteAlertsAction => 'Borrar Alertas';

  @override
  String get deletePriceError =>
      'No se pudo eliminar el precio. Haz un backup del fondo y reinicia la aplicación.';

  @override
  String get backup => 'Backup';

  @override
  String get numberLabel => 'No.';

  @override
  String get dateLabel => 'Fecha';

  @override
  String get priceLabel => 'Precio';

  @override
  String get diffLabel => 'Diff.';

  @override
  String get varLabel => 'Var.';

  @override
  String get deletePriceTitle => 'Eliminar Precio';

  @override
  String deletePriceConfirm(String date) {
    return '¿Deseas eliminar el registro del día $date?';
  }

  @override
  String get priceDeletedSuccess => 'Precio eliminado correctamente';

  @override
  String get undo => 'Deshacer';

  @override
  String get deletionUndone => 'Eliminación deshecha';

  @override
  String get noDataAvailable => 'No hay datos disponibles';

  @override
  String get noOperationsRegistered => 'No hay operaciones registradas';

  @override
  String get newOperation => 'Nueva Operación';

  @override
  String get editOperation => 'Editar Operación';

  @override
  String get subscription => 'Suscripción';

  @override
  String get redemption => 'Reembolso';

  @override
  String unitsAtPrice(String units, String price) {
    return '$units part. @ $price';
  }

  @override
  String get deleteOperationTitle => 'Eliminar Operación';

  @override
  String get areYouSure => '¿Estás seguro?';

  @override
  String get deleteOperationConfirm => '¿Deseas eliminar esta operación?';

  @override
  String get deleteOperationFailed => 'No se pudo eliminar la operación';

  @override
  String get deleteOperationError =>
      'No se pudo eliminar la operación. Haz un backup y reinicia la aplicación.';

  @override
  String get restoreOperationError =>
      'No se pudo restaurar la operación. Haz un backup y reinicia la aplicación.';

  @override
  String get operationDeletedSuccess => 'Operación eliminada correctamente';

  @override
  String get saveOperationFailed => 'No se pudo guardar la operación';

  @override
  String get buy => 'Compra';

  @override
  String get sell => 'Venta';

  @override
  String get priceNavLabel => 'Precio (VL)';

  @override
  String get unitsLabel => 'Participaciones';

  @override
  String get totalAmountLabel => 'Importe Total';

  @override
  String get noHistoryForReturns =>
      'No hay historial de precios para calcular rentabilidades.';

  @override
  String get insufficientDataForHeatmap =>
      'Datos insuficientes para generar el mapa de calor.';

  @override
  String get yearLabel => 'Año';

  @override
  String get totalUnitsLabel => 'Participaciones totales';

  @override
  String get netInvestmentLabel => 'Inversión neta';

  @override
  String get avgPurchasePriceLabel => 'Precio medio compra';

  @override
  String get currentValueLabel => 'Valor actual';

  @override
  String get grossProfitLabel => 'Plusvalía Bruta';

  @override
  String get grossLossLabel => 'Minusvalía Bruta';

  @override
  String get realGainLabel => 'Ganancia Real';

  @override
  String get netProfitEstLabel => '(Plusvalía Neta est.)';

  @override
  String get managementFeesTitle => 'Costes de Gestión';

  @override
  String get fixedFeesLabel => 'Gastos Corrientes';

  @override
  String get fixedFeesHint => 'Fijos';

  @override
  String get perfFeesLabel => 'Com. Resultados';

  @override
  String get perfFeesHint => 'Sobre éxito';

  @override
  String get annualCostEstLabel => 'Coste Anual Est.';

  @override
  String get monthlyCostEstLabel => 'Coste Mensual Est.';

  @override
  String get profitabilityIndicesTitle => 'Índices de Rentabilidad';

  @override
  String get annualizedReturnLabel => 'Rent. Anualizada';

  @override
  String get moicLabel => 'Multiplicador (MoIC)';

  @override
  String get ageLabel => 'Antigüedad';

  @override
  String get breakEvenLabel => 'Break-even';

  @override
  String get financialIndicesTitle => 'Índices Financieros';

  @override
  String get bruteReturnsNote =>
      'Rentabilidades brutas sin consideración de costes ni comisiones.';

  @override
  String get aprTaeDesc =>
      'Rentabilidad simple de TU inversión basándose en el capital total aportado y el tiempo transcurrido.';

  @override
  String get twrDesc =>
      'Time-Weighted Return. Mide el rendimiento del FONDO, eliminando el impacto de tus entradas y salidas de dinero. Es la rentabilidad del activo en sí.';

  @override
  String get mwrIrrDesc =>
      'Money-Weighted Return (o TIR). Rentabilidad real de tu bolsillo que tiene en cuenta el momento exacto de cada aportación. Refleja tu éxito como inversor al elegir cuándo entrar y salir.';

  @override
  String get moicDesc => 'Capital final obtenido por cada euro invertido.';

  @override
  String get ageDesc => 'Tiempo transcurrido desde la primera operación.';

  @override
  String get breakEvenDesc => 'Precio necesario para no tener pérdidas.';

  @override
  String get fixedFeesSuffix => '% TER';

  @override
  String get perfFeesSuffix => '% Éxito';

  @override
  String get twrTotalLabel => 'TWR (Total)';

  @override
  String get twrAnnualizedLabel => 'TWR Anualizada';

  @override
  String get mwrHistoricalLabel => 'MWR Histórico';

  @override
  String get mwrAnnualizedLabel => 'MWR Anualizada';

  @override
  String get twrInfoTitle => 'TWR (Total / Anualizada)';

  @override
  String get mwrInfoTitle => 'MWR (Histórico / Anualizada)';

  @override
  String monthsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String yearsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '1 año',
    );
    return '$_temp0';
  }

  @override
  String get andLabel => 'y';

  @override
  String get noDataInRange => 'No hay datos en este rango';

  @override
  String get averageLabelShort => 'Media';

  @override
  String get compareLabel => 'Comparar';

  @override
  String get compareWithBenchmark => 'Comparar con benchmark';

  @override
  String get noneLabel => 'Ninguno';

  @override
  String get fundPercentLabel => 'Fondo (%)';

  @override
  String get benchmarkPercentLabel => 'Benchmark (%)';

  @override
  String get sp500Desc =>
      'El S&P 500 es un índice bursátil que agrupa a las 500 empresas más grandes y representativas de Estados Unidos.';

  @override
  String get msciWorldDesc =>
      'El MSCI World es un índice que representa el rendimiento de empresas de mediana y gran capitalización en 23 países desarrollados.';

  @override
  String get euroStoxx50Desc =>
      'El EuroStoxx 50 representa a las 50 empresas más grandes y líquidas de la eurozona.';

  @override
  String get ibex35Desc =>
      'El IBEX 35 es el índice de referencia de la bolsa española, compuesto por las 35 empresas con más liquidez.';

  @override
  String get nasdaq100Desc =>
      'El Nasdaq 100 incluye a las 100 mayores empresas no financieras que cotizan en el mercado Nasdaq, con gran peso tecnológico.';

  @override
  String get dax40Desc =>
      'El DAX 40 es el índice de referencia de la bolsa alemana, compuesto por las 40 principales empresas de este mercado.';

  @override
  String get cac40Desc =>
      'El CAC 40 es el principal índice bursátil francés, que agrupa a las 40 empresas más significativas de la Bolsa de París.';

  @override
  String get nikkei225Desc =>
      'El Nikkei 225 es el índice más importante de la bolsa japonesa, compuesto por las 225 empresas más líquidas de Tokio.';
}
