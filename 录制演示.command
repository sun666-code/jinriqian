#!/bin/bash
# 今日签 · 自动录制演示视频素材
# 会用单独的演示数据从「新用户」开始自动走一遍，不碰你自己的数据和密钥。
# 会录整块主屏幕：先藏起其他应用窗口，从桌面点菜单栏图标开始。大约 4 分钟，期间请不要动鼠标和键盘。
cd "$(dirname "$0")"
exec > >(tee 演示录制.log) 2>&1
APP="dist/今日签.app"
BIN="$APP/Contents/MacOS/JinRiQian"
LANGS="${DEMO_LANGS:-zh}"
OUT="$PWD/演示素材"
mkdir -p "$OUT"
echo "===== 开始 $(date '+%F %T') ====="
if [ ! -x "$BIN" ]; then
  echo "❌ 还没有构建好的软件：请先双击「构建新版.command」构建一次，再来录制。"
  exit 1
fi
echo "== 录制前检查"
"$BIN" --demo-check

echo "== 录屏权限测试（2 秒）"
rm -f "$OUT/test.mov"
screencapture -v -V 2 -x -R0,0,300,200 "$OUT/test.mov" < /dev/null > /dev/null 2>&1
ls -la "$OUT/test.mov" 2>&1
if [ ! -s "$OUT/test.mov" ]; then
  echo "❌ 录不了屏：请在 系统设置 → 隐私与安全性 → 录屏与系统录音 里打开「终端」，然后完全退出终端再试"
  exit 1
fi

pkill -f "今日签.app/Contents/MacOS/JinRiQian" 2>/dev/null; pkill -f "今日签新版.app/Contents/MacOS/JinRiQian" 2>/dev/null; sleep 1

for L in $LANGS; do
  echo "== 录制 $L"
  rm -f "$OUT/frame.txt" "$OUT/go" "$OUT/quit" "$OUT/events-$L.json" "$OUT/demo-$L.mov"
  "$BIN" --demo "$L" --demo-out "$OUT" &
  APID=$!
  for i in $(seq 1 150); do [ -f "$OUT/frame.txt" ] && break; sleep 0.1; done
  sleep 3
  echo "   屏幕 $(cat "$OUT/frame.txt")"
  # 录满固定时长后自动保存（这台 Mac 上录屏收不到停止指令）；演示结束后面板会一直停在原处，直到录屏保存完
  REC=${DEMO_SECONDS:-320}
  screencapture -v -V $REC -x -D1 "$OUT/demo-$L.mov" < /dev/null > "$OUT/sc-err.txt" 2>&1 &
  SCP=$!
  sleep 2.5
  echo "   录屏进程 $SCP（录 $REC 秒）"
  touch "$OUT/go"
  for i in $(seq 1 3000); do [ -f "$OUT/events-$L.json" ] && break; kill -0 $APID 2>/dev/null || break; sleep 0.1; done
  sleep 1
  echo "   演示结束，等录屏录满并保存"
  wait $SCP
  echo "   录屏已保存"
  touch "$OUT/quit"
  wait $APID 2>/dev/null
  ls -la "$OUT/demo-$L.mov" "$OUT/events-$L.json" 2>/dev/null
done

open "$APP"
echo "===== 结束 $(date '+%T') ====="
