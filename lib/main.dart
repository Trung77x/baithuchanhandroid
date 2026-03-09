import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  bool _showSignUp = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Note',
      theme: ThemeData(
        // intense blue seed for sharp appearance 💙
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2962FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        initialData: _authService.currentUser,
        builder: (context, snapshot) {
          // User is signed in
          if (snapshot.data != null) {
            return const HomeScreen();
          }

          // User is not signed in - show sign up or login screen
          return _showSignUp
              ? SignUpScreen(
                  onSignIn: () {
                    setState(() => _showSignUp = false);
                  },
                )
              : LoginScreen(
                  onSignUp: () {
                    setState(() => _showSignUp = true);
                  },
                );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
