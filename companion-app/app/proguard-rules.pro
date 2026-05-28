# Keep JsBridge methods accessible from JavaScript
-keepclassmembers class com.openclaw.android.JsBridge {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep terminal library classes
-keep class com.termux.terminal.** { *; }
-keep class com.termux.view.** { *; }
