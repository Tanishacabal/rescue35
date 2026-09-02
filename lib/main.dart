import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'constants/app_colors.dart';
import 'screens/onboarding/splash_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  try {
    if (Firebase.apps.isEmpty) {
      // ✅ KUSANG HAHANAPIN ANG GoogleService-Info.plist sa iOS
      await Firebase.initializeApp();
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService().initialize();
  } catch (error, stackTrace) {
    debugPrint('Startup services failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rescue 35',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.rejected,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          headlineLarge: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.dark,
          ),
          titleLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
          bodyLarge: const TextStyle(color: AppColors.dark),
          bodyMedium: const TextStyle(color: AppColors.dark),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.textLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dark,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.96),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}