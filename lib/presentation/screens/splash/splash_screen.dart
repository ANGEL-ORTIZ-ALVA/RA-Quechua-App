import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Esperar mínimo 2 segundos para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('is_registered') ?? false;

    if (!mounted) return;

    if (isRegistered) {
      // Ya tiene perfil creado → ir directo al home
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      // Primera vez → onboarding → registro
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o ícono principal
            Icon(
              Icons.language,
              size: 100,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 24),
            // Título de la app
            Text(
              'Yachay Quechua',
              style: AppTextStyles.h1.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aprende quechua con RA',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textLight.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 48),
            // Indicador de carga
            const CircularProgressIndicator(
              valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}