# Flutter engine + plugin registrant (defensive; the Flutter plugin also ships consumer rules)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_secure_storage uses AndroidX Security / Keystore
-keep class androidx.security.crypto.** { *; }

# Preserve annotations + generic signatures (defensive against reflective JSON paths)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
