# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep all annotations
-keep @interface * { *; }

# Keep all classes referenced by JNI
-keepclassmembers class * {
    native <methods>;
}

# Optional: keep some common Flutter classes for reflection (adjust if needed)
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }

# Optimize but keep main functionality
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**

