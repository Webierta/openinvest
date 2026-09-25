# OpenInvest
<img src="assets/images/logo.png" width="150" height="150" alt="Logo">

[![GitHub release](https://img.shields.io/github/release/Webierta/openinvest?include_prereleases=&sort=semver&color=blue)](https://github.com/Webierta/openinvest/releases/)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue)](https://github.com/Webierta/openinvest/blob/main/LICENSE)
[![issues - openinvest](https://img.shields.io/github/issues/Webierta/openinvest)](https://github.com/Webierta/openinvest/issues)
[![Get it on - Obtainium](https://img.shields.io/badge/Get_it_on-Obtainium-2ea44f?logo=Obtainium)](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22com.github.webierta.openinvest%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2FWebierta%2Fopeninvest%22%2C%22author%22%3A%22Webierta%22%2C%22name%22%3A%22OpenInvest%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22includePrereleases%5C%22%3Afalse%2C%5C%22fallbackToOlderReleases%5C%22%3Atrue%2C%5C%22filterReleaseTitlesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22filterReleaseNotesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22verifyLatestTag%5C%22%3Afalse%2C%5C%22sortMethodChoice%5C%22%3A%5C%22date%5C%22%3A%5C%22useLatestAssetDateAsReleaseDate%5C%22%3Afalse%2C%5C%22releaseTitleAsVersion%5C%22%3Afalse%2C%5C%22trackOnly%5C%22%3Afalse%2C%5C%22versionExtractionRegEx%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22matchGroupToUse%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22versionDetection%5C%22%3Atrue%2C%5C%22releaseDateAsVersion%5C%22%3Afalse%2C%5C%22useVersionCodeAsOSVersion%5C%22%3Afalse%2C%5C%22apkFilterRegEx%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22invertAPKFilter%5C%22%3Afalse%2C%5C%22autoApkFilterByArch%5C%22%3Atrue%2C%5C%22appName%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22appAuthor%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22shizukuPretendToBeGooglePlay%5C%22%3Afalse%2C%5C%22allowInsecure%5C%22%3Afalse%2C%5C%22exemptFromBackgroundUpdates%5C%22%3Afalse%2C%5C%22skipUpdateNotifications%5C%22%3Afalse%2C%5C%22about%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22refreshBeforeDownload%5C%22%3Afalse%2C%5C%22github-creds%5C%22%3A%5C%22%5C%22%5C%22%2C%5C%22GHReqPrefix%5C%22%3A%5C%22%5C%22%7D%22%2C%22overrideSource%22%3A%22GitHub%22%7D)

Aplicación de código abierto para la gestión de una cartera de fondos de inversión.

## Funciones principales

- **Búsqueda de Fondos**: Busca cualquier fondo de inversión del mundo utilizando su código ISIN. Obtenemos los datos en tiempo real a través de fuentes públicas financieras.
- **Historial de Precios**: Descarga el histórico de valores liquidativos (VL) para analizar la evolución temporal. Puedes seleccionar rangos de fechas personalizados.
- **Gestión de Operaciones**: Registra tus suscripciones (compras) y reembolsos (ventas). La aplicación calcula automáticamente tus participaciones totales y capital invertido.
- **Análisis de Rentabilidad**: Cálculo de índices avanzados para un análisis profesional:
  - **TAE**: Rentabilidad anualizada de tu bolsillo.
  - **TWR**: Rendimiento real del fondo (activo), eliminando el efecto de tus flujos de caja.
  - **MWR/TIR**: Tu éxito personal basado en el momento exacto de cada inversión.
- **Auditoría de Costes**: Introduce los Gastos Corrientes (TER) y la Comisión de Éxito de tus fondos para calcular la Ganancia Real neta, descontando el impacto de las comisiones en tu capital.
- **Gráficos Interactivos**: Visualiza la evolución de tus fondos con filtros de rango rápido (1M, 6M, 1Y, ALL) y líneas de tendencia media.
- **Mapa de Calor Mensual**: Analiza la estacionalidad de tus inversiones con una cuadrícula de rentabilidades mes a mes y acumulados anuales, identificando periodos de éxito y correcciones.
- **Comparación con Benchmarks**: Superpón la evolución de los principales índices mundiales (S&P 500, MSCI World, etc.) sobre el gráfico del fondo para medir su rendimiento relativo en porcentaje.
- **Análisis de Riesgo**: Métricas de nivel profesional para evaluar la seguridad:  Max Drawdown: La mayor caída histórica desde un pico.\n• Recuperación: Tiempo que el fondo tarda en sanar sus pérdidas.
- **Exportación e Importación**: Lleva tus datos contigo. Exporta e importa tus fondos y operaciones en formato JSON para moverlos entre dispositivos o hacer copias de seguridad.
- **Soporte Multidivisa**: Gestión automática de fondos en diversas divisas con conversión en tiempo real.
- **Notificaciones**: Recibe alertas configurables para estar al tanto de tus fondos y objetivos.


## Información del Proyecto

- **Licencia**: Esta aplicación es Software Libre bajo la licencia GNU General Public License v3 (GPLv3).
- **Código Abierto**: El código fuente está disponible públicamente en nuestro repositorio de GitHub: [github.com/Webierta/openinvest](https://github.com/Webierta/openinvest)
- **Fuente de Datos**: Los datos financieros y cotizaciones se obtienen de Yahoo Finance a través de técnicas de scraping.
- **Privacidad y Seguridad**: OpenInvest es una aplicación 100% gratuita y sin publicidad. No recopilamos datos personales. Toda tu información financiera se guarda exclusivamente de forma local en tu dispositivo.
- **Garantía y Responsabilidad**: La aplicación se proporciona "tal cual", sin garantía de ningún tipo. No constituye asesoramiento financiero profesional. Invierte bajo tu propio riesgo.

## Plataformas soportadas

- **Android**
- **Linux (Desktop)**

---
Desarrollado por *Webierta*


