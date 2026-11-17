# Extra rules for R8, the tool that shrinks the release build. Flutter adds
# this file to the release build by itself.

# ML Kit starts its parts ("registrars") by name, with reflection, using
# their empty constructor. R8 can't see that, so in release it deleted the
# constructor and ML Kit failed to start: the translation model check
# failed and the app got stuck before downloading anything. Debug builds
# don't use R8, which is why they worked.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
