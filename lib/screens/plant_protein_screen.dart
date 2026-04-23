import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class PlantProteinScreen extends StatefulWidget {
  const PlantProteinScreen({super.key});

  @override
  State<PlantProteinScreen> createState() => _PlantProteinScreenState();
}

class _PlantProteinScreenState extends State<PlantProteinScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Log analytics event
    _logVisit();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://betteralt.in/products/plant-protein?utm_source=betteralt_app&utm_medium=android_app&utm_campaign=plant_protein_tab'));
  }

  Future<void> _logVisit() async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'visited_plant_protein',
        parameters: {'source': 'bottom_nav_tab'},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: Column(
          children: [
            
            // WebView filling the rest of the screen
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: controller),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
