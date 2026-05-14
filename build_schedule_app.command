#!/bin/bash
set -e
cd "$(dirname "$0")"

SRC="Schedule.applescript"
OUT_DIR="bin"
DST="$OUT_DIR/Schedule.app"

if [ ! -f "$SRC" ]; then
    echo "❌ $SRC が見つかりません"
    read -p "Enterで閉じます..."
    exit 1
fi

mkdir -p "$OUT_DIR"

if [ -d "$DST" ]; then
    echo "🧹 既存の $DST を削除します"
    rm -rf "$DST"
fi

echo "🔨 osacompile で $DST をビルド中 (run-only モード)..."
# -x: run-only。macOS 26 Tahoe の AppleScript アプレットハング問題(FB20174869)を回避
osacompile -x -o "$DST" "$SRC"

echo ""
echo "✅ $DST を作成しました"
echo "位置: $(pwd)/$DST"
echo ""
echo "使い方:"
echo "  1. Finder で $DST をダブルクリックして起動"
echo "  2. 初回起動時は Gatekeeper 警告が出るので、右クリック → 開く で承認"
echo ""
read -p "Enterで閉じます..."
