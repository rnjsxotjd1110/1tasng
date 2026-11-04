#!/usr/bin/env bash
# STARVEIL 안드로이드 APK 빌드 (Gradle 없이 aapt2 + javac + d8)
# 필요: /opt/android-sdk/bt/android-16 (build-tools 36), /opt/android-sdk/pf/android-36 (platform)
set -euo pipefail
cd "$(dirname "$0")/.."
BT=${BT:-/opt/android-sdk/bt/android-16}
JAR=${ANDROID_JAR:-/opt/android-sdk/pf/android-36/android.jar}
OUT=build/apk
rm -rf "$OUT" && mkdir -p "$OUT"/{res,gen,classes,assets}
node tools/build.mjs
cp dist/index.html "$OUT/assets/index.html"
"$BT/aapt2" compile --dir android/res -o "$OUT/res/res.zip"
"$BT/aapt2" link -o "$OUT/base.apk" -I "$JAR" --manifest android/AndroidManifest.xml \
  -A "$OUT/assets" --java "$OUT/gen" --min-sdk-version 24 --target-sdk-version 34 \
  --version-code 2 --version-name 1.1.0 "$OUT/res/res.zip"
javac -nowarn --release 11 -classpath "$JAR" -d "$OUT/classes" \
  $(find android/src "$OUT/gen" -name '*.java') 2>&1 | grep -v '^warning' || true
"$BT/d8" --lib "$JAR" --min-api 24 --release --output "$OUT" $(find "$OUT/classes" -name '*.class')
(cd "$OUT" && zip -q -j base.apk classes.dex)
"$BT/zipalign" -f -p 4 "$OUT/base.apk" "$OUT/aligned.apk"
KS=android/starveil.keystore
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias starveil -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass starveil -keypass starveil -dname "CN=Starveil, O=Starveil, C=KR" >/dev/null 2>&1
fi
"$BT/apksigner" sign --ks "$KS" --ks-key-alias starveil --ks-pass pass:starveil --key-pass pass:starveil \
  --out dist/STARVEIL.apk "$OUT/aligned.apk"
"$BT/apksigner" verify dist/STARVEIL.apk
ls -la dist/STARVEIL.apk
