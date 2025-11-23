# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Core (for app bundles and dynamic delivery)
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Keep Google Play Core splitcompat classes
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Keep Google Play Core listeners and callbacks
-keep class * implements com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }
-keep class * implements com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class * implements com.google.android.play.core.tasks.OnFailureListener { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom classes used by Flutter
-keep class com.example.recipease.** { *; }

# Additional rules for Flutter release builds
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Dontwarn for missing optional dependencies
-dontwarn com.google.android.play.core.** 