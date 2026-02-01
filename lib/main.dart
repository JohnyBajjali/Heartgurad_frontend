import 'package:flutter/material.dart';
import 'src/widgets/app_router.dart';

void main() => runApp(const ECGApp());

class ECGApp extends StatelessWidget {
  const ECGApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F62FE);
    const secondary = Color(0xFF00B4A6);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ECG Analyzer',
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.shell,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,

        scaffoldBackgroundColor: const Color(0xFFF2F6FC),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF0B1220),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentTextStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),

        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: primary.withValues(alpha: 0.10),
          selectedIconTheme: const IconThemeData(color: primary),
          unselectedIconTheme: IconThemeData(color: Colors.black.withValues(alpha: 0.55)),
          selectedLabelTextStyle: const TextStyle(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.60),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}