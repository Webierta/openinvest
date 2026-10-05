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
      'Lleva tus datos contigo. Exporta e importa tu cartera completa con fusión inteligente o fondos individuales en JSON para moverlos entre dispositivos.';

  @override
  String get reportsInfoTitle => 'Informes y Generación de Archivos';

  @override
  String get reportsInfoDesc =>
      'Genera informes anuales profesionales en PDF con resumen ejecutivo y desglose por fondo, exporta un registro completo de tus operaciones en CSV, y protege tus datos con copias de seguridad.';

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
      'Los datos financieros, registros oficiales y cotizaciones se obtienen de diversas fuentes públicas, entre ellas la CNMV, el Banco Central Europeo (ECB/IFS), Morningstar y Yahoo Finance. OpenInvest no se responsabiliza de la exactitud de los datos proporcionados por terceros.';

  @override
  String get permissionsTitle => 'Permisos';

  @override
  String get permissionsDesc =>
      '• Internet: Para descargar cotizaciones en tiempo real.\n• Almacenamiento: Para exportar e importar archivos JSON de copia de seguridad.\n• Uso Biométrico: Permite que la aplicación utilice las modalidades biométricas admitidas por el dispositivo si el usuario de Android activa la opción de acceso restringido.';

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
  String get noFundSearchResults =>
      'No se han encontrado fondos para este criterio de búsqueda.';

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
  String get importFundJson => 'Importar fondo';

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
  String get marketOperations => 'Operaciones';

  @override
  String get marketCosts => 'Costes';

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
  String get saveCostsFailed => 'No se pudieron guardar los costes.';

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
  String get netProfitRecordedLabel =>
      '(Tras cargos externos registrados; VL ya neto)';

  @override
  String get costPeriodsTitle => 'Tarifas por periodo';

  @override
  String get costChargesTitle => 'Cargos externos registrados';

  @override
  String get costPeriodsEmpty => 'No hay tarifas históricas registradas.';

  @override
  String get costChargesEmpty => 'No hay cargos externos registrados.';

  @override
  String get costHelpTooltip => 'Ayuda sobre los costes';

  @override
  String get costHelpTitle => 'Cómo se contabilizan los costes';

  @override
  String get costHelpNav =>
      'El valor liquidativo (VL) normalmente ya descuenta los gastos propios del fondo. Los costes marcados como incluidos en el VL son informativos y no se restan otra vez.';

  @override
  String get costHelpTer =>
      'El TER puede incluir gestión, depositaría y gastos operativos. Si registras el TER total, no sumes además sus componentes.';

  @override
  String get costHelpRates =>
      'Las tarifas describen porcentajes y periodos, no importes pagados. Las tarifas externas recurrentes vigentes generan una estimación anual. La comisión de resultados potencial solo se muestra cuando está vinculada a una liquidación previa y hay valor liquidativo para comparar; si falta esa referencia, se oculta. Ninguna estimación modifica la plusvalía neta registrada.';

  @override
  String get costHelpExternal =>
      'Registra como cargo externo solo el importe cobrado aparte al inversor, por ejemplo una comisión de entrada, salida, comercialización o custodia. Se admite desde la primera suscripción hasta hoy, aunque el VL disponible sea anterior.';

  @override
  String get costHelpNet =>
      'La plusvalía neta se calcula como plusvalía bruta menos los cargos externos registrados dentro del periodo de inversión. Los costes ya incluidos en el VL no vuelven a descontarse.';

  @override
  String get costEstimateTitle => 'Estimación con tarifas vigentes';

  @override
  String get costAnnualEstimate => 'Coste anual recurrente';

  @override
  String get costAnnualEstimateNote =>
      'Porcentaje anual sobre la posición, valorada al último VL disponible. No se resta del neto.';

  @override
  String get costPerformancePotential => 'Comisión de resultados potencial';

  @override
  String get costPerformancePotentialNote =>
      'Incremento estimado desde la última liquidación vinculada; no es anual ni se resta del neto.';

  @override
  String get costPerformancePeriod => 'Tarifa de resultados vinculada';

  @override
  String get costSettlementUnlinked => 'Sin tarifa vinculada';

  @override
  String get costSettlementPeriodUnavailable => 'Tarifa ya no disponible';

  @override
  String get costSettledThrough => 'Liquidada hasta';

  @override
  String get costSettlementUnspecified => 'Sin fecha de liquidación';

  @override
  String get costSettlementDateInvalid =>
      'La fecha de liquidación no puede ser posterior al cargo.';

  @override
  String get addCostPeriod => 'Añadir tarifa';

  @override
  String get editCostPeriod => 'Editar tarifa';

  @override
  String get addCostCharge => 'Registrar cargo';

  @override
  String get editCostCharge => 'Editar cargo';

  @override
  String get costConcept => 'Concepto';

  @override
  String get costRate => 'Tasa (%)';

  @override
  String get costBasis => 'Base';

  @override
  String get costTreatment => 'Tratamiento';

  @override
  String get costStartDate => 'Vigente desde';

  @override
  String get costEndDate => 'Vigente hasta (opcional)';

  @override
  String get costNoEndDate => 'Sin fecha de fin';

  @override
  String get costAnnualBalance => '% anual sobre el saldo';

  @override
  String get costPositiveProfit => '% sobre beneficio positivo';

  @override
  String get costIncludedInNav => 'Incluido en VL';

  @override
  String get costChargedSeparately => 'Cobrado aparte';

  @override
  String get costTreatmentUnknown => 'Pendiente de clasificar';

  @override
  String get costLegacyDateUnknown => 'Periodo histórico sin fecha conocida';

  @override
  String get costDescription => 'Descripción (opcional)';

  @override
  String get costAmount => 'Importe cobrado';

  @override
  String get costDate => 'Fecha del cargo';

  @override
  String get costRateInvalid =>
      'Introduce una tasa válida igual o superior a cero.';

  @override
  String get costPeriodInvalid =>
      'La fecha final debe ser igual o posterior a la inicial.';

  @override
  String get costPeriodOverlap =>
      'Ya existe una tarifa del mismo concepto en ese periodo.';

  @override
  String get costChargeInvalid =>
      'Introduce un importe cobrado mayor que cero.';

  @override
  String get deleteCostTitle => 'Eliminar coste';

  @override
  String get deleteCostConfirm => '¿Quieres eliminar este registro?';

  @override
  String get costConceptTer => 'TER total';

  @override
  String get costConceptManagement => 'Gestión';

  @override
  String get costConceptDepositary => 'Depositario';

  @override
  String get costConceptOperating => 'Gastos operativos';

  @override
  String get costConceptSubscription => 'Suscripción o entrada';

  @override
  String get costConceptRedemption => 'Reembolso o salida';

  @override
  String get costConceptTransfer => 'Traspaso o cambio';

  @override
  String get costConceptDistributor => 'Comercializador o intermediario';

  @override
  String get costConceptCustody => 'Custodia o mantenimiento';

  @override
  String get costConceptPerformance => 'Comisión de resultados';

  @override
  String get costConceptTax => 'Impuestos asociados';

  @override
  String get costConceptOther => 'Otro';

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
  String get ageDesc => 'Tiempo transcurrido desde la primera suscripción.';

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
  String get mwrHistoricalLabel => 'MWR Acumulado';

  @override
  String get mwrAnnualizedLabel => 'MWR Anualizada';

  @override
  String get twrInfoTitle => 'TWR (Total / Anualizada)';

  @override
  String get mwrInfoTitle => 'MWR (Acumulado / Anualizada)';

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
  String get comparePageTitle => 'Comparador';

  @override
  String get compareFundSelection => 'Fondos para comparar';

  @override
  String get comparePortfolioNeedsTwo =>
      'Necesitas al menos dos fondos en cartera para compararlos.';

  @override
  String get compareSelectFund => 'Selecciona un fondo';

  @override
  String get compareFundOne => 'Primer fondo';

  @override
  String get compareFundTwo => 'Segundo fondo';

  @override
  String get compareChooseDifferentFunds => 'Selecciona dos fondos diferentes.';

  @override
  String get compareResults => 'Resultado de la comparación';

  @override
  String get compareChartTitle => 'Evolución histórica';

  @override
  String get compareChartNoData =>
      'No hay historial común suficiente para mostrar el gráfico.';

  @override
  String get compareMarketHistory => 'Fondo e historial';

  @override
  String get compareInvestmentPosition => 'Tu inversión';

  @override
  String get compareNoSharedPositions =>
      'Las métricas de inversión requieren una posición abierta en ambos fondos.';

  @override
  String get compareHistoryStart => 'Primer valor disponible';

  @override
  String get compareCurrency => 'Moneda';

  @override
  String get compareLastNav => 'Último valor liquidativo';

  @override
  String get compareLastChange => 'Última variación';

  @override
  String get compareMonthChange => 'Variación en 1 mes';

  @override
  String get compareSixMonthChange => 'Variación en 6 meses';

  @override
  String get compareYearChange => 'Variación en 1 año';

  @override
  String get compareSinceInceptionChange => 'Variación desde el inicio';

  @override
  String get compareAnnualVolatility => 'Volatilidad anualizada';

  @override
  String get compareCosts => 'Costes y comisiones';

  @override
  String get compareMorningstarRating => 'Rating Morningstar';

  @override
  String get compareTer => 'TER';

  @override
  String get compareInvested => 'Capital invertido';

  @override
  String get compareCurrentValue => 'Valor actual';

  @override
  String get compareProfit => 'Plusvalía';

  @override
  String get compareReturn => 'Rentabilidad de la posición';

  @override
  String get compareTwr => 'TWR anualizado';

  @override
  String get compareMwr => 'TIR anualizada';

  @override
  String get compareMoic => 'MOIC';

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

  @override
  String get portfolioAlertsTitle => '¡Alertas de Fondos!';

  @override
  String get portfolioAlertsDesc =>
      'Se han alcanzado los siguientes límites configurados en tus fondos:';

  @override
  String alertMinReached(String fundName, String current, String limit) {
    return 'El fondo $fundName ha caído por debajo del límite de $limit: Valor actual $current';
  }

  @override
  String alertMaxReached(String fundName, String current, String limit) {
    return 'El fondo $fundName ha superado el límite de $limit: Valor actual $current';
  }

  @override
  String get localCatalog => 'Catálogo Local';

  @override
  String get localCatalogDesc => 'Fondos armonizados del catálogo local.';

  @override
  String get ecbSource => 'ECB / IFS';

  @override
  String get ecbSourceDesc =>
      'Fondos y vehículos de inversión identificados mediante la base estadística IFS del Banco Central Europeo.';

  @override
  String get morningstarSource => 'Morningstar';

  @override
  String get morningstarSourceDesc =>
      'Fondos extranjeros resueltos mediante Morningstar LT.';

  @override
  String get yahooSource => 'Yahoo Finance';

  @override
  String get yahooSourceDesc =>
      'Búsqueda y cotizaciones globales en Yahoo Finance.';

  @override
  String get csvHeaderDate => 'Fecha';

  @override
  String get csvHeaderIsin => 'ISIN';

  @override
  String get csvHeaderFundName => 'Nombre del Fondo';

  @override
  String get csvHeaderOperationType => 'Tipo de Operación';

  @override
  String get csvHeaderUnits => 'Unidades';

  @override
  String get csvHeaderUnitPrice => 'Precio Unitario';

  @override
  String get csvHeaderTotalAmount => 'Importe Total';

  @override
  String get csvHeaderCurrency => 'Divisa';

  @override
  String get saveOperationsReportTitle => 'Guardar informe de operaciones';

  @override
  String get annualPortfolioReport => 'Informe Anual de Cartera';

  @override
  String get executiveSummary => 'Resumen Ejecutivo';

  @override
  String get fundDetail => 'Detalle por Fondo';

  @override
  String get returnPercentLabel => 'Rent. %';

  @override
  String get legalNotice => 'Aviso Legal';

  @override
  String legalNoticeText(String date) {
    return 'Este informe ha sido generado automáticamente por OpenInvest el $date. Los datos se han obtenido de fuentes públicas y pueden contener imprecisiones. Este documento no constituye asesoramiento financiero. Verifique siempre los datos con su entidad financiera antes de tomar decisiones.';
  }

  @override
  String pdfFooter(String year, String page, String total) {
    return 'OpenInvest - Informe Anual $year - Página $page de $total';
  }

  @override
  String get saveAnnualReportTitle => 'Guardar informe anual';

  @override
  String get operationsCsv => 'Operaciones CSV';

  @override
  String get pdfReportLabel => 'Informe PDF';

  @override
  String get selectReportYear => 'Selecciona el año del informe';

  @override
  String reportSavedSuccess(String fileName) {
    return '✓ Informe guardado: $fileName';
  }

  @override
  String get exportCancelledOrFailed => 'Exportación cancelada o fallida.';

  @override
  String pdfGenerationError(String error) {
    return 'Error al generar el PDF: $error';
  }

  @override
  String get openAction => 'Abrir';

  @override
  String get reportGeneratedTitle => 'Informe generado';

  @override
  String annualReportReadyMessage(String year) {
    return 'El informe anual de $year está listo. ¿Qué deseas hacer?';
  }

  @override
  String get previewAndPrint => 'Previsualizar / Imprimir';

  @override
  String get creditsTitle => 'Créditos';

  @override
  String get creditsDesc =>
      'OpenInvest — Proyecto de código abierto desarrollado por Webierta.\n\nHerramientas de IA — ChatGPT · OpenAI, GitHub Copilot y Google Gemini — Asistencia en arquitectura de software, investigación técnica y pruebas, generación, depuración y revisión de código, seguridad y automatización.';

  @override
  String get generateFilesLabel => 'Generar archivos';

  @override
  String get exportPortfolioMenu => 'Exportar cartera';

  @override
  String get importPortfolioMenu => 'Importar cartera';

  @override
  String get portfolioExportedSuccess => 'Cartera exportada correctamente';

  @override
  String get portfolioImportedSuccess =>
      'Cartera importada con fusión inteligente';

  @override
  String get compareInfoTitle => 'Comparador de Fondos';

  @override
  String get compareInfoDesc =>
      'Compara dos fondos de tu cartera lado a lado: evolución histórica con gráficos normalizados, comparativa de rentabilidades (1M, 6M, 1A, Total), volatilidad, costes (TER), rating Morningstar y posición de inversión personal.';
}
