import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';

import 'providers/fund_provider.dart';
import 'screens/portfolio_page.dart';
import 'services/settings_service.dart';
import 'widgets/gradient_background.dart';
import 'utils/route_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => FundProvider()..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0F172A);
    const slateBlue = Color(0xFF1E293B);
    const skyBlue = Color(0xFF38BDF8);

    final provider = context.watch<FundProvider>();

    return MaterialApp(
      title: 'OpenInvest',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: provider.locale,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: skyBlue,
          surface: slateBlue,
          surfaceContainer: darkBlue,
          primaryContainer: Color(0xFF0369A1),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: slateBlue.withValues(
            alpha: 0.4,
          ), // Más transparente para ver el fondo
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _authenticated;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<bool> _promptLinuxPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.protectedAccessTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.appPasswordLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.enterPasswordError;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(l10n.enter),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    return SettingsService.authenticate(password: controller.text);
  }

  Future<void> _checkAuth() async {
    final bool authRequired = await SettingsService.isAuthRequired();
    if (!authRequired) {
      setState(() => _authenticated = true);
      return;
    }

    final bool success = Platform.isLinux
        ? await _promptLinuxPassword()
        : await SettingsService.authenticate();

    setState(() => _authenticated = success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_authenticated == null) {
      return const Scaffold(
        body: GradientBackground(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (!_authenticated!) {
      return Scaffold(
        body: GradientBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.white24),
                const SizedBox(height: 24),
                Text(
                  l10n.protectedAccess,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.authRequiredDescription,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _checkAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.retry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const PortfolioPage();
  }
}
