# ──────────────────────────────────────────────────────────
# BetterAlt — ProGuard / R8 Rules for Release Builds
# ──────────────────────────────────────────────────────────

# ── Google ML Kit (image labeling & text recognition) ──
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── Firebase ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Gson (used by Firebase for JSON serialization) ──
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── OkHttp / Okio (network layer) ──
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Crashlytics (if added later) ──
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ── Health Connect ──
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# ── Kotlin Coroutines ──
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }
