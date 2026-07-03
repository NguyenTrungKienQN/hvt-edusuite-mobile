# Flutter Vosk Plugin rules
-keep class org.vosk.** { *; }
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.Structure {
    <fields>;
    <methods>;
}

-dontwarn java.awt.**
-dontwarn com.sun.jna.**
-dontwarn org.vosk.**

# Flutter general
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.lifecycle.** { *; }
