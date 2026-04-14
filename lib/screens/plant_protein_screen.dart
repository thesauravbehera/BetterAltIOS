import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';

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
      ..loadRequest(Uri.parse('https://betteralt.in/products/plant-protein'));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: Column(
          children: [
            // Plant Protein Top Banner Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
              ),
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     "Plant Protein",
                     style: AppTypography.h2(color: isDark ? Colors.white : Colors.black87).copyWith(fontWeight: FontWeight.w800),
                   ),
                   Image.asset(
                     'images/Betteralt_main_logo.jpeg',
                     height: 65,
                     fit: BoxFit.contain,
                   ),
                 ],
              ),
            ),
            
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
