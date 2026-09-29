import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Minimal app shown from the very first frame until startup work (database
/// migration, keyring lookup, sync init) finishes, so launch doesn't look
/// frozen — on desktop the window doesn't appear until a frame is drawn, so
/// without this it just sits invisible for that whole time. `main.dart`
/// replaces it with the real app via a second `runApp`.
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreNotes',
      debugShowCheckedModeBanner: false,
      theme: buildNotallyTheme(),
      home: const LoadingScreen(),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Android already shows the icon natively (launch theme / SplashScreen
    // API) until this first frame, so leave the name off there to keep the
    // logo from jumping when Flutter takes over.
    final showName = kIsWeb || !Platform.isAndroid;
    return Scaffold(
      backgroundColor: NotallyColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/splash_logo.png',
                width: 96,
                height: 96,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (showName) ...[
              const SizedBox(height: 20),
              const Text(
                'LibreNotes',
                style: TextStyle(
                  color: NotallyColors.textBright,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
