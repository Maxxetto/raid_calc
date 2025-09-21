# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads SDK
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-keepclassmembers class com.google.android.gms.ads.** { *; }

# UMP SDK (consent)
-keep class com.google.android.ump.** { *; }
-keepclassmembers class com.google.android.ump.** { *; }
