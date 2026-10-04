import 'package:flutter/material.dart';

import '../../core/routes/app_route.dart';
import '../../core/services/i18n/translations.g.dart';
import '../themes/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    AppTheme.setStatusBarColor();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0.0,
      title: Text(context.t.appNameAlt, style: const TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          onPressed: () => const SettingsRoute().push(context),
          icon: const Icon(Icons.settings, color: Colors.white),
        ),
      ],
      backgroundColor: AppTheme.getAppbarBgColor(),
    ),
  );
}
