import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Logged in as: ${authProvider.user?.username ?? '...'}'),
            const SizedBox(height: 10),
            Text('Role: ${authProvider.user?.role ?? '...'}'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => authProvider.logout(),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}