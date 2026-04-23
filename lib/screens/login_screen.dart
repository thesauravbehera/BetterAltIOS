import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _rememberMe = true;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  static const _prefKeyPhone = 'remembered_phone';
  static const _prefKeyRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString(_prefKeyPhone);
    final remember = prefs.getBool(_prefKeyRemember) ?? false;
    if (savedPhone != null && savedPhone.isNotEmpty && remember) {
      setState(() {
        _phoneController.text = savedPhone;
        _rememberMe = true;
      });
    }
  }

  Future<void> _savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_prefKeyPhone, phone);
      await prefs.setBool(_prefKeyRemember, true);
    } else {
      await prefs.remove(_prefKeyPhone);
      await prefs.setBool(_prefKeyRemember, false);
    }
  }

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

  Future<void> _checkOnboardingAndRoute(User user) async {
    // Save phone for Remember Me
    await _savePhone(_phoneController.text.trim());

    // Per user requirement: Sign-in path should BYPASS onboarding regardless of status
    // Onboarding is reserved only for the Sign-Up flow.
    if (mounted) context.go('/verify');
  }

  /// Step 1: Send OTP to the phone number
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

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android (auto-read SMS)
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            if (userCredential.user != null) {
              // Guarantee phone field is present in Firestore
              await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                'phone': phone,
              }, SetOptions(merge: true));
              await _checkOnboardingAndRoute(userCredential.user!);
            }
          } catch (e) {
            if (mounted) setState(() => _errorMessage = 'Auto-verification failed. Please enter the OTP manually.');
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
            // Auto-focus the first OTP box
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

  /// Step 2: Verify the OTP entered by the user
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
        // Guarantee phone field is present in Firestore
        final normalizedPhone = '+91${_phoneController.text.trim()}';
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'phone': _phoneController.text.trim(),
        }, SetOptions(merge: true));
        
        // Ensure the phone is correctly registered in the new registry to block future duplicate sign-ups
        try {
          await FirebaseFirestore.instance.collection('phone_registry').doc(normalizedPhone).set({
            'registeredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}

        await _checkOnboardingAndRoute(userCredential.user!);
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
      setState(() => _errorMessage = 'An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resend OTP
  void _resendOtp() {
    // Clear old OTP fields
    for (final c in _otpControllers) {
      c.clear();
    }
    _sendOtp();
  }

  /// Go back to phone entry
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
                          _isOtpSent ? "Enter OTP" : "Welcome back",
                          style: AppTypography.h2(
                              color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Center(
                        child: Text(
                          _isOtpSent
                              ? "We sent a verification code to +91${_phoneController.text.trim()}"
                              : "Sign in to continue",
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
                        const SizedBox(height: 12),

                        /// Remember Me Checkbox
                        GestureDetector(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                  activeColor: AppColors.accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: BorderSide(
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Remember me",
                                style: AppTypography.body(
                                    color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)
                                    .copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

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
                        /// 6-digit OTP boxes
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
                                  // Auto-verify when all 6 digits entered
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
                                : Text("Verify & Sign In",
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
