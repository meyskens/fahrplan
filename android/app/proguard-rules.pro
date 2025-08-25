#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

-keep class com.builttoroam.devicecalendar.** { *; }
-keep class com.google.android.play.core.**  { *; }


# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# FFmpegKit rules
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# Keep all FFmpegKit native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep FFmpegKit Config
-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig {
    *;
}

# Keep ABI Detection
-keep class com.antonkarpenko.ffmpegkit.AbiDetect {
    *;
}

# Keep all FFmpegKit sessions
-keep class com.antonkarpenko.ffmpegkit.*Session {
    *;
}

# Keep FFmpegKit callbacks
-keep class com.antonkarpenko.ffmpegkit.*Callback {
    *;
}

# Preserve all public classes in ffmpegkit
-keep public class com.antonkarpenko.ffmpegkit.** {
    public *;
}

# Keep reflection-based access
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses