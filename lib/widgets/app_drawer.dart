import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/settings_page.dart';
import '../screens/info_page.dart';
import '../screens/about_page.dart';
import '../screens/support_page.dart';
import '../services/database_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Image.asset(
                'assets/images/logo.png',
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: Colors.white70,
            ),
            title: const Text(
              'Ajustes',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white70),
            title: const Text('Info', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InfoPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.white70),
            title: const Text(
              'Acerca de',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.favorite_outline,
              color: Colors.white70,
            ),
            title: const Text(
              'Apoyar',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SupportPage()),
              );
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Salir', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await DatabaseService.close();
              exit(0);
            },
          ),
          const Spacer(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  version == null ? 'v...' : 'v$version',
                  style: const TextStyle(color: Colors.white24, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
