import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fat_burner/screens/login_screen.dart';
import 'package:fat_burner/screens/sign_up_screen.dart';
import 'package:fat_burner/screens/main_screen.dart';
import 'package:fat_burner/screens/purchase_gate_screen.dart';
import 'package:fat_burner/screens/verification_gate_screen.dart';
import 'package:fat_burner/screens/onboarding_screen.dart';
import 'package:fat_burner/services/auth_service.dart';

/// Centralized routing configuration.
/// Add new routes here to keep navigation scalable.
class AppRouter {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String verify = '/verify';
  static const String paywall = '/paywall';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';

  static final GoRouter router = GoRouter(
    initialLocation: login,
    debugLogDiagnostics: true,
    refreshListenable: AuthService.instance.authState,
    redirect: (context, state) {
      final isLoggedIn = AuthService.instance.isLoggedIn;
      final isAuthRoute = state.matchedLocation == login || state.matchedLocation == signup;

      // So if they are logged in, and try to visit an auth route (login/signup), we force them to the verifier first.
      if (isLoggedIn && isAuthRoute) {
        return verify;
      }
      
      if (!isLoggedIn && !isAuthRoute) {
        return login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: signup,
        name: 'signup',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return SignUpScreen(onboardingData: extras);
        },
      ),
      GoRoute(
        path: verify,
        name: 'verify',
        builder: (context, state) => const VerificationGateScreen(),
      ),
      GoRoute(
        path: paywall,
        name: 'paywall',
        builder: (context, state) => const PurchaseGateScreen(),
      ),
      GoRoute(
        path: dashboard,
        name: 'dashboard',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
  );
}
