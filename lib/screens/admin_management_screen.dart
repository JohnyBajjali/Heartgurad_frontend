import 'package:flutter/material.dart';

class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Management')),
      body: const Center(child: Text('Super Admin: Manage Hospitals & Admins Here')),
    );
  }
}