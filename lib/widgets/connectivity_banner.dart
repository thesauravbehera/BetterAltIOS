import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fat_burner/theme/app_colors.dart';

/// A slim, animated banner that slides in from the top when the device loses
/// internet connectivity, and slides out when connectivity is restored.
/// Uses a Stack overlay so it does NOT push content down.
/// Automatically adapts to light and dark mode using the app's color palette.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1), // hidden above
      end: Offset.zero,           // visible
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Check initial state
    Connectivity().checkConnectivity().then(_handleResult);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen(_handleResult);
  }

  void _handleResult(List<ConnectivityResult> result) {
    final offline = result.isEmpty || result.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      setState(() => _isOffline = offline);
      if (offline) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // — The actual content (full area, not pushed down) —
        widget.child,

        // — The overlay banner —
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 4,
              shadowColor: Colors.black26,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: topPadding + 6,
                  bottom: 10,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDk  // Dark mode elevated surface
                      : AppColors.surfaceElevated,    // Light mode warm tan
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.warning   // Golden brown on dark
                          : AppColors.structureMuted, // Brown on light
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No internet connection',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.warning
                            : AppColors.structureMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
