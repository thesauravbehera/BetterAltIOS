import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/widgets/app_text_field.dart';
import 'package:fat_burner/widgets/auto_scrolling_slider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _checkOnboardingAndRoute(User user) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['onboardingCompleted'] == true) {
      if (mounted) context.go('/dashboard');
    } else {
      if (mounted) context.go('/onboarding');
    }
  }

  Future<void> _handleLogin() async {
    _clearError();
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Simulate auth delay for UI preview
      await Future.delayed(const Duration(milliseconds: 600));

      if (userCredential.user != null) {
        await _checkOnboardingAndRoute(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Authentication failed';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _clearError();
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _checkOnboardingAndRoute(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Google Sign-In failed');
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred during Google Sign-In: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    _clearError();
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _checkOnboardingAndRoute(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Apple Sign-In failed');
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred during Apple Sign-In');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const String svgmail =
      '''<svg height="20" viewBox="0 0 32 32" width="20" xmlns="http://www.w3.org/2000/svg"><g id="Layer_3" data-name="Layer 3"><path d="m30.853 13.87a15 15 0 0 0 -29.729 4.082 15.1 15.1 0 0 0 12.876 12.918 15.6 15.6 0 0 0 2.016.13 14.85 14.85 0 0 0 7.715-2.145 1 1 0 1 0 -1.031-1.711 13.007 13.007 0 1 1 5.458-6.529 2.149 2.149 0 0 1 -4.158-.759v-10.856a1 1 0 0 0 -2 0v1.726a8 8 0 1 0 .2 10.325 4.135 4.135 0 0 0 7.83.274 15.2 15.2 0 0 0 .823-7.455zm-14.853 8.13a6 6 0 1 1 6-6 6.006 6.006 0 0 1 -6 6z" fill="#9B9E8E" /></g></svg>''';
  static const String svgLock =
      '''<svg height="20" viewBox="-64 0 512 512" width="20" xmlns="http://www.w3.org/2000/svg"><path d="m336 512h-288c-26.453125 0-48-21.523438-48-48v-224c0-26.476562 21.546875-48 48-48h288c26.453125 0 48 21.523438 48 48v224c0 26.476562-21.546875 48-48 48zm-288-288c-8.8125 0-16 7.167969-16 16v224c0 8.832031 7.1875 16 16 16h288c8.8125 0 16-7.167969 16-16v-224c0-8.832031-7.1875-16-16-16zm0 0" fill="#9B9E8E" /><path d="m304 224c-8.832031 0-16-7.167969-16-16v-80c0-52.929688-43.070312-96-96-96s-96 43.070312-96 96v80c0 8.832031-7.167969 16-16 16s-16-7.167969-16-16v-80c0-70.59375 57.40625-128 128-128s128 57.40625 128 128v80c0 8.832031-7.167969 16-16 16zm0 0" fill="#9B9E8E" /></svg>''';
  static const String svgEye =
      '''<svg viewBox="0 0 576 512" height="18" width="18" xmlns="http://www.w3.org/2000/svg"><path d="M288 32c-80.8 0-145.5 36.8-192.6 80.6C48.6 156 17.3 208 2.5 243.7c-3.3 7.9-3.3 16.7 0 24.6C17.3 304 48.6 356 95.4 399.4C142.5 443.2 207.2 480 288 480s145.5-36.8 192.6-80.6c46.8-43.5 78.1-95.4 93-131.1c3.3-7.9 3.3-16.7 0-24.6c-14.9-35.7-46.2-87.7-93-131.1C433.5 68.8 368.8 32 288 32zM144 256a144 144 0 1 1 288 0 144 144 0 1 1 -288 0zm144-64c0 35.3-28.7 64-64 64c-7.1 0-13.9-1.2-20.3-3.3c-5.5-1.8-11.9 1.6-11.7 7.4c.3 6.9 1.3 13.8 3.2 20.7c13.7 51.2 66.4 81.6 117.6 67.9s81.6-66.4 67.9-117.6c-11.1-41.5-47.8-69.4-88.6-71.1c-5.8-.2-9.2 6.1-7.4 11.7c2.1 6.4 3.3 13.2 3.3 20.3z" fill="#9B9E8E" /></svg>''';
  static const String svgGoogle =
      '''<svg version="1.1" width="20" height="20" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="#FBBB00" d="M113.47,309.408L95.648,375.94l-65.139,1.378C11.042,341.211,0,299.9,0,256c0-42.451,10.324-82.483,28.624-117.732h0.014l57.992,10.632l25.404,57.644c-5.317,15.501-8.215,32.141-8.215,49.456C103.821,274.792,107.225,292.797,113.47,309.408z"/><path fill="#518EF8" d="M507.527,208.176C510.467,223.662,512,239.655,512,256c0,18.328-1.927,36.206-5.598,53.451c-12.462,58.683-45.025,109.925-90.134,146.187l-0.014-0.014l-73.044-3.727l-10.338-64.535c29.932-17.554,53.324-45.025,65.646-77.911h-136.89V208.176h138.887L507.527,208.176L507.527,208.176z"/><path fill="#28B446" d="M416.253,455.624l0.014,0.014C372.396,490.901,316.666,512,256,512c-97.491,0-182.252-54.491-225.491-134.681l82.961-67.91c21.619,57.698,77.278,98.771,142.53,98.771c28.047,0,54.323-7.582,76.87-20.818L416.253,455.624z"/><path fill="#F14336" d="M419.404,58.936l-82.933,67.896c-23.335-14.586-50.919-23.012-80.471-23.012c-66.729,0-123.429,42.957-143.965,102.724l-83.397-68.276h-0.014C71.23,56.123,157.06,0,256,0C318.115,0,375.068,22.126,419.404,58.936z"/></svg>''';
  static const String svgApple =
      '''<svg height="20" width="20" viewBox="0 0 22.773 22.773" xmlns="http://www.w3.org/2000/svg"><g><path d="M15.769,0c0.053,0,0.106,0,0.162,0c0.13,1.606-0.483,2.806-1.228,3.675c-0.731,0.863-1.732,1.7-3.351,1.573 c-0.108-1.583,0.506-2.694,1.25-3.561C13.292,0.879,14.557,0.16,15.769,0z" fill="#000000"/><path d="M20.67,16.716c0,0.016,0,0.03,0,0.045c-0.455,1.378-1.104,2.559-1.896,3.655c-0.723,0.995-1.609,2.334-3.191,2.334 c-1.367,0-2.275-0.879-3.676-0.903c-1.482-0.024-2.297,0.735-3.652,0.926c-0.155,0-0.31,0-0.462,0 c-0.995-0.144-1.798-0.932-2.383-1.642c-1.725-2.098-3.058-4.808-3.306-8.276c0-0.34,0-0.679,0-1.019 c0.105-2.482,1.311-4.5,2.914-5.478c0.846-0.52,2.009-0.963,3.304-0.765c0.555,0.086,1.122,0.276,1.619,0.464 c0.471,0.181,1.06,0.502,1.618,0.485c0.378-0.011,0.754-0.208,1.135-0.347c1.116-0.403,2.21-0.865,3.652-0.648 c1.733,0.262,2.963,1.032,3.723,2.22c-1.466,0.933-2.625,2.339-2.427,4.74C17.818,14.688,19.086,15.964,20.67,16.716z" fill="#000000"/></g></svg>''';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.canvasDark : Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: double.infinity,
                  // Padding removed from container to allow full-width logo
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),
                      /// Main Logo
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                        child: Image.asset(
                          'images/Betteralt_main_logo.jpeg',
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (context, error, stackTrace) {
                            return const Placeholder(
                              fallbackHeight: 60,
                              fallbackWidth: double.infinity,
                              color: AppColors.accent,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                      Center(
                        child: Text(
                          "Welcome back",
                          style: AppTypography.h2(
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Center(
                        child: Text(
                          "Sign in to continue",
                          style: AppTypography.body(
                              color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.caption(color: AppColors.error),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      AppTextField(
                        label: 'Email',
                        hint: 'Enter your Email',
                        controller: _emailController,
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        isPremiumWhite: true,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Password',
                        hint: 'Enter your Password',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary,
                            size: 20,
                          ),
                        ),
                        keyboardType: TextInputType.visiblePassword,
                        isPremiumWhite: true,
                      ),
                      const SizedBox(height: 20),

                      /// Row: Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) => setState(() => _rememberMe = val!),
                                  activeColor: AppColors.structurePrimary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text("Remember me",
                                  style: AppTypography.body(
                                          color: isDark
                                              ? AppColors.textOnDark
                                              : AppColors.textPrimary)
                                      .copyWith(fontSize: 14)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () async {
                              FocusScope.of(context).unfocus();

                              final email = _emailController.text.trim();

                              if (email.isEmpty) {
                                setState(() => _errorMessage = 'Enter email to reset password');
                                return;
                              }

                              try {
                                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password reset email sent')),
                                );
                              } catch (e) {
                                setState(() => _errorMessage = 'Failed to send reset email');
                              }
                            },
                            child: Text(
                              "Forgot password?",
                              style: AppTypography.body(color: AppColors.info)
                                  .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      /// Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.textPrimary,
                            foregroundColor: isDark ? AppColors.textPrimary : AppColors.textOnAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text("Sign In",
                                  style: AppTypography.h3(
                                          color: isDark ? AppColors.textPrimary : AppColors.textOnAccent)
                                      .copyWith(fontSize: 15)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Don't have an account
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTypography.body(
                                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary)
                                  .copyWith(fontSize: 14),
                            ),
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                context.push('/signup');
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Sign Up",
                                style: AppTypography.body(color: AppColors.info)
                                    .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                          child: Text("Or With",
                              style: AppTypography.body(
                                      color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)
                                  .copyWith(fontSize: 14))),
                      const SizedBox(height: 20),

                      /// Social Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: SvgPicture.string(svgGoogle, height: 20),
                              label: Text("Google",
                                  style: AppTypography.bodyMedium(
                                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                              onPressed: _isLoading ? null : _signInWithGoogle,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: SvgPicture.string(svgApple,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                      isDark ? Colors.white : Colors.black, BlendMode.srcIn)),
                              label: Text("Apple",
                                  style: AppTypography.bodyMedium(
                                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                              onPressed: _isLoading ? null : _signInWithApple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      ], // end inner column children
                    ), // end inner Column
                  ), // end inner Padding
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}