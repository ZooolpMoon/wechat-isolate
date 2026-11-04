#!/bin/sh
# 构建 userswitch.apk（在 Ubuntu / proot 环境里用 aapt + dx + apksigner）
set -e
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"
mkdir -p "$OUT/classes"

echo "== javac =="
javac -classpath android.jar -source 8 -target 8 -d "$OUT/classes" \
    src/org/wechatfence/userswitch/MainActivity.java

echo "== dx/dalvik-exchange -> classes.dex =="
if command -v dx >/dev/null 2>&1; then
    dx --dex --output="$OUT/classes.dex" "$OUT/classes"
else
    dalvik-exchange --dex --output="$OUT/classes.dex" "$OUT/classes"
fi

echo "== aapt package =="
aapt package -f -M AndroidManifest.xml -S res -I android.jar -F "$OUT/unsigned.apk"
(cd "$OUT" && aapt add unsigned.apk classes.dex >/dev/null)

echo "== zipalign =="
zipalign -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

echo "== sign =="
if [ ! -f debug.keystore ]; then
    keytool -genkeypair -keystore debug.keystore -alias userswitch \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android \
        -dname "CN=userswitch, OU=wechatfence, O=wechatfence, C=CN" >/dev/null 2>&1
fi
apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
    --out "$OUT/userswitch.apk" "$OUT/aligned.apk"

apksigner verify --print-certs "$OUT/userswitch.apk" | head -3
aapt dump badging "$OUT/userswitch.apk" | head -5
echo "OK: $OUT/userswitch.apk"
