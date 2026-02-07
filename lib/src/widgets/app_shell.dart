import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
import '../screens/home_landing_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/ecg_gallery_screen.dart';
import '../screens/patient_pick_upload_screen.dart';

class AppShell extends StatefulWidget {
  final AppThemeController themeController;

  const AppShell({
    super.key,
    required this.themeController,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  void _goTo(int i) => setState(() => index = i);

  Widget _buildMainContent(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        HomeLandingScreen(
          onOpenPatients: () => _goTo(1),
          onOpenGallery: () => _goTo(2),
          onOpenUpload: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PatientPickUploadScreen(),
              ),
            );
          },
        ),
        const PatientsScreen(),
        const EcgGalleryScreen(),
      ],
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: index == 0,
              onTap: () {
                Navigator.of(context).pop();
                _goTo(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Patients'),
              selected: index == 1,
              onTap: () {
                Navigator.of(context).pop();
                _goTo(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('ECGs'),
              selected: index == 2,
              onTap: () {
                Navigator.of(context).pop();
                _goTo(2);
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'ECG Analyzer',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ Only switch behavior on small widths (phones / Safari).
        // ✅ Desktop/laptop keeps your existing layout.
        final isNarrow = constraints.maxWidth < 820;

        if (isNarrow) {
          // ✅ MOBILE / SAFARI FIX:
          // - No NavigationRail (prevents RenderFlex overflow)
          // - Drawer for side menu
          // - Bottom nav for fast switching
          return Scaffold(
            appBar: _TopBar(themeController: widget.themeController),
            drawer: _buildDrawer(context),
            body: _buildMainContent(context),
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: _goTo,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.people), label: 'Patients'),
                NavigationDestination(icon: Icon(Icons.monitor_heart), label: 'ECGs'),
              ],
            ),
          );
        }

        // ✅ DESKTOP / LAPTOP (UNCHANGED look):
        return Scaffold(
          appBar: _TopBar(themeController: widget.themeController),
          body: Row(
            children: [
              // ✅ Your exact modern rail container (kept)
              Container(
                width: 104,
                margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  minWidth: 90,
                  groupAlignment: -0.9,
                  selectedIndex: index,
                  onDestinationSelected: _goTo,
                  labelType: NavigationRailLabelType.all,
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorColor: cs.primary.withValues(alpha: 0.10),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Patients'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.monitor_heart_outlined),
                      selectedIcon: Icon(Icons.monitor_heart),
                      label: Text('ECGs'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildMainContent(context)),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final AppThemeController themeController;

  const _TopBar({required this.themeController});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      title: const Text(
        'ECG Analyzer',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          tooltip: themeController.isDark ? 'Light Mode' : 'Dark Mode',
          icon: Icon(themeController.isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () {
            themeController.setDark(!themeController.isDark);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}