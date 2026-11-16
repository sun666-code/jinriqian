#!/bin/bash
# 今日签 · 山人 一键构建：编译 → 自检 → 打包 → 截图 → git 提交（不 push）
# 产物在 dist/，截图在 screens/（两者都不进 git）。
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
exec > >(tee "$DIR/build.log") 2>&1
echo "===== 今日签·山人 构建 $(date '+%F %T') ====="
sw_vers 2>/dev/null | tr '\n' ' '; echo; uname -m

# 第一次构建时，在这里建一个全新的 git 仓库（以后开源就直接用它，历史干净、不带旧版的大文件）
if [ ! -d .git ]; then
  git init -q && git add -A && git commit -q -m "chore: 今日签 · 山人 开源仓库初始化" && echo "✔ 已在本文件夹建好 git 仓库"
fi

commit_queue() {
  [ -d .commit-queue ] || return 0
  for f in $(ls .commit-queue/*.txt 2>/dev/null | sort); do
    msg="$(sed '/^---$/,$d' "$f")"
    paths="$(sed '1,/^---$/d' "$f")"
    echo "$paths" | while IFS= read -r p; do [ -n "$p" ] && git add -A -- "$p" 2>/dev/null; done
    if ! git diff --cached --quiet; then git commit -q -F <(printf '%s\n' "$msg") && echo "✔ commit: $(echo "$msg" | head -1)"; fi
    rm -f "$f"
  done
}

if ! /bin/bash ./mac/build.sh; then echo "❌ 构建失败，详见上方日志"; exit 1; fi
APP="dist/今日签.app"
BIN="$APP/Contents/MacOS/JinRiQian"

echo "== 自检"
"$BIN" --selftest || echo "⚠️ 自检有失败项"

echo "== 截图"
rm -rf screens && mkdir -p screens
"$BIN" --snapshots "$DIR/screens"
ls screens | wc -l | xargs echo "截图数量："
cp mac/build/AppIcon.iconset/icon_512x512.png screens/00-App图标.png 2>/dev/null || true

echo "== 内存"
open -n -g "$APP" --args --memtest || true
sleep 8
PID=$(pgrep -nf "今日签.app/Contents/MacOS/JinRiQian" || true)
if [ -n "$PID" ]; then
  ps -o rss= -p "$PID" | awk '{printf "空闲常驻内存 RSS ≈ %.1f MB\n", $1/1024}'
  footprint "$PID" 2>/dev/null | grep -i "phys_footprint:" | head -1 || true
  kill "$PID" 2>/dev/null || true
fi

echo "== 安全检查"
if grep -rEn -D skip -I "sk-[A-Za-z0-9]{10,}" --exclude-dir=dist --exclude-dir=build --exclude-dir=演示素材 --exclude=build.log --exclude=演示录制.log . ; then echo "❌ 发现疑似密钥"; else echo "✅ 未发现 sk- 密钥"; fi

commit_queue

# 只在放了 .reset-once 标记时执行一次：清零数据，以新用户身份打开
if [ -f .reset-once ]; then
  echo "== 清零为新用户"
  pkill -f "今日签.app/Contents/MacOS/JinRiQian" 2>/dev/null; pkill -f "今日签新版.app/Contents/MacOS/JinRiQian" 2>/dev/null; sleep 1
  "$BIN" --reset
  rm -f .reset-once
  open "$APP"
else
  # 平时：把正在运行的旧版本关掉，换成刚构建好的这一版
  pkill -f "今日签.app/Contents/MacOS/JinRiQian" 2>/dev/null; pkill -f "今日签新版.app/Contents/MacOS/JinRiQian" 2>/dev/null; sleep 1
  open "$APP"
  echo "== 已用新版重新打开"
fi
echo "===== 结束 $(date '+%T') ====="
