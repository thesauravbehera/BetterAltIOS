import 'package:flutter/material.dart';

/// BetterAlt Color Palette
/// PRIMARY:   #efe6d9 → #decdb3 → #c7ab7f → #af884c → #7b5f35 (warm tans/browns)
/// SECONDARY: #9bd6b4 → #69c28f → #42a26b → #2e704a → #1b412b (fresh greens)
/// NEUTRAL:   #ffffff → #e8e8e8 → #d2d2d2 → #bbbbbb → #8e8e8e → #606060 → #333333

class AppColors {
  // === CANVAS (Backgrounds) ===
  // Light Mode — warm parchment from Primary palette
  static const Color canvasLight       = Color(0xFFEFE6D9); // Primary lightest
  static const Color surfaceLight      = Color(0xFFFFFFFF); // Pure white cards
  static const Color surfaceElevated   = Color(0xFFDECDB3); // Primary #2 — input fields

  // Dark Mode — sleek modern black (Blinkit / Swiggy inspired)
  static const Color canvasDark        = Color(0xFF0A0A0A); // Near-black background
  static const Color surfaceDark       = Color(0xFF161616); // Dark gray cards
  static const Color surfaceElevatedDk = Color(0xFF1E1E1E); // Slightly lighter elevated

  // === STRUCTURE (Borders, dividers) ===
  static const Color structurePrimary  = Color(0xFF2E704A); // Secondary dark green
  static const Color structureSecondary= Color(0xFF42A26B); // Secondary mid green
  static const Color structureMuted    = Color(0xFF7B5F35); // Primary dark brown
  static const Color borderLight       = Color(0xFFD2D2D2); // Neutral #3
  static const Color borderDark        = Color(0xFF2A2A2A); // Subtle gray border

  // === ACCENT (CTAs, highlights, brand) ===
  static const Color accent            = Color(0xFF42A26B); // Secondary mid — main brand green
  static const Color accentGlow        = Color(0xFF69C28F); // Secondary #2 — hover/glow
  static const Color accentMuted       = Color(0xFF2E704A); // Secondary #4 — pressed

  // === SEMANTIC ===
  static const Color success           = Color(0xFF42A26B); // Secondary mid green
  static const Color warning           = Color(0xFFAF884C); // Primary #4 — golden brown
  static const Color error             = Color(0xFFD94F4F); // Red (outside palette, needed)
  static const Color info              = Color(0xFF69C28F); // Secondary #2 light green

  // === TEXT ===
  static const Color textPrimary       = Color(0xFF333333); // Neutral darkest
  static const Color textSecondary     = Color(0xFF606060); // Neutral #9
  static const Color textTertiary      = Color(0xFF8E8E8E); // Neutral #6
  static const Color textOnAccent      = Color(0xFFFFFFFF); // White on green buttons
  static const Color textOnDark        = Color(0xFFFFFFFF); // Pure white
  static const Color textOnDarkMuted   = Color(0xFF8E8E8E); // Neutral gray muted

  // === CHART COLORS ===
  static const Color chartGreen        = Color(0xFF42A26B); // Secondary mid
  static const Color chartOrange       = Color(0xFFAF884C); // Primary #4 golden
  static const Color chartBlue         = Color(0xFF9BD6B4); // Secondary lightest mint
  static const Color chartRed          = Color(0xFFD94F4F); // Semantic red
  static const Color chartPurple       = Color(0xFF7B5F35); // Primary dark brown

  // === GRADIENT PRESETS ===
  static const List<Color> gradientPrimary = [
    Color(0xFF1B412B), // Secondary darkest
    Color(0xFF2E704A), // Secondary #4
  ];
  static const List<Color> gradientAccent = [
    Color(0xFF42A26B), // Secondary mid
    Color(0xFF69C28F), // Secondary #2
  ];
  static const List<Color> gradientCard = [
    Color(0xFFFFFFFF),
    Color(0xFFEFE6D9), // Primary lightest
  ];
  static const List<Color> gradientWarm = [
    Color(0xFFAF884C), // Primary #4 golden
    Color(0xFF7B5F35), // Primary darkest brown
  ];
}
