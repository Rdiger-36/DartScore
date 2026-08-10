# Rules this app has to state itself. Every plugin it uses ships its own
# consumer rules, which R8 applies automatically, so this file only covers what
# is left over.

# Play Core is referenced by the Flutter embedding for deferred components,
# which this app does not use. Without it R8 warns about the missing classes.
-dontwarn com.google.android.play.core.**

# ML Kit wires itself together at startup from a registry of components, and
# resolves each one's dependencies by class rather than by call. R8 sees no
# caller for those classes, drops them, and the barcode component then comes up
# with an unsatisfied dependency that kills the process in MlKitInitProvider,
# before any Flutter code runs. Keeping the registry and everything it can name
# is the price of shrinking the rest.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.firebase.components.** { *; }
-keep @com.google.firebase.components.ComponentRegistrar class * { *; }
-keepclassmembers class * {
    @com.google.firebase.components.ComponentRegistrar *;
}
-dontwarn com.google.mlkit.**
