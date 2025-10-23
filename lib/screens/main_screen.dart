// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/auth_provider.dart';
import 'admin_management_screen.dart';
import 'patient_list_screen.dart';
import 'profile_screen.dart';
import 'ecg_inbox_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? '';

    // Base tabs: ECGs, Patients, Profile
    final pages = <Widget>[
      const EcgInboxScreen(),
      const PatientListScreen(),
      const ProfileScreen(),
    ];
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'ECGs'),
      const BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Patients'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
    ];

    // Admin tab (first)
    if (role == 'ADMIN') {
      pages.insert(0, const AdminManagementScreen());
      items.insert(0, const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'));
    }

    if (_selectedIndex >= pages.length) _selectedIndex = pages.length - 1;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
