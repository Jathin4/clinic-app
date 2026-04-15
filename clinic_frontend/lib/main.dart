import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/session.dart';

void main()  async {
  WidgetsFlutterBinding.ensureInitialized(); // ADD THIS
  await Session.restore();  

  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const ClinicApp(),
    ),
  );
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClinicOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6C68)),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AppProvider>().isLoggedIn;
    return isLoggedIn ? const MainLayout() : const LoginScreen();
  }
}