import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'pages/main_shell.dart';
import 'pages/auth_page.dart';
import 'services/role_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => RoleService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WareWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor:
            const Color(0xFFF8FAFC), // Off-white canvas background

        // Applying your explicit Emerald Green Token Palette
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF009473), // Core Emerald Accent
          secondary: Color(0xFF1CB08F), // Vibrant Mint
          tertiary: Color(0xFF01604B), // Deep Forest Dark
          surface: Colors.white,
          outline: Color(0xFF6BC1AE), // Soft Sage Intermediary
        ),

        // Typography matching the high scannability of your UI mockup
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xFF01604B),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF009473),
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            return const MainShell();
          }

          return const AuthPage();
        },
      ),
    );
  }
}
