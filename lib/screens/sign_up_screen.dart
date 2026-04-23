import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/widgets/app_text_field.dart';

class SignUpScreen extends StatefulWidget {
  final Map<String, dynamic>? onboardingData;
  const SignUpScreen({super.key, this.onboardingData});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  /// Step 1: Send OTP
  Future<void> _sendOtp() async {
    _clearError();
    FocusScope.of(context).unfocus();

    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Phone number must be exactly 10 digits');
      return;
    }

    setState(() => _isLoading = true);

    // Securely check if this phone number already has an account using the phone_registry
    try {
      final normalizedPhone = '+91$phone';
      final phoneDoc = await FirebaseFirestore.instance.collection('phone_registry').doc(normalizedPhone).get();
      
      if (phoneDoc.exists) {
        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/login');
        }
        return;
      }
    } catch (_) {
      // If check fails, proceed with OTP (fail-safe)
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            if (userCredential.user != null) {
              await _createUserProfile(userCredential.user!, phone);
              await _routeAfterAuth(userCredential.user!);
            }
          } catch (e) {
            if (mounted) setState(() => _errorMessage = 'Auto-verification failed. Please enter OTP manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            String message;
            switch (e.code) {
              case 'too-many-requests':
                message = 'Too many OTP requests. Please wait and try again later.';
                break;
              case 'invalid-phone-number':
                message = 'Invalid phone number. Please check and try again.';
                break;
              case 'network-request-failed':
                message = 'No internet connection. Please check your network.';
                break;
              default:
                message = e.message ?? 'Failed to send OTP. Please try again.';
            }
            setState(() {
              _errorMessage = message;
              _isLoading = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isOtpSent = true;
              _isLoading = false;
            });
            _otpFocusNodes[0].requestFocus();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  /// Step 2: Verify OTP and create account
  Future<void> _verifyOtp() async {
    _clearError();
    FocusScope.of(context).unfocus();

    final otp = _otpControllers.map((c) => c.text.trim()).join();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Session expired. Please resend OTP.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createUserProfile(userCredential.user!, _phoneController.text.trim());
        await _routeAfterAuth(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
          message = 'Incorrect OTP. Please check and try again.';
          break;
        case 'session-expired':
          message = 'OTP has expired. Please resend a new one.';
          break;
        default:
          message = e.message ?? 'Verification failed. Please try again.';
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Route user based on whether they have completed onboarding already
  Future<void> _routeAfterAuth(User user) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['onboardingCompleted'] == true) {
      // Existing user — skip onboarding, go straight to verification/dashboard
      if (mounted) context.go('/verify');
    } else {
      // New user — needs onboarding
      if (mounted) context.go('/onboarding');
    }
  }

  /// Create or merge user profile in Firestore
  Future<void> _createUserProfile(User user, String phone) async {
    // Check if user already exists with onboarding completed
    final existingDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final existingData = existingDoc.data();
    final alreadyOnboarded = existingData?['onboardingCompleted'] == true;

    final Map<String, dynamic> payload = {
      'phone': phone,
      'provider': 'phone',
    };

    // Only set onboardingCompleted to false if the user doesn't already have it set to true
    if (!alreadyOnboarded) {
      payload['created_at'] = FieldValue.serverTimestamp();
      payload['onboardingCompleted'] = false;
    }

    if (widget.onboardingData != null) payload.addAll(widget.onboardingData!);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
    
    // Also register the phone number securely so we can check it before sending OTPs in the future
    try {
      final normalizedPhone = '+91$phone';
      await FirebaseFirestore.instance.collection('phone_registry').doc(normalizedPhone).set({
        'registeredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to add phone to registry: $e');
    }
  }

  void _resendOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _sendOtp();
  }

  void _goBackToPhone() {
    setState(() {
      _isOtpSent = false;
      _verificationId = null;
      _errorMessage = null;
      for (final c in _otpControllers) {
        c.clear();
      }
    });
  }

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
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          _isOtpSent ? "Enter OTP" : "Create an Account",
                          style: AppTypography.h2(
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Center(
                        child: Text(
                          _isOtpSent
                              ? "We sent a verification code to +91${_phoneController.text.trim()}"
                              : "Sign up to get started",
                          textAlign: TextAlign.center,
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

                      /// ── PHONE NUMBER ENTRY ──
                      if (!_isOtpSent) ...[
                        AppTextField(
                          label: 'Phone Number',
                          hint: 'Enter your Phone Number',
                          controller: _phoneController,
                          prefixIcon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                          isPremiumWhite: true,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                        const SizedBox(height: 40),

                        /// Send OTP Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.textPrimary,
                              foregroundColor: isDark ? AppColors.textPrimary : AppColors.textOnAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isLoading ? null : _sendOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text("Send OTP",
                                    style: AppTypography.h3(
                                            color: isDark ? AppColors.textPrimary : AppColors.textOnAccent)
                                        .copyWith(fontSize: 15)),
                          ),
                        ),
                      ],

                      /// ── OTP ENTRY ──
                      if (_isOtpSent) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 45,
                              height: 55,
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _otpFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: AppTypography.h2(
                                    color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                                      : Colors.grey.shade100,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.accent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    _otpFocusNodes[index + 1].requestFocus();
                                  }
                                  if (value.isEmpty && index > 0) {
                                    _otpFocusNodes[index - 1].requestFocus();
                                  }
                                  if (index == 5 && value.isNotEmpty) {
                                    final otp = _otpControllers.map((c) => c.text).join();
                                    if (otp.length == 6) {
                                      _verifyOtp();
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 25),

                        /// Verify OTP Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.textPrimary,
                              foregroundColor: isDark ? AppColors.textPrimary : AppColors.textOnAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isLoading ? null : _verifyOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text("Verify & Create Account",
                                    style: AppTypography.h3(
                                            color: isDark ? AppColors.textPrimary : AppColors.textOnAccent)
                                        .copyWith(fontSize: 15)),
                          ),
                        ),

                        const SizedBox(height: 15),

                        /// Resend + Change Number row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : _goBackToPhone,
                              child: Text(
                                "← Change Number",
                                style: AppTypography.body(
                                    color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)
                                    .copyWith(fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _resendOtp,
                              child: Text(
                                "Resend OTP",
                                style: AppTypography.body(color: AppColors.info)
                                    .copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      /// Already have an account? Sign In
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: AppTypography.body(
                                      color: isDark ? AppColors.textOnDark : AppColors.textPrimary)
                                  .copyWith(fontSize: 14),
                            ),
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                context.push('/login'); 
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Sign In",
                                style: AppTypography.body(color: AppColors.info)
                                    .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
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
