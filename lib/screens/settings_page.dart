import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../services/settings_service.dart';
import '../providers/fund_provider.dart';
import '../widgets/gradient_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _requireAuth = false;
  bool _canAuthenticate = false;
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final requireAuth = await SettingsService.isAuthRequired();
    final canAuth = await SettingsService.canAuthenticate();
    final autoRefresh = await SettingsService.isAutoRefreshEnabled();
    setState(() {
      _requireAuth = requireAuth;
      _canAuthenticate = canAuth;
      _autoRefresh = autoRefresh;
    });
  }

  Future<void> _toggleAutoRefresh(bool value) async {
    await SettingsService.setAutoRefreshEnabled(value);
    if (!mounted) return;
    setState(() {
      _autoRefresh = value;
    });
  }

  Future<void> _toggleAuth(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      if (Platform.isLinux) {
        final hasPassword = (await SettingsService.getAppPassword()) != null;
        if (!hasPassword) {
          if (!mounted) return;
          final set = await _showSetPasswordDialog(context);
          if (!set) return;
        }
      } else {
        final authenticated = await SettingsService.authenticate();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authFailed),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
    }
    await SettingsService.setAuthRequired(value);
    setState(() {
      _requireAuth = value;
    });
  }

  Future<bool> _showSetPasswordDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.setAppPassword),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.setAppPasswordDescription),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.length < 4) ? l10n.minCharacters : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await SettingsService.setAppPassword(controller.text);
                saved = true;
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle(l10n.language),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.locale?.languageCode ?? 'es',
                      dropdownColor: const Color(0xFF1E293B),
                      items: [
                        DropdownMenuItem(
                          value: 'es',
                          child: Text(
                            l10n.spanish,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            l10n.english,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (code) {
                        if (code != null) {
                          provider.setLocale(Locale(code));
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.security),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        l10n.protectedAccess,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        Platform.isLinux
                            ? l10n.requirePasswordSubtitle
                            : _canAuthenticate
                            ? l10n.requireBiometricSubtitle
                            : l10n.noBiometricSupport,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: _requireAuth,
                      onChanged: _canAuthenticate || Platform.isLinux
                          ? _toggleAuth
                          : null,
                      activeThumbColor: Colors.blueAccent,
                    ),
                    if (_requireAuth && Platform.isLinux) ...[
                      const Divider(height: 1, color: Colors.white10),
                      ListTile(
                        title: Text(
                          l10n.changePassword,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                        onTap: () => _showSetPasswordDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.data),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: SwitchListTile(
                  title: Text(
                    l10n.autoRefreshTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    l10n.autoRefreshSubtitle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  value: _autoRefresh,
                  onChanged: _toggleAutoRefresh,
                  activeThumbColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 24),
              /*_buildSectionTitle('Información'),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const ListTile(
                  title: Text(
                    'Versión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '1.0.6+7',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),*/
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.blueAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
