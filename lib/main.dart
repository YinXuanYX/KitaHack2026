import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/consumer/consumer_main_screen.dart';
import 'screens/vendor/vendor_home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const KitaHackApp(),
    ),
  );
}

class KitaHackApp extends StatelessWidget {
  const KitaHackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return MaterialApp(
      title: 'Wastave',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.green, // Emerald/Forest green base
        brightness: Brightness.light,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green, // Emerald/Forest green base
        brightness: Brightness.dark,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        // We have a user, check their role in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasError || !userSnapshot.data!.exists) {
              // Fallback or handle error
              return const Scaffold(body: Center(child: Text('Error loading user profile.')));
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] as String?;

            if (role == 'vendor') {
              return const VendorHomeScreen();
            } else {
              return const ConsumerMainScreen();
            }
          },
        );
      },
    );
  }
}
