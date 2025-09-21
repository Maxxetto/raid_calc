# Keep Flutter/AdMob/UMP runtime classes for release builds
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.ump.**
