import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'OpenInvest'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get english;

  /// No description provided for @security.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get security;

  /// No description provided for @protectedAccess.
  ///
  /// In es, this message translates to:
  /// **'Acceso Protegido'**
  String get protectedAccess;

  /// No description provided for @supportOpenInvest.
  ///
  /// In es, this message translates to:
  /// **'Apoyar OpenInvest'**
  String get supportOpenInvest;

  /// No description provided for @helloDeveloper.
  ///
  /// In es, this message translates to:
  /// **'¡Hola! Soy el desarrollador de OpenInvest'**
  String get helloDeveloper;

  /// No description provided for @supportDescription.
  ///
  /// In es, this message translates to:
  /// **'OpenInvest es una herramienta de código abierto creada para ayudar a los inversores a gestionar sus carteras de forma gratuita y privada. Si la aplicación te resulta útil, considera apoyarla para asegurar su mantenimiento y evolución futura.'**
  String get supportDescription;

  /// No description provided for @githubTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviar Sugerencias o Errores'**
  String get githubTitle;

  /// No description provided for @githubDescription.
  ///
  /// In es, this message translates to:
  /// **'¿Tienes alguna idea para mejorar o has encontrado un fallo? Cuéntamelo en el repositorio oficial.'**
  String get githubDescription;

  /// No description provided for @githubButton.
  ///
  /// In es, this message translates to:
  /// **'Ir a GitHub'**
  String get githubButton;

  /// No description provided for @paypalTitle.
  ///
  /// In es, this message translates to:
  /// **'Donar vía PayPal'**
  String get paypalTitle;

  /// No description provided for @paypalDescription.
  ///
  /// In es, this message translates to:
  /// **'Las donaciones ayudan a cubrir los costes de desarrollo y servidores de información.'**
  String get paypalDescription;

  /// No description provided for @paypalButton.
  ///
  /// In es, this message translates to:
  /// **'Donar con PayPal'**
  String get paypalButton;

  /// No description provided for @bitcoinTitle.
  ///
  /// In es, this message translates to:
  /// **'Donar vía Bitcoin'**
  String get bitcoinTitle;

  /// No description provided for @bitcoinDescription.
  ///
  /// In es, this message translates to:
  /// **'También puedes enviar tu apoyo a través de la red Bitcoin.'**
  String get bitcoinDescription;

  /// No description provided for @copyAddress.
  ///
  /// In es, this message translates to:
  /// **'Copiar Dirección'**
  String get copyAddress;

  /// No description provided for @bitcoinCopied.
  ///
  /// In es, this message translates to:
  /// **'Dirección Bitcoin copiada al portapapeles'**
  String get bitcoinCopied;

  /// No description provided for @thanksForUsing.
  ///
  /// In es, this message translates to:
  /// **'¡Muchas gracias por usar OpenInvest!'**
  String get thanksForUsing;

  /// No description provided for @authFailed.
  ///
  /// In es, this message translates to:
  /// **'Autenticación fallida o cancelada'**
  String get authFailed;

  /// No description provided for @setAppPassword.
  ///
  /// In es, this message translates to:
  /// **'Establecer Contraseña'**
  String get setAppPassword;

  /// No description provided for @setAppPasswordDescription.
  ///
  /// In es, this message translates to:
  /// **'Define una contraseña para proteger el acceso a OpenInvest en este equipo.'**
  String get setAppPasswordDescription;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @minCharacters.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 4 caracteres'**
  String get minCharacters;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @requirePasswordSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Requerir contraseña de aplicación para entrar.'**
  String get requirePasswordSubtitle;

  /// No description provided for @requireBiometricSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Requerir huella, rostro o PIN del dispositivo para entrar.'**
  String get requireBiometricSubtitle;

  /// No description provided for @noBiometricSupport.
  ///
  /// In es, this message translates to:
  /// **'Tu dispositivo no soporta autenticación biométrica.'**
  String get noBiometricSupport;

  /// No description provided for @changePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// No description provided for @data.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get data;

  /// No description provided for @autoRefreshTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar fondos al iniciar'**
  String get autoRefreshTitle;

  /// No description provided for @autoRefreshSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar cuando los datos tengan al menos un día y no se hayan actualizado en las últimas 24 horas.'**
  String get autoRefreshSubtitle;

  /// No description provided for @protectedAccessTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso protegido'**
  String get protectedAccessTitle;

  /// No description provided for @appPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña de la aplicación'**
  String get appPasswordLabel;

  /// No description provided for @enterPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Introduce la contraseña'**
  String get enterPasswordError;

  /// No description provided for @enter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get enter;

  /// No description provided for @authRequiredDescription.
  ///
  /// In es, this message translates to:
  /// **'Por favor, autentícate para continuar.'**
  String get authRequiredDescription;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @info.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get info;

  /// No description provided for @searchFundsTitle.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda de Fondos'**
  String get searchFundsTitle;

  /// No description provided for @searchFundsDesc.
  ///
  /// In es, this message translates to:
  /// **'Busca cualquier fondo de inversión del mundo utilizando su código ISIN. Obtenemos los datos en tiempo real a través de fuentes públicas financieras.'**
  String get searchFundsDesc;

  /// No description provided for @priceHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de Precios'**
  String get priceHistoryTitle;

  /// No description provided for @priceHistoryDesc.
  ///
  /// In es, this message translates to:
  /// **'Descarga el histórico de valores liquidativos (VL) para analizar la evolución temporal. Puedes seleccionar rangos de fechas personalizados.'**
  String get priceHistoryDesc;

  /// No description provided for @operationsMgmtTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestión de Operaciones'**
  String get operationsMgmtTitle;

  /// No description provided for @operationsMgmtDesc.
  ///
  /// In es, this message translates to:
  /// **'Registra tus suscripciones (compras) y reembolsos (ventas). La aplicación calcula automáticamente tus participaciones totales y capital invertido.'**
  String get operationsMgmtDesc;

  /// No description provided for @profitabilityAnalysisTitle.
  ///
  /// In es, this message translates to:
  /// **'Análisis de Rentabilidad'**
  String get profitabilityAnalysisTitle;

  /// No description provided for @profitabilityAnalysisDesc.
  ///
  /// In es, this message translates to:
  /// **'Cálculo de índices avanzados:\n• TAE: Rentabilidad anualizada de tu bolsillo.\n• TWR: Rendimiento real del fondo (activo).\n• MWR/TIR: Tu éxito personal según el momento de inversión.'**
  String get profitabilityAnalysisDesc;

  /// No description provided for @costsAuditTitle.
  ///
  /// In es, this message translates to:
  /// **'Auditoría de Costes'**
  String get costsAuditTitle;

  /// No description provided for @costsAuditDesc.
  ///
  /// In es, this message translates to:
  /// **'Introduce los Gastos Corrientes (TER) y la Comisión de Éxito de tus fondos para calcular la Ganancia Real neta, descontando el impacto de las comisiones en tu capital.'**
  String get costsAuditDesc;

  /// No description provided for @interactiveChartsTitle.
  ///
  /// In es, this message translates to:
  /// **'Gráficos Interactivos'**
  String get interactiveChartsTitle;

  /// No description provided for @interactiveChartsDesc.
  ///
  /// In es, this message translates to:
  /// **'Visualiza la evolución de tus fondos con filtros de rango rápido (1M, 6M, 1Y, etc.) y líneas de tendencia media.'**
  String get interactiveChartsDesc;

  /// No description provided for @monthlyHeatmapTitle.
  ///
  /// In es, this message translates to:
  /// **'Mapa de Calor Mensual'**
  String get monthlyHeatmapTitle;

  /// No description provided for @monthlyHeatmapDesc.
  ///
  /// In es, this message translates to:
  /// **'Analiza la estacionalidad de tus inversiones con una cuadrícula de rentabilidades mes a mes y acumulados anuales, identificando periodos de éxito y correcciones.'**
  String get monthlyHeatmapDesc;

  /// No description provided for @benchmarkComparisonTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparación con Benchmarks'**
  String get benchmarkComparisonTitle;

  /// No description provided for @benchmarkComparisonDesc.
  ///
  /// In es, this message translates to:
  /// **'Superpón la evolución de los principales índices mundiales (S&P 500, MSCI World, etc.) sobre el gráfico del fondo para medir su rendimiento relativo en porcentaje.'**
  String get benchmarkComparisonDesc;

  /// No description provided for @riskAnalysisTitle.
  ///
  /// In es, this message translates to:
  /// **'Análisis de Riesgo'**
  String get riskAnalysisTitle;

  /// No description provided for @riskAnalysisDesc.
  ///
  /// In es, this message translates to:
  /// **'Métricas de nivel profesional para evaluar la seguridad:\n• Max Drawdown: La mayor caída histórica desde un pico.\n• Recuperación: Tiempo que el fondo tarda en sanar sus pérdidas.'**
  String get riskAnalysisDesc;

  /// No description provided for @exportImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportación e Importación'**
  String get exportImportTitle;

  /// No description provided for @exportImportDesc.
  ///
  /// In es, this message translates to:
  /// **'Lleva tus datos contigo. Exporta e importa tu cartera completa con fusión inteligente o fondos individuales en JSON para moverlos entre dispositivos.'**
  String get exportImportDesc;

  /// No description provided for @reportsInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'Informes y Generación de Archivos'**
  String get reportsInfoTitle;

  /// No description provided for @reportsInfoDesc.
  ///
  /// In es, this message translates to:
  /// **'Genera informes anuales profesionales en PDF con resumen ejecutivo y desglose por fondo, exporta un registro completo de tus operaciones en CSV, y protege tus datos con copias de seguridad.'**
  String get reportsInfoDesc;

  /// No description provided for @multicurrencySupportTitle.
  ///
  /// In es, this message translates to:
  /// **'Soporte Multidivisa'**
  String get multicurrencySupportTitle;

  /// No description provided for @multicurrencySupportDesc.
  ///
  /// In es, this message translates to:
  /// **'Gestión automática de fondos en diversas divisas con conversión en tiempo real para una valoración precisa de tu cartera global.'**
  String get multicurrencySupportDesc;

  /// No description provided for @notificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificationsTitle;

  /// No description provided for @notificationsDesc.
  ///
  /// In es, this message translates to:
  /// **'Configura alertas personalizadas para mantenerte informado sobre tus fondos y objetivos financieros.'**
  String get notificationsDesc;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @support.
  ///
  /// In es, this message translates to:
  /// **'Apoyar'**
  String get support;

  /// No description provided for @exit.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get exit;

  /// No description provided for @aboutOpenInvest.
  ///
  /// In es, this message translates to:
  /// **'Acerca de OpenInvest'**
  String get aboutOpenInvest;

  /// No description provided for @licenseTitle.
  ///
  /// In es, this message translates to:
  /// **'Licencia'**
  String get licenseTitle;

  /// No description provided for @licenseDesc.
  ///
  /// In es, this message translates to:
  /// **'Esta aplicación es Software Libre bajo la licencia GNU General Public License v3 (GPLv3).'**
  String get licenseDesc;

  /// No description provided for @openSourceTitle.
  ///
  /// In es, this message translates to:
  /// **'Código Abierto'**
  String get openSourceTitle;

  /// No description provided for @openSourceDesc.
  ///
  /// In es, this message translates to:
  /// **'El código fuente está disponible públicamente en nuestro repositorio de GitHub:\ngithub.com/Webierta/openinvest'**
  String get openSourceDesc;

  /// No description provided for @dataSourceTitle.
  ///
  /// In es, this message translates to:
  /// **'Fuente de Datos'**
  String get dataSourceTitle;

  /// No description provided for @dataSourceDesc.
  ///
  /// In es, this message translates to:
  /// **'Los datos financieros, registros oficiales y cotizaciones se obtienen de fuentes públicas como la CNMV, Morningstar y Yahoo Finance. OpenInvest no se responsabiliza de la exactitud de los datos proporcionados por terceros.'**
  String get dataSourceDesc;

  /// No description provided for @permissionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Permisos'**
  String get permissionsTitle;

  /// No description provided for @permissionsDesc.
  ///
  /// In es, this message translates to:
  /// **'• Internet: Para descargar cotizaciones en tiempo real.\n• Almacenamiento: Para exportar e importar archivos JSON de copia de seguridad.'**
  String get permissionsDesc;

  /// No description provided for @warrantyTitle.
  ///
  /// In es, this message translates to:
  /// **'Garantía y Responsabilidad'**
  String get warrantyTitle;

  /// No description provided for @warrantyDesc.
  ///
  /// In es, this message translates to:
  /// **'La aplicación se proporciona \"tal cual\", sin garantía de ningún tipo. No constituye asesoramiento financiero profesional. Invierte bajo tu propio riesgo.'**
  String get warrantyDesc;

  /// No description provided for @privacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Privacidad y Seguridad'**
  String get privacyTitle;

  /// No description provided for @privacyDesc.
  ///
  /// In es, this message translates to:
  /// **'OpenInvest es una aplicación 100% gratuita y sin publicidad. No recopilamos datos personales. Toda tu información financiera se guarda exclusivamente de forma local en tu dispositivo.'**
  String get privacyDesc;

  /// No description provided for @versionLabel.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get versionLabel;

  /// No description provided for @addFund.
  ///
  /// In es, this message translates to:
  /// **'Añadir Fondo'**
  String get addFund;

  /// No description provided for @resultsInfo.
  ///
  /// In es, this message translates to:
  /// **'Información sobre resultados'**
  String get resultsInfo;

  /// No description provided for @searchFundPrompt.
  ///
  /// In es, this message translates to:
  /// **'Busca un fondo para añadirlo a tu cartera'**
  String get searchFundPrompt;

  /// No description provided for @fundSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre o código ISIN'**
  String get fundSearchLabel;

  /// No description provided for @fundSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Amundi o ES0152743003'**
  String get fundSearchHint;

  /// No description provided for @searchFundAction.
  ///
  /// In es, this message translates to:
  /// **'Buscar fondo'**
  String get searchFundAction;

  /// No description provided for @isinNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'ISIN no disponible'**
  String get isinNotAvailable;

  /// No description provided for @fundFound.
  ///
  /// In es, this message translates to:
  /// **'Fondo Encontrado'**
  String get fundFound;

  /// No description provided for @fundFoundDesc.
  ///
  /// In es, this message translates to:
  /// **'Se ha encontrado el siguiente fondo:'**
  String get fundFoundDesc;

  /// No description provided for @noValidIsinDesc.
  ///
  /// In es, this message translates to:
  /// **'Este activo no proporciona un código ISIN válido y no puede ser añadido a la cartera.'**
  String get noValidIsinDesc;

  /// No description provided for @resolved.
  ///
  /// In es, this message translates to:
  /// **'RESUELTO'**
  String get resolved;

  /// No description provided for @addToPortfolioPrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas añadirlo a tu cartera?'**
  String get addToPortfolioPrompt;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @addToPortfolioAction.
  ///
  /// In es, this message translates to:
  /// **'Añadir a Cartera'**
  String get addToPortfolioAction;

  /// No description provided for @fundAlreadyInPortfolio.
  ///
  /// In es, this message translates to:
  /// **'Fondo ya existente'**
  String get fundAlreadyInPortfolio;

  /// No description provided for @overwriteFundDesc.
  ///
  /// In es, this message translates to:
  /// **'{fundName} ya está en tu cartera. ¿Quieres sobrescribirlo? Se eliminarán sus datos actuales, incluido el historial y las operaciones.'**
  String overwriteFundDesc(String fundName);

  /// No description provided for @overwrite.
  ///
  /// In es, this message translates to:
  /// **'Sobrescribir'**
  String get overwrite;

  /// No description provided for @processingFund.
  ///
  /// In es, this message translates to:
  /// **'Procesando fondo e identificando ISIN...'**
  String get processingFund;

  /// No description provided for @processingWait.
  ///
  /// In es, this message translates to:
  /// **'Esta operación puede tardar unos segundos'**
  String get processingWait;

  /// No description provided for @dataSource.
  ///
  /// In es, this message translates to:
  /// **'Origen de los Datos'**
  String get dataSource;

  /// No description provided for @cnmvRegistry.
  ///
  /// In es, this message translates to:
  /// **'Registro CNMV'**
  String get cnmvRegistry;

  /// No description provided for @cnmvDesc.
  ///
  /// In es, this message translates to:
  /// **'Fondos españoles armonizados. Los datos provienen del catálogo oficial de la Comisión Nacional del Mercado de Valores.'**
  String get cnmvDesc;

  /// No description provided for @globalMarket.
  ///
  /// In es, this message translates to:
  /// **'Mercado Global'**
  String get globalMarket;

  /// No description provided for @globalMarketDesc.
  ///
  /// In es, this message translates to:
  /// **'Fondos internacionales y ETFs. Los datos se obtienen de Yahoo Finance.'**
  String get globalMarketDesc;

  /// No description provided for @isinNotDetected.
  ///
  /// In es, this message translates to:
  /// **'ISIN no detectado'**
  String get isinNotDetected;

  /// No description provided for @isinNotDetectedDesc.
  ///
  /// In es, this message translates to:
  /// **'Yahoo Finance no ha proporcionado el código ISIN para este resultado. Intentaremos obtenerlo de los metadatos o usaremos el símbolo como identificador.\n\n¿Deseas continuar?'**
  String get isinNotDetectedDesc;

  /// No description provided for @continueText.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueText;

  /// No description provided for @global.
  ///
  /// In es, this message translates to:
  /// **'GLOBAL'**
  String get global;

  /// No description provided for @updatePortfolioTooltip.
  ///
  /// In es, this message translates to:
  /// **'Actualizar toda la cartera'**
  String get updatePortfolioTooltip;

  /// No description provided for @sortPortfolioTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ordenar cartera'**
  String get sortPortfolioTooltip;

  /// No description provided for @sortByAlpha.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get sortByAlpha;

  /// No description provided for @sortByValue.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get sortByValue;

  /// No description provided for @sortByPerformance.
  ///
  /// In es, this message translates to:
  /// **'TAE'**
  String get sortByPerformance;

  /// No description provided for @moreOptionsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptionsTooltip;

  /// No description provided for @importFundJson.
  ///
  /// In es, this message translates to:
  /// **'Importar fondo'**
  String get importFundJson;

  /// No description provided for @fundImportedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Fondo importado correctamente'**
  String get fundImportedSuccess;

  /// No description provided for @clearPortfolioTitle.
  ///
  /// In es, this message translates to:
  /// **'Vaciar Cartera'**
  String get clearPortfolioTitle;

  /// No description provided for @clearPortfolioConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres eliminar todos los fondos de tu cartera?'**
  String get clearPortfolioConfirm;

  /// No description provided for @clearPortfolioAction.
  ///
  /// In es, this message translates to:
  /// **'Vaciar cartera'**
  String get clearPortfolioAction;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @portfolioLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los datos de la cartera.'**
  String get portfolioLoadError;

  /// No description provided for @emptyPortfolio.
  ///
  /// In es, this message translates to:
  /// **'Tu cartera está vacía.'**
  String get emptyPortfolio;

  /// No description provided for @addFirstFund.
  ///
  /// In es, this message translates to:
  /// **'Añadir mi primer fondo'**
  String get addFirstFund;

  /// No description provided for @portfolioSummary.
  ///
  /// In es, this message translates to:
  /// **'RESUMEN DE CARTERA'**
  String get portfolioSummary;

  /// No description provided for @invested.
  ///
  /// In es, this message translates to:
  /// **'Invertido'**
  String get invested;

  /// No description provided for @gain.
  ///
  /// In es, this message translates to:
  /// **'GANANCIA'**
  String get gain;

  /// No description provided for @totalGain.
  ///
  /// In es, this message translates to:
  /// **'GANANCIA TOTAL'**
  String get totalGain;

  /// No description provided for @valueLabel.
  ///
  /// In es, this message translates to:
  /// **'VALOR'**
  String get valueLabel;

  /// No description provided for @performanceLabel.
  ///
  /// In es, this message translates to:
  /// **'RENDIMIENTO'**
  String get performanceLabel;

  /// No description provided for @weightLabel.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get weightLabel;

  /// No description provided for @noQuoteData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de cotización.'**
  String get noQuoteData;

  /// No description provided for @navLabel.
  ///
  /// In es, this message translates to:
  /// **'Valor Liquidativo'**
  String get navLabel;

  /// No description provided for @toHighsLabel.
  ///
  /// In es, this message translates to:
  /// **'A máximos'**
  String get toHighsLabel;

  /// No description provided for @totalVariationLabel.
  ///
  /// In es, this message translates to:
  /// **'Variación Total'**
  String get totalVariationLabel;

  /// No description provided for @sinceLabel.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get sinceLabel;

  /// No description provided for @configuredAlertsLabel.
  ///
  /// In es, this message translates to:
  /// **'Alertas configuradas'**
  String get configuredAlertsLabel;

  /// No description provided for @minLabel.
  ///
  /// In es, this message translates to:
  /// **'Mínimo'**
  String get minLabel;

  /// No description provided for @maxLabel.
  ///
  /// In es, this message translates to:
  /// **'Máximo'**
  String get maxLabel;

  /// No description provided for @cnmvOfficialRegistryLabel.
  ///
  /// In es, this message translates to:
  /// **'Consulta en el Registro Oficial'**
  String get cnmvOfficialRegistryLabel;

  /// No description provided for @noBackupLabel.
  ///
  /// In es, this message translates to:
  /// **'No hay backup. Se recomienda exportar este fondo.'**
  String get noBackupLabel;

  /// No description provided for @oldBackupLabel.
  ///
  /// In es, this message translates to:
  /// **'El último backup tiene más de un mes. Se recomienda exportar este fondo.'**
  String get oldBackupLabel;

  /// No description provided for @lastBackupLabel.
  ///
  /// In es, this message translates to:
  /// **'Último backup: {date}'**
  String lastBackupLabel(String date);

  /// No description provided for @averageLabel.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get averageLabel;

  /// No description provided for @historicalLabel.
  ///
  /// In es, this message translates to:
  /// **'Histórico'**
  String get historicalLabel;

  /// No description provided for @volatilityLabel.
  ///
  /// In es, this message translates to:
  /// **'Volatilidad'**
  String get volatilityLabel;

  /// No description provided for @annualizedLabel.
  ///
  /// In es, this message translates to:
  /// **'Anualizada'**
  String get annualizedLabel;

  /// No description provided for @maxDrawdownLabel.
  ///
  /// In es, this message translates to:
  /// **'Max Drawdown'**
  String get maxDrawdownLabel;

  /// No description provided for @maxDropLabel.
  ///
  /// In es, this message translates to:
  /// **'Máxima Caída'**
  String get maxDropLabel;

  /// No description provided for @recoveryLabel.
  ///
  /// In es, this message translates to:
  /// **'Recuperación'**
  String get recoveryLabel;

  /// No description provided for @fromTroughLabel.
  ///
  /// In es, this message translates to:
  /// **'Desde el Trough'**
  String get fromTroughLabel;

  /// No description provided for @daysCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String daysCount(num count);

  /// No description provided for @inProgressLabel.
  ///
  /// In es, this message translates to:
  /// **'en curso'**
  String get inProgressLabel;

  /// No description provided for @statusTab.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get statusTab;

  /// No description provided for @balanceTab.
  ///
  /// In es, this message translates to:
  /// **'Balance'**
  String get balanceTab;

  /// No description provided for @chartTab.
  ///
  /// In es, this message translates to:
  /// **'Gráfico'**
  String get chartTab;

  /// No description provided for @monthsTab.
  ///
  /// In es, this message translates to:
  /// **'Meses'**
  String get monthsTab;

  /// No description provided for @tableTab.
  ///
  /// In es, this message translates to:
  /// **'Tabla'**
  String get tableTab;

  /// No description provided for @marketTab.
  ///
  /// In es, this message translates to:
  /// **'Mercado'**
  String get marketTab;

  /// No description provided for @marketOperations.
  ///
  /// In es, this message translates to:
  /// **'Operaciones'**
  String get marketOperations;

  /// No description provided for @marketCosts.
  ///
  /// In es, this message translates to:
  /// **'Costes'**
  String get marketCosts;

  /// No description provided for @updateDataTooltip.
  ///
  /// In es, this message translates to:
  /// **'Actualizar datos'**
  String get updateDataTooltip;

  /// No description provided for @downloadRangeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Descargar rango'**
  String get downloadRangeTooltip;

  /// No description provided for @exportFundAction.
  ///
  /// In es, this message translates to:
  /// **'Exportar fondo'**
  String get exportFundAction;

  /// No description provided for @clearDataAction.
  ///
  /// In es, this message translates to:
  /// **'Limpiar datos'**
  String get clearDataAction;

  /// No description provided for @deleteFromPortfolioAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar de cartera'**
  String get deleteFromPortfolioAction;

  /// No description provided for @clearDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Limpiar Datos'**
  String get clearDataTitle;

  /// No description provided for @clearDataConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres limpiar los precios e historial?'**
  String get clearDataConfirm;

  /// No description provided for @deleteFromPortfolioTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar de Cartera'**
  String get deleteFromPortfolioTitle;

  /// No description provided for @deleteFromPortfolioConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres eliminar este fondo?'**
  String get deleteFromPortfolioConfirm;

  /// No description provided for @configureAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configurar Alertas'**
  String get configureAlertsTitle;

  /// No description provided for @configureAlertsDesc.
  ///
  /// In es, this message translates to:
  /// **'Notificar si el Valor Liquidativo alcanza los siguientes límites:'**
  String get configureAlertsDesc;

  /// No description provided for @deleteAlertsAction.
  ///
  /// In es, this message translates to:
  /// **'Borrar Alertas'**
  String get deleteAlertsAction;

  /// No description provided for @deletePriceError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el precio. Haz un backup del fondo y reinicia la aplicación.'**
  String get deletePriceError;

  /// No description provided for @backup.
  ///
  /// In es, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @numberLabel.
  ///
  /// In es, this message translates to:
  /// **'No.'**
  String get numberLabel;

  /// No description provided for @dateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get dateLabel;

  /// No description provided for @priceLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get priceLabel;

  /// No description provided for @diffLabel.
  ///
  /// In es, this message translates to:
  /// **'Diff.'**
  String get diffLabel;

  /// No description provided for @varLabel.
  ///
  /// In es, this message translates to:
  /// **'Var.'**
  String get varLabel;

  /// No description provided for @deletePriceTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar Precio'**
  String get deletePriceTitle;

  /// No description provided for @deletePriceConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas eliminar el registro del día {date}?'**
  String deletePriceConfirm(String date);

  /// No description provided for @priceDeletedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Precio eliminado correctamente'**
  String get priceDeletedSuccess;

  /// No description provided for @undo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// No description provided for @deletionUndone.
  ///
  /// In es, this message translates to:
  /// **'Eliminación deshecha'**
  String get deletionUndone;

  /// No description provided for @noDataAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay datos disponibles'**
  String get noDataAvailable;

  /// No description provided for @noOperationsRegistered.
  ///
  /// In es, this message translates to:
  /// **'No hay operaciones registradas'**
  String get noOperationsRegistered;

  /// No description provided for @newOperation.
  ///
  /// In es, this message translates to:
  /// **'Nueva Operación'**
  String get newOperation;

  /// No description provided for @editOperation.
  ///
  /// In es, this message translates to:
  /// **'Editar Operación'**
  String get editOperation;

  /// No description provided for @subscription.
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get subscription;

  /// No description provided for @redemption.
  ///
  /// In es, this message translates to:
  /// **'Reembolso'**
  String get redemption;

  /// No description provided for @unitsAtPrice.
  ///
  /// In es, this message translates to:
  /// **'{units} part. @ {price}'**
  String unitsAtPrice(String units, String price);

  /// No description provided for @deleteOperationTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar Operación'**
  String get deleteOperationTitle;

  /// No description provided for @areYouSure.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro?'**
  String get areYouSure;

  /// No description provided for @deleteOperationConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas eliminar esta operación?'**
  String get deleteOperationConfirm;

  /// No description provided for @deleteOperationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la operación'**
  String get deleteOperationFailed;

  /// No description provided for @deleteOperationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la operación. Haz un backup y reinicia la aplicación.'**
  String get deleteOperationError;

  /// No description provided for @restoreOperationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restaurar la operación. Haz un backup y reinicia la aplicación.'**
  String get restoreOperationError;

  /// No description provided for @operationDeletedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Operación eliminada correctamente'**
  String get operationDeletedSuccess;

  /// No description provided for @saveOperationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la operación'**
  String get saveOperationFailed;

  /// No description provided for @saveCostsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar los costes.'**
  String get saveCostsFailed;

  /// No description provided for @buy.
  ///
  /// In es, this message translates to:
  /// **'Compra'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In es, this message translates to:
  /// **'Venta'**
  String get sell;

  /// No description provided for @priceNavLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio (VL)'**
  String get priceNavLabel;

  /// No description provided for @unitsLabel.
  ///
  /// In es, this message translates to:
  /// **'Participaciones'**
  String get unitsLabel;

  /// No description provided for @totalAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'Importe Total'**
  String get totalAmountLabel;

  /// No description provided for @noHistoryForReturns.
  ///
  /// In es, this message translates to:
  /// **'No hay historial de precios para calcular rentabilidades.'**
  String get noHistoryForReturns;

  /// No description provided for @insufficientDataForHeatmap.
  ///
  /// In es, this message translates to:
  /// **'Datos insuficientes para generar el mapa de calor.'**
  String get insufficientDataForHeatmap;

  /// No description provided for @yearLabel.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get yearLabel;

  /// No description provided for @totalUnitsLabel.
  ///
  /// In es, this message translates to:
  /// **'Participaciones totales'**
  String get totalUnitsLabel;

  /// No description provided for @netInvestmentLabel.
  ///
  /// In es, this message translates to:
  /// **'Inversión neta'**
  String get netInvestmentLabel;

  /// No description provided for @avgPurchasePriceLabel.
  ///
  /// In es, this message translates to:
  /// **'Precio medio compra'**
  String get avgPurchasePriceLabel;

  /// No description provided for @currentValueLabel.
  ///
  /// In es, this message translates to:
  /// **'Valor actual'**
  String get currentValueLabel;

  /// No description provided for @grossProfitLabel.
  ///
  /// In es, this message translates to:
  /// **'Plusvalía Bruta'**
  String get grossProfitLabel;

  /// No description provided for @grossLossLabel.
  ///
  /// In es, this message translates to:
  /// **'Minusvalía Bruta'**
  String get grossLossLabel;

  /// No description provided for @realGainLabel.
  ///
  /// In es, this message translates to:
  /// **'Ganancia Real'**
  String get realGainLabel;

  /// No description provided for @netProfitEstLabel.
  ///
  /// In es, this message translates to:
  /// **'(Plusvalía Neta est.)'**
  String get netProfitEstLabel;

  /// No description provided for @netProfitRecordedLabel.
  ///
  /// In es, this message translates to:
  /// **'(Tras cargos externos registrados; VL ya neto)'**
  String get netProfitRecordedLabel;

  /// No description provided for @costPeriodsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tarifas por periodo'**
  String get costPeriodsTitle;

  /// No description provided for @costChargesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cargos externos registrados'**
  String get costChargesTitle;

  /// No description provided for @costPeriodsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay tarifas históricas registradas.'**
  String get costPeriodsEmpty;

  /// No description provided for @costChargesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay cargos externos registrados.'**
  String get costChargesEmpty;

  /// No description provided for @costHelpTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ayuda sobre los costes'**
  String get costHelpTooltip;

  /// No description provided for @costHelpTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo se contabilizan los costes'**
  String get costHelpTitle;

  /// No description provided for @costHelpNav.
  ///
  /// In es, this message translates to:
  /// **'El valor liquidativo (VL) normalmente ya descuenta los gastos propios del fondo. Los costes marcados como incluidos en el VL son informativos y no se restan otra vez.'**
  String get costHelpNav;

  /// No description provided for @costHelpTer.
  ///
  /// In es, this message translates to:
  /// **'El TER puede incluir gestión, depositaría y gastos operativos. Si registras el TER total, no sumes además sus componentes.'**
  String get costHelpTer;

  /// No description provided for @costHelpRates.
  ///
  /// In es, this message translates to:
  /// **'Las tarifas describen porcentajes y periodos, no importes pagados. Las tarifas externas recurrentes vigentes generan una estimación anual. La comisión de resultados potencial solo se muestra cuando está vinculada a una liquidación previa y hay valor liquidativo para comparar; si falta esa referencia, se oculta. Ninguna estimación modifica la plusvalía neta registrada.'**
  String get costHelpRates;

  /// No description provided for @costHelpExternal.
  ///
  /// In es, this message translates to:
  /// **'Registra como cargo externo solo el importe cobrado aparte al inversor, por ejemplo una comisión de entrada, salida, comercialización o custodia. Se admite desde la primera suscripción hasta hoy, aunque el VL disponible sea anterior.'**
  String get costHelpExternal;

  /// No description provided for @costHelpNet.
  ///
  /// In es, this message translates to:
  /// **'La plusvalía neta se calcula como plusvalía bruta menos los cargos externos registrados dentro del periodo de inversión. Los costes ya incluidos en el VL no vuelven a descontarse.'**
  String get costHelpNet;

  /// No description provided for @costEstimateTitle.
  ///
  /// In es, this message translates to:
  /// **'Estimación con tarifas vigentes'**
  String get costEstimateTitle;

  /// No description provided for @costAnnualEstimate.
  ///
  /// In es, this message translates to:
  /// **'Coste anual recurrente'**
  String get costAnnualEstimate;

  /// No description provided for @costAnnualEstimateNote.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje anual sobre la posición, valorada al último VL disponible. No se resta del neto.'**
  String get costAnnualEstimateNote;

  /// No description provided for @costPerformancePotential.
  ///
  /// In es, this message translates to:
  /// **'Comisión de resultados potencial'**
  String get costPerformancePotential;

  /// No description provided for @costPerformancePotentialNote.
  ///
  /// In es, this message translates to:
  /// **'Incremento estimado desde la última liquidación vinculada; no es anual ni se resta del neto.'**
  String get costPerformancePotentialNote;

  /// No description provided for @costPerformancePeriod.
  ///
  /// In es, this message translates to:
  /// **'Tarifa de resultados vinculada'**
  String get costPerformancePeriod;

  /// No description provided for @costSettlementUnlinked.
  ///
  /// In es, this message translates to:
  /// **'Sin tarifa vinculada'**
  String get costSettlementUnlinked;

  /// No description provided for @costSettlementPeriodUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Tarifa ya no disponible'**
  String get costSettlementPeriodUnavailable;

  /// No description provided for @costSettledThrough.
  ///
  /// In es, this message translates to:
  /// **'Liquidada hasta'**
  String get costSettledThrough;

  /// No description provided for @costSettlementUnspecified.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha de liquidación'**
  String get costSettlementUnspecified;

  /// No description provided for @costSettlementDateInvalid.
  ///
  /// In es, this message translates to:
  /// **'La fecha de liquidación no puede ser posterior al cargo.'**
  String get costSettlementDateInvalid;

  /// No description provided for @addCostPeriod.
  ///
  /// In es, this message translates to:
  /// **'Añadir tarifa'**
  String get addCostPeriod;

  /// No description provided for @editCostPeriod.
  ///
  /// In es, this message translates to:
  /// **'Editar tarifa'**
  String get editCostPeriod;

  /// No description provided for @addCostCharge.
  ///
  /// In es, this message translates to:
  /// **'Registrar cargo'**
  String get addCostCharge;

  /// No description provided for @editCostCharge.
  ///
  /// In es, this message translates to:
  /// **'Editar cargo'**
  String get editCostCharge;

  /// No description provided for @costConcept.
  ///
  /// In es, this message translates to:
  /// **'Concepto'**
  String get costConcept;

  /// No description provided for @costRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa (%)'**
  String get costRate;

  /// No description provided for @costBasis.
  ///
  /// In es, this message translates to:
  /// **'Base'**
  String get costBasis;

  /// No description provided for @costTreatment.
  ///
  /// In es, this message translates to:
  /// **'Tratamiento'**
  String get costTreatment;

  /// No description provided for @costStartDate.
  ///
  /// In es, this message translates to:
  /// **'Vigente desde'**
  String get costStartDate;

  /// No description provided for @costEndDate.
  ///
  /// In es, this message translates to:
  /// **'Vigente hasta (opcional)'**
  String get costEndDate;

  /// No description provided for @costNoEndDate.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha de fin'**
  String get costNoEndDate;

  /// No description provided for @costAnnualBalance.
  ///
  /// In es, this message translates to:
  /// **'% anual sobre el saldo'**
  String get costAnnualBalance;

  /// No description provided for @costPositiveProfit.
  ///
  /// In es, this message translates to:
  /// **'% sobre beneficio positivo'**
  String get costPositiveProfit;

  /// No description provided for @costIncludedInNav.
  ///
  /// In es, this message translates to:
  /// **'Incluido en VL'**
  String get costIncludedInNav;

  /// No description provided for @costChargedSeparately.
  ///
  /// In es, this message translates to:
  /// **'Cobrado aparte'**
  String get costChargedSeparately;

  /// No description provided for @costTreatmentUnknown.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de clasificar'**
  String get costTreatmentUnknown;

  /// No description provided for @costLegacyDateUnknown.
  ///
  /// In es, this message translates to:
  /// **'Periodo histórico sin fecha conocida'**
  String get costLegacyDateUnknown;

  /// No description provided for @costDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get costDescription;

  /// No description provided for @costAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe cobrado'**
  String get costAmount;

  /// No description provided for @costDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha del cargo'**
  String get costDate;

  /// No description provided for @costRateInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce una tasa válida igual o superior a cero.'**
  String get costRateInvalid;

  /// No description provided for @costPeriodInvalid.
  ///
  /// In es, this message translates to:
  /// **'La fecha final debe ser igual o posterior a la inicial.'**
  String get costPeriodInvalid;

  /// No description provided for @costPeriodOverlap.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una tarifa del mismo concepto en ese periodo.'**
  String get costPeriodOverlap;

  /// No description provided for @costChargeInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un importe cobrado mayor que cero.'**
  String get costChargeInvalid;

  /// No description provided for @deleteCostTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar coste'**
  String get deleteCostTitle;

  /// No description provided for @deleteCostConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres eliminar este registro?'**
  String get deleteCostConfirm;

  /// No description provided for @costConceptTer.
  ///
  /// In es, this message translates to:
  /// **'TER total'**
  String get costConceptTer;

  /// No description provided for @costConceptManagement.
  ///
  /// In es, this message translates to:
  /// **'Gestión'**
  String get costConceptManagement;

  /// No description provided for @costConceptDepositary.
  ///
  /// In es, this message translates to:
  /// **'Depositario'**
  String get costConceptDepositary;

  /// No description provided for @costConceptOperating.
  ///
  /// In es, this message translates to:
  /// **'Gastos operativos'**
  String get costConceptOperating;

  /// No description provided for @costConceptSubscription.
  ///
  /// In es, this message translates to:
  /// **'Suscripción o entrada'**
  String get costConceptSubscription;

  /// No description provided for @costConceptRedemption.
  ///
  /// In es, this message translates to:
  /// **'Reembolso o salida'**
  String get costConceptRedemption;

  /// No description provided for @costConceptTransfer.
  ///
  /// In es, this message translates to:
  /// **'Traspaso o cambio'**
  String get costConceptTransfer;

  /// No description provided for @costConceptDistributor.
  ///
  /// In es, this message translates to:
  /// **'Comercializador o intermediario'**
  String get costConceptDistributor;

  /// No description provided for @costConceptCustody.
  ///
  /// In es, this message translates to:
  /// **'Custodia o mantenimiento'**
  String get costConceptCustody;

  /// No description provided for @costConceptPerformance.
  ///
  /// In es, this message translates to:
  /// **'Comisión de resultados'**
  String get costConceptPerformance;

  /// No description provided for @costConceptTax.
  ///
  /// In es, this message translates to:
  /// **'Impuestos asociados'**
  String get costConceptTax;

  /// No description provided for @costConceptOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get costConceptOther;

  /// No description provided for @managementFeesTitle.
  ///
  /// In es, this message translates to:
  /// **'Costes de Gestión'**
  String get managementFeesTitle;

  /// No description provided for @fixedFeesLabel.
  ///
  /// In es, this message translates to:
  /// **'Gastos Corrientes'**
  String get fixedFeesLabel;

  /// No description provided for @fixedFeesHint.
  ///
  /// In es, this message translates to:
  /// **'Fijos'**
  String get fixedFeesHint;

  /// No description provided for @perfFeesLabel.
  ///
  /// In es, this message translates to:
  /// **'Com. Resultados'**
  String get perfFeesLabel;

  /// No description provided for @perfFeesHint.
  ///
  /// In es, this message translates to:
  /// **'Sobre éxito'**
  String get perfFeesHint;

  /// No description provided for @annualCostEstLabel.
  ///
  /// In es, this message translates to:
  /// **'Coste Anual Est.'**
  String get annualCostEstLabel;

  /// No description provided for @monthlyCostEstLabel.
  ///
  /// In es, this message translates to:
  /// **'Coste Mensual Est.'**
  String get monthlyCostEstLabel;

  /// No description provided for @profitabilityIndicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Índices de Rentabilidad'**
  String get profitabilityIndicesTitle;

  /// No description provided for @annualizedReturnLabel.
  ///
  /// In es, this message translates to:
  /// **'Rent. Anualizada'**
  String get annualizedReturnLabel;

  /// No description provided for @moicLabel.
  ///
  /// In es, this message translates to:
  /// **'Multiplicador (MoIC)'**
  String get moicLabel;

  /// No description provided for @ageLabel.
  ///
  /// In es, this message translates to:
  /// **'Antigüedad'**
  String get ageLabel;

  /// No description provided for @breakEvenLabel.
  ///
  /// In es, this message translates to:
  /// **'Break-even'**
  String get breakEvenLabel;

  /// No description provided for @financialIndicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Índices Financieros'**
  String get financialIndicesTitle;

  /// No description provided for @bruteReturnsNote.
  ///
  /// In es, this message translates to:
  /// **'Rentabilidades brutas sin consideración de costes ni comisiones.'**
  String get bruteReturnsNote;

  /// No description provided for @aprTaeDesc.
  ///
  /// In es, this message translates to:
  /// **'Rentabilidad simple de TU inversión basándose en el capital total aportado y el tiempo transcurrido.'**
  String get aprTaeDesc;

  /// No description provided for @twrDesc.
  ///
  /// In es, this message translates to:
  /// **'Time-Weighted Return. Mide el rendimiento del FONDO, eliminando el impacto de tus entradas y salidas de dinero. Es la rentabilidad del activo en sí.'**
  String get twrDesc;

  /// No description provided for @mwrIrrDesc.
  ///
  /// In es, this message translates to:
  /// **'Money-Weighted Return (o TIR). Rentabilidad real de tu bolsillo que tiene en cuenta el momento exacto de cada aportación. Refleja tu éxito como inversor al elegir cuándo entrar y salir.'**
  String get mwrIrrDesc;

  /// No description provided for @moicDesc.
  ///
  /// In es, this message translates to:
  /// **'Capital final obtenido por cada euro invertido.'**
  String get moicDesc;

  /// No description provided for @ageDesc.
  ///
  /// In es, this message translates to:
  /// **'Tiempo transcurrido desde la primera suscripción.'**
  String get ageDesc;

  /// No description provided for @breakEvenDesc.
  ///
  /// In es, this message translates to:
  /// **'Precio necesario para no tener pérdidas.'**
  String get breakEvenDesc;

  /// No description provided for @fixedFeesSuffix.
  ///
  /// In es, this message translates to:
  /// **'% TER'**
  String get fixedFeesSuffix;

  /// No description provided for @perfFeesSuffix.
  ///
  /// In es, this message translates to:
  /// **'% Éxito'**
  String get perfFeesSuffix;

  /// No description provided for @twrTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'TWR (Total)'**
  String get twrTotalLabel;

  /// No description provided for @twrAnnualizedLabel.
  ///
  /// In es, this message translates to:
  /// **'TWR Anualizada'**
  String get twrAnnualizedLabel;

  /// No description provided for @mwrHistoricalLabel.
  ///
  /// In es, this message translates to:
  /// **'MWR Acumulado'**
  String get mwrHistoricalLabel;

  /// No description provided for @mwrAnnualizedLabel.
  ///
  /// In es, this message translates to:
  /// **'MWR Anualizada'**
  String get mwrAnnualizedLabel;

  /// No description provided for @twrInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'TWR (Total / Anualizada)'**
  String get twrInfoTitle;

  /// No description provided for @mwrInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'MWR (Acumulado / Anualizada)'**
  String get mwrInfoTitle;

  /// No description provided for @monthsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 mes} other{{count} meses}}'**
  String monthsCount(num count);

  /// No description provided for @yearsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 año} other{{count} años}}'**
  String yearsCount(num count);

  /// No description provided for @andLabel.
  ///
  /// In es, this message translates to:
  /// **'y'**
  String get andLabel;

  /// No description provided for @noDataInRange.
  ///
  /// In es, this message translates to:
  /// **'No hay datos en este rango'**
  String get noDataInRange;

  /// No description provided for @averageLabelShort.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get averageLabelShort;

  /// No description provided for @compareLabel.
  ///
  /// In es, this message translates to:
  /// **'Comparar'**
  String get compareLabel;

  /// No description provided for @comparePageTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparador'**
  String get comparePageTitle;

  /// No description provided for @compareFundSelection.
  ///
  /// In es, this message translates to:
  /// **'Fondos para comparar'**
  String get compareFundSelection;

  /// No description provided for @comparePortfolioNeedsTwo.
  ///
  /// In es, this message translates to:
  /// **'Necesitas al menos dos fondos en cartera para compararlos.'**
  String get comparePortfolioNeedsTwo;

  /// No description provided for @compareSelectFund.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un fondo'**
  String get compareSelectFund;

  /// No description provided for @compareFundOne.
  ///
  /// In es, this message translates to:
  /// **'Primer fondo'**
  String get compareFundOne;

  /// No description provided for @compareFundTwo.
  ///
  /// In es, this message translates to:
  /// **'Segundo fondo'**
  String get compareFundTwo;

  /// No description provided for @compareChooseDifferentFunds.
  ///
  /// In es, this message translates to:
  /// **'Selecciona dos fondos diferentes.'**
  String get compareChooseDifferentFunds;

  /// No description provided for @compareResults.
  ///
  /// In es, this message translates to:
  /// **'Resultado de la comparación'**
  String get compareResults;

  /// No description provided for @compareChartTitle.
  ///
  /// In es, this message translates to:
  /// **'Evolución histórica'**
  String get compareChartTitle;

  /// No description provided for @compareChartNoData.
  ///
  /// In es, this message translates to:
  /// **'No hay historial común suficiente para mostrar el gráfico.'**
  String get compareChartNoData;

  /// No description provided for @compareMarketHistory.
  ///
  /// In es, this message translates to:
  /// **'Fondo e historial'**
  String get compareMarketHistory;

  /// No description provided for @compareInvestmentPosition.
  ///
  /// In es, this message translates to:
  /// **'Tu inversión'**
  String get compareInvestmentPosition;

  /// No description provided for @compareNoSharedPositions.
  ///
  /// In es, this message translates to:
  /// **'Las métricas de inversión requieren una posición abierta en ambos fondos.'**
  String get compareNoSharedPositions;

  /// No description provided for @compareHistoryStart.
  ///
  /// In es, this message translates to:
  /// **'Primer valor disponible'**
  String get compareHistoryStart;

  /// No description provided for @compareCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get compareCurrency;

  /// No description provided for @compareLastNav.
  ///
  /// In es, this message translates to:
  /// **'Último valor liquidativo'**
  String get compareLastNav;

  /// No description provided for @compareLastChange.
  ///
  /// In es, this message translates to:
  /// **'Última variación'**
  String get compareLastChange;

  /// No description provided for @compareMonthChange.
  ///
  /// In es, this message translates to:
  /// **'Variación en 1 mes'**
  String get compareMonthChange;

  /// No description provided for @compareSixMonthChange.
  ///
  /// In es, this message translates to:
  /// **'Variación en 6 meses'**
  String get compareSixMonthChange;

  /// No description provided for @compareYearChange.
  ///
  /// In es, this message translates to:
  /// **'Variación en 1 año'**
  String get compareYearChange;

  /// No description provided for @compareSinceInceptionChange.
  ///
  /// In es, this message translates to:
  /// **'Variación desde el inicio'**
  String get compareSinceInceptionChange;

  /// No description provided for @compareAnnualVolatility.
  ///
  /// In es, this message translates to:
  /// **'Volatilidad anualizada'**
  String get compareAnnualVolatility;

  /// No description provided for @compareCosts.
  ///
  /// In es, this message translates to:
  /// **'Costes y comisiones'**
  String get compareCosts;

  /// No description provided for @compareMorningstarRating.
  ///
  /// In es, this message translates to:
  /// **'Rating Morningstar'**
  String get compareMorningstarRating;

  /// No description provided for @compareTer.
  ///
  /// In es, this message translates to:
  /// **'TER'**
  String get compareTer;

  /// No description provided for @compareInvested.
  ///
  /// In es, this message translates to:
  /// **'Capital invertido'**
  String get compareInvested;

  /// No description provided for @compareCurrentValue.
  ///
  /// In es, this message translates to:
  /// **'Valor actual'**
  String get compareCurrentValue;

  /// No description provided for @compareProfit.
  ///
  /// In es, this message translates to:
  /// **'Plusvalía'**
  String get compareProfit;

  /// No description provided for @compareReturn.
  ///
  /// In es, this message translates to:
  /// **'Rentabilidad de la posición'**
  String get compareReturn;

  /// No description provided for @compareTwr.
  ///
  /// In es, this message translates to:
  /// **'TWR anualizado'**
  String get compareTwr;

  /// No description provided for @compareMwr.
  ///
  /// In es, this message translates to:
  /// **'TIR anualizada'**
  String get compareMwr;

  /// No description provided for @compareMoic.
  ///
  /// In es, this message translates to:
  /// **'MOIC'**
  String get compareMoic;

  /// No description provided for @compareWithBenchmark.
  ///
  /// In es, this message translates to:
  /// **'Comparar con benchmark'**
  String get compareWithBenchmark;

  /// No description provided for @noneLabel.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get noneLabel;

  /// No description provided for @fundPercentLabel.
  ///
  /// In es, this message translates to:
  /// **'Fondo (%)'**
  String get fundPercentLabel;

  /// No description provided for @benchmarkPercentLabel.
  ///
  /// In es, this message translates to:
  /// **'Benchmark (%)'**
  String get benchmarkPercentLabel;

  /// No description provided for @sp500Desc.
  ///
  /// In es, this message translates to:
  /// **'El S&P 500 es un índice bursátil que agrupa a las 500 empresas más grandes y representativas de Estados Unidos.'**
  String get sp500Desc;

  /// No description provided for @msciWorldDesc.
  ///
  /// In es, this message translates to:
  /// **'El MSCI World es un índice que representa el rendimiento de empresas de mediana y gran capitalización en 23 países desarrollados.'**
  String get msciWorldDesc;

  /// No description provided for @euroStoxx50Desc.
  ///
  /// In es, this message translates to:
  /// **'El EuroStoxx 50 representa a las 50 empresas más grandes y líquidas de la eurozona.'**
  String get euroStoxx50Desc;

  /// No description provided for @ibex35Desc.
  ///
  /// In es, this message translates to:
  /// **'El IBEX 35 es el índice de referencia de la bolsa española, compuesto por las 35 empresas con más liquidez.'**
  String get ibex35Desc;

  /// No description provided for @nasdaq100Desc.
  ///
  /// In es, this message translates to:
  /// **'El Nasdaq 100 incluye a las 100 mayores empresas no financieras que cotizan en el mercado Nasdaq, con gran peso tecnológico.'**
  String get nasdaq100Desc;

  /// No description provided for @dax40Desc.
  ///
  /// In es, this message translates to:
  /// **'El DAX 40 es el índice de referencia de la bolsa alemana, compuesto por las 40 principales empresas de este mercado.'**
  String get dax40Desc;

  /// No description provided for @cac40Desc.
  ///
  /// In es, this message translates to:
  /// **'El CAC 40 es el principal índice bursátil francés, que agrupa a las 40 empresas más significativas de la Bolsa de París.'**
  String get cac40Desc;

  /// No description provided for @nikkei225Desc.
  ///
  /// In es, this message translates to:
  /// **'El Nikkei 225 es el índice más importante de la bolsa japonesa, compuesto por las 225 empresas más líquidas de Tokio.'**
  String get nikkei225Desc;

  /// No description provided for @portfolioAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Alertas de Fondos!'**
  String get portfolioAlertsTitle;

  /// No description provided for @portfolioAlertsDesc.
  ///
  /// In es, this message translates to:
  /// **'Se han alcanzado los siguientes límites configurados en tus fondos:'**
  String get portfolioAlertsDesc;

  /// No description provided for @alertMinReached.
  ///
  /// In es, this message translates to:
  /// **'El fondo {fundName} ha caído por debajo del límite de {limit}: Valor actual {current}'**
  String alertMinReached(String fundName, String current, String limit);

  /// No description provided for @alertMaxReached.
  ///
  /// In es, this message translates to:
  /// **'El fondo {fundName} ha superado el límite de {limit}: Valor actual {current}'**
  String alertMaxReached(String fundName, String current, String limit);

  /// No description provided for @localCatalog.
  ///
  /// In es, this message translates to:
  /// **'Catálogo Local'**
  String get localCatalog;

  /// No description provided for @localCatalogDesc.
  ///
  /// In es, this message translates to:
  /// **'Fondos armonizados del catálogo local.'**
  String get localCatalogDesc;

  /// No description provided for @morningstarSource.
  ///
  /// In es, this message translates to:
  /// **'Morningstar'**
  String get morningstarSource;

  /// No description provided for @morningstarSourceDesc.
  ///
  /// In es, this message translates to:
  /// **'Fondos extranjeros resueltos mediante Morningstar LT.'**
  String get morningstarSourceDesc;

  /// No description provided for @yahooSource.
  ///
  /// In es, this message translates to:
  /// **'Yahoo Finance'**
  String get yahooSource;

  /// No description provided for @yahooSourceDesc.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda y cotizaciones globales en Yahoo Finance.'**
  String get yahooSourceDesc;

  /// No description provided for @csvHeaderDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get csvHeaderDate;

  /// No description provided for @csvHeaderIsin.
  ///
  /// In es, this message translates to:
  /// **'ISIN'**
  String get csvHeaderIsin;

  /// No description provided for @csvHeaderFundName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del Fondo'**
  String get csvHeaderFundName;

  /// No description provided for @csvHeaderOperationType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de Operación'**
  String get csvHeaderOperationType;

  /// No description provided for @csvHeaderUnits.
  ///
  /// In es, this message translates to:
  /// **'Unidades'**
  String get csvHeaderUnits;

  /// No description provided for @csvHeaderUnitPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio Unitario'**
  String get csvHeaderUnitPrice;

  /// No description provided for @csvHeaderTotalAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe Total'**
  String get csvHeaderTotalAmount;

  /// No description provided for @csvHeaderCurrency.
  ///
  /// In es, this message translates to:
  /// **'Divisa'**
  String get csvHeaderCurrency;

  /// No description provided for @saveOperationsReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar informe de operaciones'**
  String get saveOperationsReportTitle;

  /// No description provided for @annualPortfolioReport.
  ///
  /// In es, this message translates to:
  /// **'Informe Anual de Cartera'**
  String get annualPortfolioReport;

  /// No description provided for @executiveSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen Ejecutivo'**
  String get executiveSummary;

  /// No description provided for @fundDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle por Fondo'**
  String get fundDetail;

  /// No description provided for @returnPercentLabel.
  ///
  /// In es, this message translates to:
  /// **'Rent. %'**
  String get returnPercentLabel;

  /// No description provided for @legalNotice.
  ///
  /// In es, this message translates to:
  /// **'Aviso Legal'**
  String get legalNotice;

  /// No description provided for @legalNoticeText.
  ///
  /// In es, this message translates to:
  /// **'Este informe ha sido generado automáticamente por OpenInvest el {date}. Los datos se han obtenido de fuentes públicas y pueden contener imprecisiones. Este documento no constituye asesoramiento financiero. Verifique siempre los datos con su entidad financiera antes de tomar decisiones.'**
  String legalNoticeText(String date);

  /// No description provided for @pdfFooter.
  ///
  /// In es, this message translates to:
  /// **'OpenInvest - Informe Anual {year} - Página {page} de {total}'**
  String pdfFooter(String year, String page, String total);

  /// No description provided for @saveAnnualReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar informe anual'**
  String get saveAnnualReportTitle;

  /// No description provided for @operationsCsv.
  ///
  /// In es, this message translates to:
  /// **'Operaciones CSV'**
  String get operationsCsv;

  /// No description provided for @pdfReportLabel.
  ///
  /// In es, this message translates to:
  /// **'Informe PDF'**
  String get pdfReportLabel;

  /// No description provided for @selectReportYear.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el año del informe'**
  String get selectReportYear;

  /// No description provided for @reportSavedSuccess.
  ///
  /// In es, this message translates to:
  /// **'✓ Informe guardado: {fileName}'**
  String reportSavedSuccess(String fileName);

  /// No description provided for @exportCancelledOrFailed.
  ///
  /// In es, this message translates to:
  /// **'Exportación cancelada o fallida.'**
  String get exportCancelledOrFailed;

  /// No description provided for @pdfGenerationError.
  ///
  /// In es, this message translates to:
  /// **'Error al generar el PDF: {error}'**
  String pdfGenerationError(String error);

  /// No description provided for @openAction.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get openAction;

  /// No description provided for @reportGeneratedTitle.
  ///
  /// In es, this message translates to:
  /// **'Informe generado'**
  String get reportGeneratedTitle;

  /// No description provided for @annualReportReadyMessage.
  ///
  /// In es, this message translates to:
  /// **'El informe anual de {year} está listo. ¿Qué deseas hacer?'**
  String annualReportReadyMessage(String year);

  /// No description provided for @previewAndPrint.
  ///
  /// In es, this message translates to:
  /// **'Previsualizar / Imprimir'**
  String get previewAndPrint;

  /// No description provided for @creditsTitle.
  ///
  /// In es, this message translates to:
  /// **'Créditos'**
  String get creditsTitle;

  /// No description provided for @creditsDesc.
  ///
  /// In es, this message translates to:
  /// **'OpenInvest — Proyecto de código abierto desarrollado por Webierta.\n\nHerramientas de IA — ChatGPT · OpenAI, GitHub Copilot y Google Gemini — Asistencia en arquitectura de software, investigación técnica y pruebas, generación, depuración y revisión de código, seguridad y automatización.'**
  String get creditsDesc;

  /// No description provided for @generateFilesLabel.
  ///
  /// In es, this message translates to:
  /// **'Generar archivos'**
  String get generateFilesLabel;

  /// No description provided for @exportPortfolioMenu.
  ///
  /// In es, this message translates to:
  /// **'Exportar cartera'**
  String get exportPortfolioMenu;

  /// No description provided for @importPortfolioMenu.
  ///
  /// In es, this message translates to:
  /// **'Importar cartera'**
  String get importPortfolioMenu;

  /// No description provided for @portfolioExportedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cartera exportada correctamente'**
  String get portfolioExportedSuccess;

  /// No description provided for @portfolioImportedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cartera importada con fusión inteligente'**
  String get portfolioImportedSuccess;

  /// No description provided for @compareInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparador de Fondos'**
  String get compareInfoTitle;

  /// No description provided for @compareInfoDesc.
  ///
  /// In es, this message translates to:
  /// **'Compara dos fondos de tu cartera lado a lado: evolución histórica con gráficos normalizados, comparativa de rentabilidades (1M, 6M, 1A, Total), volatilidad, costes (TER), rating Morningstar y posición de inversión personal.'**
  String get compareInfoDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
