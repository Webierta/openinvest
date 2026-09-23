// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenInvest';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get spanish => 'Spanish';

  @override
  String get english => 'English';

  @override
  String get security => 'Security';

  @override
  String get protectedAccess => 'Protected Access';

  @override
  String get supportOpenInvest => 'Support OpenInvest';

  @override
  String get helloDeveloper => 'Hi! I\'m the developer of OpenInvest';

  @override
  String get supportDescription =>
      'OpenInvest is an open source tool created to help investors manage their portfolios for free and privately. If you find the app useful, consider supporting it to ensure its future maintenance and evolution.';

  @override
  String get githubTitle => 'Send Suggestions or Bugs';

  @override
  String get githubDescription =>
      'Do you have any ideas for improvement or have you found a bug? Tell me about it in the official repository.';

  @override
  String get githubButton => 'Go to GitHub';

  @override
  String get paypalTitle => 'Donate via PayPal';

  @override
  String get paypalDescription =>
      'Donations help cover development and info server costs.';

  @override
  String get paypalButton => 'Donate with PayPal';

  @override
  String get bitcoinTitle => 'Donate via Bitcoin';

  @override
  String get bitcoinDescription =>
      'You can also send your support through the Bitcoin network.';

  @override
  String get copyAddress => 'Copy Address';

  @override
  String get bitcoinCopied => 'Bitcoin address copied to clipboard';

  @override
  String get thanksForUsing => 'Thanks a lot for using OpenInvest!';

  @override
  String get authFailed => 'Authentication failed or canceled';

  @override
  String get setAppPassword => 'Set App Password';

  @override
  String get setAppPasswordDescription =>
      'Define a password to protect access to OpenInvest on this device.';

  @override
  String get password => 'Password';

  @override
  String get minCharacters => 'Minimum 4 characters';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get requirePasswordSubtitle => 'Require app password to enter.';

  @override
  String get requireBiometricSubtitle =>
      'Require fingerprint, face or device PIN to enter.';

  @override
  String get noBiometricSupport =>
      'Your device does not support biometric authentication.';

  @override
  String get changePassword => 'Change password';

  @override
  String get data => 'Data';

  @override
  String get autoRefreshTitle => 'Update funds on startup';

  @override
  String get autoRefreshSubtitle =>
      'Update when data is at least one day old and has not been updated in the last 24 hours.';

  @override
  String get protectedAccessTitle => 'Protected access';

  @override
  String get appPasswordLabel => 'App password';

  @override
  String get enterPasswordError => 'Enter the password';

  @override
  String get enter => 'Enter';

  @override
  String get authRequiredDescription => 'Please authenticate to continue.';

  @override
  String get retry => 'Retry';

  @override
  String get info => 'Information';

  @override
  String get searchFundsTitle => 'Fund Search';

  @override
  String get searchFundsDesc =>
      'Search for any investment fund in the world using its ISIN code. We obtain real-time data through public financial sources.';

  @override
  String get priceHistoryTitle => 'Price History';

  @override
  String get priceHistoryDesc =>
      'Download the history of net asset values (NAV) to analyze temporal evolution. You can select custom date ranges.';

  @override
  String get operationsMgmtTitle => 'Operations Management';

  @override
  String get operationsMgmtDesc =>
      'Record your subscriptions (buys) and redemptions (sells). The app automatically calculates your total units and invested capital.';

  @override
  String get profitabilityAnalysisTitle => 'Profitability Analysis';

  @override
  String get profitabilityAnalysisDesc =>
      'Advanced index calculation:\n• APR/TAE: Annualized return for your pocket.\n• TWR: Real performance of the fund (asset).\n• MWR/IRR: Your personal success based on the investment timing.';

  @override
  String get costsAuditTitle => 'Costs Audit';

  @override
  String get costsAuditDesc =>
      'Enter the Total Expense Ratio (TER) and Performance Fee of your funds to calculate the Net Real Profit, discounting the impact of fees on your capital.';

  @override
  String get interactiveChartsTitle => 'Interactive Charts';

  @override
  String get interactiveChartsDesc =>
      'Visualize the evolution of your funds with quick range filters (1M, 6M, 1Y, etc.) and average trend lines.';

  @override
  String get monthlyHeatmapTitle => 'Monthly Heatmap';

  @override
  String get monthlyHeatmapDesc =>
      'Analyze the seasonality of your investments with a grid of month-by-month returns and annual totals, identifying periods of success and corrections.';

  @override
  String get benchmarkComparisonTitle => 'Benchmark Comparison';

  @override
  String get benchmarkComparisonDesc =>
      'Overlay the evolution of major world indices (S&P 500, MSCI World, etc.) on the fund chart to measure its relative performance in percentage.';

  @override
  String get riskAnalysisTitle => 'Risk Analysis';

  @override
  String get riskAnalysisDesc =>
      'Professional-grade metrics to assess safety:\n• Max Drawdown: The largest historical drop from a peak.\n• Recovery: Time the fund takes to heal its losses.';

  @override
  String get exportImportTitle => 'Export and Import';

  @override
  String get exportImportDesc =>
      'Take your data with you. Export and import your funds and operations in JSON format to move them between devices or make backups.';

  @override
  String get multicurrencySupportTitle => 'Multicurrency Support';

  @override
  String get multicurrencySupportDesc =>
      'Automatic management of funds in various currencies with real-time conversion for an accurate valuation of your global portfolio.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsDesc =>
      'Set up personalized alerts to stay informed about your funds and financial goals.';

  @override
  String get about => 'About';

  @override
  String get support => 'Support';

  @override
  String get exit => 'Exit';

  @override
  String get aboutOpenInvest => 'About OpenInvest';

  @override
  String get licenseTitle => 'License';

  @override
  String get licenseDesc =>
      'This app is Free Software under the GNU General Public License v3 (GPLv3).';

  @override
  String get openSourceTitle => 'Open Source';

  @override
  String get openSourceDesc =>
      'The source code is publicly available in our GitHub repository:\ngithub.com/Webierta/openinvest';

  @override
  String get dataSourceTitle => 'Data Source';

  @override
  String get dataSourceDesc =>
      'Financial data and quotes are obtained from Yahoo Finance. OpenInvest is not responsible for the accuracy of data provided by third parties.';

  @override
  String get permissionsTitle => 'Permissions';

  @override
  String get permissionsDesc =>
      '• Internet: To download real-time quotes.\n• Storage: To export and import JSON backup files.';

  @override
  String get warrantyTitle => 'Warranty and Liability';

  @override
  String get warrantyDesc =>
      'The app is provided \"as is\", without warranty of any kind. It does not constitute professional financial advice. Invest at your own risk.';

  @override
  String get privacyTitle => 'Privacy and Security';

  @override
  String get privacyDesc =>
      'OpenInvest is a 100% free app without ads. We do not collect personal data. All your financial information is stored exclusively locally on your device.';

  @override
  String get versionLabel => 'Version';

  @override
  String get addFund => 'Add Fund';

  @override
  String get resultsInfo => 'Information about results';

  @override
  String get searchFundPrompt => 'Search for a fund to add to your portfolio';

  @override
  String get fundSearchLabel => 'Name or ISIN code';

  @override
  String get fundSearchHint => 'Ex: Amundi or ES0152743003';

  @override
  String get searchFundAction => 'Search fund';

  @override
  String get isinNotAvailable => 'ISIN not available';

  @override
  String get fundFound => 'Fund Found';

  @override
  String get fundFoundDesc => 'The following fund has been found:';

  @override
  String get noValidIsinDesc =>
      'This asset does not provide a valid ISIN code and cannot be added to the portfolio.';

  @override
  String get resolved => 'RESOLVED';

  @override
  String get addToPortfolioPrompt => 'Do you want to add it to your portfolio?';

  @override
  String get close => 'Close';

  @override
  String get addToPortfolioAction => 'Add to Portfolio';

  @override
  String get fundAlreadyInPortfolio => 'Fund already exists';

  @override
  String overwriteFundDesc(String fundName) {
    return '$fundName is already in your portfolio. Do you want to overwrite it? Its current data, including history and operations, will be deleted.';
  }

  @override
  String get overwrite => 'Overwrite';

  @override
  String get processingFund => 'Processing fund and identifying ISIN...';

  @override
  String get processingWait => 'This operation may take a few seconds';

  @override
  String get dataSource => 'Data Source';

  @override
  String get cnmvRegistry => 'CNMV Registry';

  @override
  String get cnmvDesc =>
      'Harmonized Spanish funds. Data comes from the official catalog of the National Securities Market Commission.';

  @override
  String get globalMarket => 'Global Market';

  @override
  String get globalMarketDesc =>
      'International funds and ETFs. Data is obtained from Yahoo Finance.';

  @override
  String get isinNotDetected => 'ISIN not detected';

  @override
  String get isinNotDetectedDesc =>
      'Yahoo Finance has not provided the ISIN code for this result. We will try to obtain it from metadata or use the symbol as an identifier.\n\nDo you want to continue?';

  @override
  String get continueText => 'Continue';

  @override
  String get global => 'GLOBAL';

  @override
  String get updatePortfolioTooltip => 'Update all portfolio';

  @override
  String get sortPortfolioTooltip => 'Sort portfolio';

  @override
  String get sortByAlpha => 'Name';

  @override
  String get sortByValue => 'Value';

  @override
  String get sortByPerformance => 'TAE';

  @override
  String get moreOptionsTooltip => 'More options';

  @override
  String get importFundJson => 'Import fund (JSON)';

  @override
  String get fundImportedSuccess => 'Fund imported successfully';

  @override
  String get clearPortfolioTitle => 'Clear Portfolio';

  @override
  String get clearPortfolioConfirm =>
      'Are you sure you want to delete all funds from your portfolio?';

  @override
  String get clearPortfolioAction => 'Clear portfolio';

  @override
  String get delete => 'Delete';

  @override
  String get portfolioLoadError => 'Could not load portfolio data.';

  @override
  String get emptyPortfolio => 'Your portfolio is empty.';

  @override
  String get addFirstFund => 'Add my first fund';

  @override
  String get portfolioSummary => 'PORTFOLIO SUMMARY';

  @override
  String get invested => 'Invested';

  @override
  String get gain => 'GAIN';

  @override
  String get totalGain => 'TOTAL GAIN';

  @override
  String get valueLabel => 'VALUE';

  @override
  String get performanceLabel => 'PERFORMANCE';

  @override
  String get weightLabel => 'Weight';

  @override
  String get noQuoteData => 'No quote data.';

  @override
  String get navLabel => 'Net Asset Value';

  @override
  String get toHighsLabel => 'To highs';

  @override
  String get totalVariationLabel => 'Total Variation';

  @override
  String get sinceLabel => 'Since';

  @override
  String get configuredAlertsLabel => 'Configured alerts';

  @override
  String get minLabel => 'Minimum';

  @override
  String get maxLabel => 'Maximum';

  @override
  String get cnmvOfficialRegistryLabel => 'Check official registry';

  @override
  String get noBackupLabel => 'No backup. Exporting this fund is recommended.';

  @override
  String get oldBackupLabel =>
      'The last backup is more than a month old. Exporting this fund is recommended.';

  @override
  String lastBackupLabel(String date) {
    return 'Last backup: $date';
  }

  @override
  String get averageLabel => 'Average';

  @override
  String get historicalLabel => 'Historical';

  @override
  String get volatilityLabel => 'Volatility';

  @override
  String get annualizedLabel => 'Annualized';

  @override
  String get maxDrawdownLabel => 'Max Drawdown';

  @override
  String get maxDropLabel => 'Maximum Drop';

  @override
  String get recoveryLabel => 'Recovery';

  @override
  String get fromTroughLabel => 'From Trough';

  @override
  String daysCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get inProgressLabel => 'in progress';

  @override
  String get statusTab => 'Status';

  @override
  String get balanceTab => 'Balance';

  @override
  String get chartTab => 'Chart';

  @override
  String get monthsTab => 'Months';

  @override
  String get tableTab => 'Table';

  @override
  String get marketTab => 'Market';

  @override
  String get updateDataTooltip => 'Update data';

  @override
  String get downloadRangeTooltip => 'Download range';

  @override
  String get exportFundAction => 'Export fund';

  @override
  String get clearDataAction => 'Clear data';

  @override
  String get deleteFromPortfolioAction => 'Remove from portfolio';

  @override
  String get clearDataTitle => 'Clear Data';

  @override
  String get clearDataConfirm => 'Do you want to clear prices and history?';

  @override
  String get deleteFromPortfolioTitle => 'Remove from Portfolio';

  @override
  String get deleteFromPortfolioConfirm =>
      'Are you sure you want to remove this fund?';

  @override
  String get configureAlertsTitle => 'Configure Alerts';

  @override
  String get configureAlertsDesc =>
      'Notify if the Net Asset Value reaches the following limits:';

  @override
  String get deleteAlertsAction => 'Delete Alerts';

  @override
  String get deletePriceError =>
      'Could not delete price. Back up the fund and restart the app.';

  @override
  String get backup => 'Backup';

  @override
  String get numberLabel => 'No.';

  @override
  String get dateLabel => 'Date';

  @override
  String get priceLabel => 'Price';

  @override
  String get diffLabel => 'Diff.';

  @override
  String get varLabel => 'Var.';

  @override
  String get deletePriceTitle => 'Delete Price';

  @override
  String deletePriceConfirm(String date) {
    return 'Do you want to delete the record for $date?';
  }

  @override
  String get priceDeletedSuccess => 'Price deleted successfully';

  @override
  String get undo => 'Undo';

  @override
  String get deletionUndone => 'Deletion undone';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get noOperationsRegistered => 'No operations registered';

  @override
  String get newOperation => 'New Operation';

  @override
  String get editOperation => 'Edit Operation';

  @override
  String get subscription => 'Subscription';

  @override
  String get redemption => 'Redemption';

  @override
  String unitsAtPrice(String units, String price) {
    return '$units units @ $price';
  }

  @override
  String get deleteOperationTitle => 'Delete Operation';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get deleteOperationConfirm => 'Do you want to delete this operation?';

  @override
  String get deleteOperationFailed => 'Could not delete the operation';

  @override
  String get deleteOperationError =>
      'Could not delete the operation. Back up and restart the app.';

  @override
  String get restoreOperationError =>
      'Could not restore the operation. Back up and restart the app.';

  @override
  String get operationDeletedSuccess => 'Operation deleted successfully';

  @override
  String get saveOperationFailed => 'Could not save the operation';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get priceNavLabel => 'Price (NAV)';

  @override
  String get unitsLabel => 'Units';

  @override
  String get totalAmountLabel => 'Total Amount';

  @override
  String get noHistoryForReturns => 'No price history to calculate returns.';

  @override
  String get insufficientDataForHeatmap =>
      'Insufficient data to generate heatmap.';

  @override
  String get yearLabel => 'Year';

  @override
  String get totalUnitsLabel => 'Total units';

  @override
  String get netInvestmentLabel => 'Net investment';

  @override
  String get avgPurchasePriceLabel => 'Avg purchase price';

  @override
  String get currentValueLabel => 'Current value';

  @override
  String get grossProfitLabel => 'Gross Profit';

  @override
  String get grossLossLabel => 'Gross Loss';

  @override
  String get realGainLabel => 'Real Gain';

  @override
  String get netProfitEstLabel => '(Est. Net Profit)';

  @override
  String get managementFeesTitle => 'Management Fees';

  @override
  String get fixedFeesLabel => 'Current Expenses';

  @override
  String get fixedFeesHint => 'Fixed';

  @override
  String get perfFeesLabel => 'Performance Fee';

  @override
  String get perfFeesHint => 'On success';

  @override
  String get annualCostEstLabel => 'Est. Annual Cost';

  @override
  String get monthlyCostEstLabel => 'Est. Monthly Cost';

  @override
  String get profitabilityIndicesTitle => 'Profitability Indices';

  @override
  String get annualizedReturnLabel => 'Ann. Return';

  @override
  String get moicLabel => 'Multiplier (MoIC)';

  @override
  String get ageLabel => 'Age';

  @override
  String get breakEvenLabel => 'Break-even';

  @override
  String get financialIndicesTitle => 'Financial Indices';

  @override
  String get bruteReturnsNote =>
      'Gross returns without consideration of costs or fees.';

  @override
  String get aprTaeDesc =>
      'Simple profitability of YOUR investment based on total capital contributed and time elapsed.';

  @override
  String get twrDesc =>
      'Time-Weighted Return. Measures the performance of the FUND, eliminating the impact of your cash inflows and outflows. It is the profitability of the asset itself.';

  @override
  String get mwrIrrDesc =>
      'Money-Weighted Return (or IRR). Real profitability of your pocket that takes into account the exact timing of each contribution. It reflects your success as an investor in choosing when to enter and exit.';

  @override
  String get moicDesc => 'Final capital obtained for each euro invested.';

  @override
  String get ageDesc => 'Time elapsed since the first operation.';

  @override
  String get breakEvenDesc => 'Price needed to avoid losses.';

  @override
  String get fixedFeesSuffix => '% TER';

  @override
  String get perfFeesSuffix => '% Success';

  @override
  String get twrTotalLabel => 'TWR (Total)';

  @override
  String get twrAnnualizedLabel => 'TWR Annualized';

  @override
  String get mwrHistoricalLabel => 'MWR Historical';

  @override
  String get mwrAnnualizedLabel => 'MWR Annualized';

  @override
  String get twrInfoTitle => 'TWR (Total / Annualized)';

  @override
  String get mwrInfoTitle => 'MWR (Historical / Annualized)';

  @override
  String monthsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String yearsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get andLabel => 'and';

  @override
  String get noDataInRange => 'No data in this range';

  @override
  String get averageLabelShort => 'Mean';

  @override
  String get compareLabel => 'Compare';

  @override
  String get compareWithBenchmark => 'Compare with benchmark';

  @override
  String get noneLabel => 'None';

  @override
  String get fundPercentLabel => 'Fund (%)';

  @override
  String get benchmarkPercentLabel => 'Benchmark (%)';

  @override
  String get sp500Desc =>
      'The S&P 500 is a stock market index tracking the stock performance of 500 of the largest companies listed on stock exchanges in the United States.';

  @override
  String get msciWorldDesc =>
      'The MSCI World is a broad global equity index that represents large and mid-cap equity performance across 23 developed markets countries.';

  @override
  String get euroStoxx50Desc =>
      'The Euro Stoxx 50 is a stock index of eurozone stocks designed by Stoxx, a provider of stock indices owned by Deutsche Börse Group.';

  @override
  String get ibex35Desc =>
      'The IBEX 35 is the benchmark stock market index of the Bolsa de Madrid, Spain\'s principal stock exchange.';

  @override
  String get nasdaq100Desc =>
      'The Nasdaq 100 is a stock market index made up of 101 equity securities issued by 100 of the largest non-financial companies listed on the Nasdaq stock market.';

  @override
  String get dax40Desc =>
      'The DAX is a blue chip stock market index consisting of the 40 major German companies trading on the Frankfurt Stock Exchange.';

  @override
  String get cac40Desc =>
      'The CAC 40 is a benchmark French stock market index. The index represents a capitalization-weighted measure of the 40 most significant stocks among the 100 largest market caps on the Euronext Paris.';

  @override
  String get nikkei225Desc =>
      'The Nikkei 225 is a stock market index for the Tokyo Stock Exchange. It has been calculated daily by the Nihon Keizai Shimbun newspaper since 1950.';
}
