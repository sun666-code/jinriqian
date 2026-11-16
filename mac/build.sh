#!/bin/bash
# 今日签 · 命令行构建（不需要打开 Xcode）
# 产物：dist/今日签.app（Universal：Apple 芯片 + Intel）、dist/今日签-mac.zip
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
OUT="$ROOT/dist"
APP="$OUT/今日签.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "== swiftc: $(xcrun swiftc --version 2>&1 | head -1)"
echo "== SDK: $SDK"
mkdir -p build "$OUT"

ARCHS="${ARCHS:-arm64 x86_64}"
BINS=()
for arch in $ARCHS; do
  echo "== 编译 $arch"
  xcrun swiftc -O -whole-module-optimization -sdk "$SDK" -target "$arch-apple-macos13.0" \
    -module-name JinRiQian -swift-version 5 Sources/*.swift -o "build/JinRiQian-$arch"
  BINS+=("build/JinRiQian-$arch")
done
lipo -create "${BINS[@]}" -output build/JinRiQian

echo "== 图标"
if [ ! -f build/AppIcon.icns ] || [ scripts/make-icon.swift -nt build/AppIcon.icns ]; then
  xcrun swiftc -sdk "$SDK" scripts/make-icon.swift -o build/make-icon
  rm -rf build/AppIcon.iconset
  build/make-icon build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

echo "== 打包 .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/JinRiQian "$APP/Contents/MacOS/JinRiQian"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# —— 签名 ——
# 以前每次都用「临时签名」(--sign -)，macOS 会把每次重新构建的 app 当成一个新 app，
# 于是提醒事项 / 通知 / 钥匙串的授权全部作废、重新再问。
# 现在改用一张只存在这台 Mac 钥匙串里的固定「本地签名证书」：签名不变，授权就一直有效。
SIGN_ID="JinriQian Local Signing"
KC="$HOME/Library/Keychains/login.keychain-db"
if ! security find-certificate -c "${SIGN_ID}" "$KC" >/dev/null 2>&1; then
  echo "== 第一次：生成本地签名证书（只存在这台 Mac，不上传）"
  T="$(mktemp -d)"
  cat > "$T/cfg" <<CFG
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = ${SIGN_ID}
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG
  if /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$T/cfg" \
       -keyout "$T/key.pem" -out "$T/cert.pem" >/dev/null 2>&1 \
     && /usr/bin/openssl pkcs12 -export -inkey "$T/key.pem" -in "$T/cert.pem" \
       -name "${SIGN_ID}" -passout pass:jrq -out "$T/id.p12" >/dev/null 2>&1; then
    security import "$T/id.p12" -k "$KC" -P jrq -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1 \
      && echo "   已导入钥匙串" || echo "   导入钥匙串失败"
  else
    echo "   生成证书失败"
  fi
  rm -rf "$T"
fi
if codesign --force --deep --sign "${SIGN_ID}" "$APP" 2>build/sign.err; then
  echo "== 签名：固定本地签名（${SIGN_ID}）— 重新构建后授权保持有效"
else
  echo "== 固定签名没成功（$(head -1 build/sign.err)），先用临时签名"
  codesign --force --deep --sign - "$APP"
fi
codesign -dr - "$APP" 2>&1 | tail -1
xattr -cr "$APP" || true
rm -f "$OUT/今日签-mac.zip"
ditto -c -k --keepParent "$APP" "$OUT/今日签-mac.zip"
echo "== 完成：$APP"
lipo -info "$APP/Contents/MacOS/JinRiQian"
du -sh "$APP"
