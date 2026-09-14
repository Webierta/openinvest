import 'dart:io';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/gradient_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _requireAuth = false;
  bool _canAuthenticate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final requireAuth = await SettingsService.isAuthRequired();
    final canAuth = await SettingsService.canAuthenticate();
    setState(() {
      _requireAuth = requireAuth;
      _canAuthenticate = canAuth;
    });
  }

  Future<void> _toggleAuth(bool value) async {
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
        if (!authenticated) return;
      }
    }
    await SettingsService.setAuthRequired(value);
    setState(() {
      _requireAuth = value;
    });
  }

  Future<bool> _showSetPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Establecer Contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Define una contraseña para proteger el acceso a OpenInvest en este equipo.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await SettingsService.setAppPassword(controller.text);
                saved = true;
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Seguridad'),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Acceso Protegido',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        Platform.isLinux 
                            ? 'Requerir contraseña de aplicación para entrar.'
                            : _canAuthenticate
                                ? 'Requerir huella, rostro o PIN del dispositivo para entrar.'
                                : 'Tu dispositivo no soporta autenticación biométrica.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: _requireAuth,
                      onChanged: _canAuthenticate || Platform.isLinux ? _toggleAuth : null,
                      activeThumbColor: Colors.blueAccent,
                    ),
                    if (_requireAuth && Platform.isLinux) ...[
                      const Divider(height: 1, color: Colors.white10),
                      ListTile(
                        title: const Text('Cambiar contraseña', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () => _showSetPasswordDialog(context),
                      ),
                    ],
                  ],
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
