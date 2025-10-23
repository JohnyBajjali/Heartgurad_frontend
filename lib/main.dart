// In lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ProtoECGNetApp());
}

class ProtoECGNetApp extends StatelessWidget {
  const ProtoECGNetApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'ProtoECGNet AI',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          // You can add more theme properties here to match the login screen
        ),
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const SplashScreen();
            } else if (auth.isAuthenticated) {
              return const MainScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}