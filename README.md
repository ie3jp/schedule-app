# schedule-app

展示筐体・キオスク端末向けの **Mac 自動起動 / 自動終了 スケジューラ GUI**。AppleScript 1ファイル。

A lightweight **macOS auto wake / auto shutdown scheduler GUI** for exhibition kiosks. Single AppleScript file.

---

## 日本語

毎日決まった時刻に Mac を電源ONして夜にシャットダウンする設定を、ターミナル不要のGUIから行えます。

macOS 13 で標準の「スケジュール」UIが廃止され、`pmset repeat shutdown` は警告ダイアログや power assertion で中断されるという問題があります。本アプリは:

- **起動** → `pmset repeat wakeorpoweron`（スリープ/電源OFFから復帰）
- **終了** → `launchd` の `StartCalendarInterval` で `/sbin/shutdown -h now`（root権限で強制実行）

の分業で確実に動かします。

### 動作環境

- macOS 13 (Ventura) 〜 26 (Tahoe)
- Apple Silicon / Intel
- 管理者権限

### インストール

```bash
git clone https://github.com/ie3jp/schedule-app.git
cd schedule-app
./build_schedule_app.command
```

`bin/Schedule.app` が生成されます。

> **macOS 26 Tahoe 注意**: `osacompile -x`(run-only) は必須。これを付けないとAppleScript ランタイムバグ ([FB20174869](https://mjtsai.com/blog/2025/09/17/tahoe-applescript-timeouts/)) でUI操作のたびに10〜20秒のビーチボールが発生します。本ビルドスクリプトは `-x` 付きでビルドします。

### 初回起動 (Gatekeeper 承認)

未署名アプリのため警告が出ます。いずれかで承認:

- **A**: Finder で右クリック → 「開く」
- **B**: ダブルクリック → システム設定 → プライバシーとセキュリティ → 「このまま開く」
- **C**: `sudo xattr -cr /path/to/Schedule.app`

### 使い方

`Schedule.app` を起動するとメニューが出ます。

| 操作 | 起動 (pmset) | 終了 (launchd) |
|---|---|---|
| 両方設定 | 上書き | 上書き |
| 起動だけ設定/変更 | 上書き | 触らない |
| 終了だけ設定/変更 | 触らない | 上書き |
| すべて削除 | 削除 | 削除 |
| 現在の設定を確認 | 表示 | 表示 |

**設定時の流れ**:

1. 操作を選ぶ
2. 起動設定なら **曜日選択** (月〜日、複数選択可) → **時刻入力** (`HH:MM`、24時間表記)
3. 終了設定なら時刻入力のみ (毎日実行)
4. 確認 → 管理者パスワード入力 → 結果表示

> 終了側は毎日発火しますが、起動しない曜日に当たっても何も起きないだけなので無害です。

### 状態を CLI から確認

```bash
pmset -g sched                                        # 起動側
sudo launchctl print system/com.local.nightly-shutdown # 終了側
```

### ログ

- `/var/log/nightly-shutdown.log` (stdout)
- `/var/log/nightly-shutdown.err` (stderr)

### 運用上の前提

展示筐体として運用する場合は別途以下を設定してください。

**必須**:
- AC電源常時接続
- FileVault 無効 (起動後にログイン画面で止まらないため)
- 自動ログイン有効

**推奨**:
- macOS の自動アップデート再起動を無効化
- 省エネルギー: 「停電後に自動的に起動」

### トラブルシューティング

- **操作のたびにビーチボール (macOS 26)** — `-x` なしでビルドされた症状。再ビルドしてください
- **設定したのに動かない** — `pmset -g sched` と `sudo launchctl print system/com.local.nightly-shutdown` で登録状況を確認
- **「すべて削除」しても残骸が残る** — `sudo launchctl bootout system /Library/LaunchDaemons/com.local.nightly-shutdown.plist && sudo rm /Library/LaunchDaemons/com.local.nightly-shutdown.plist && pmset repeat cancel`
- **アップデート後に起動設定が消えた** — `pmset repeat` はメジャーアップデートでリセットされることがあります。再設定してください

### 開発

ソースは `Schedule.applescript` のみ。修正後 `./build_schedule_app.command` で再ビルド。

### ライセンス

[MIT License](LICENSE)

---

## English

GUI tool to schedule daily auto power-on and auto shutdown for a Mac without using the terminal.

The native "Schedule" UI was removed in macOS 13, and `pmset repeat shutdown` is unreliable (it shows a warning dialog and can be blocked by power assertions). This app combines:

- **Wake** → `pmset repeat wakeorpoweron` (wakes from sleep or power-off)
- **Shutdown** → `launchd` `StartCalendarInterval` firing `/sbin/shutdown -h now` (root, cannot be blocked)

### Requirements

- macOS 13 (Ventura) – 26 (Tahoe)
- Apple Silicon / Intel
- Administrator account

### Install

```bash
git clone https://github.com/ie3jp/schedule-app.git
cd schedule-app
./build_schedule_app.command
```

This produces `bin/Schedule.app`.

> **macOS 26 Tahoe note**: `osacompile -x` (run-only) is mandatory. Without it, an AppleScript runtime bug ([FB20174869](https://mjtsai.com/blog/2025/09/17/tahoe-applescript-timeouts/)) causes 10–20 second beachballs on every UI action. The build script already passes `-x`.

### First launch (Gatekeeper)

The app is unsigned, so macOS will warn on first launch. Approve with any of:

- **A**: Right-click in Finder → "Open"
- **B**: Double-click → System Settings → Privacy & Security → "Open Anyway"
- **C**: `sudo xattr -cr /path/to/Schedule.app`

### Usage

Launch `Schedule.app` to get the menu.

| Action | Wake (pmset) | Shutdown (launchd) |
|---|---|---|
| Set both | overwrite | overwrite |
| Set/change wake only | overwrite | untouched |
| Set/change shutdown only | untouched | overwrite |
| Remove all | clear | clear |
| Show current settings | show | show |

**Setup flow**:

1. Pick an action
2. For wake: pick **weekdays** (Mon–Sun, multi-select) then enter **time** (`HH:MM`, 24h)
3. For shutdown: enter time only (runs every day)
4. Confirm → admin password → result is shown

> Shutdown fires every day; on days the machine isn't scheduled to wake it simply does nothing.

### Inspect from CLI

```bash
pmset -g sched
sudo launchctl print system/com.local.nightly-shutdown
```

### Logs

- `/var/log/nightly-shutdown.log` (stdout)
- `/var/log/nightly-shutdown.err` (stderr)

### Deployment notes

For exhibition kiosks, also configure:

**Required**:
- Constant AC power
- FileVault disabled (so wake doesn't stop at the login screen)
- Automatic login enabled

**Recommended**:
- Disable automatic macOS update restarts
- Energy: "Start up automatically after a power failure"

### Troubleshooting

- **Beachball on every action (macOS 26)** — built without `-x`. Rebuild.
- **Nothing happens at the scheduled time** — verify with `pmset -g sched` and `sudo launchctl print system/com.local.nightly-shutdown`.
- **"Remove all" leaves leftovers** — `sudo launchctl bootout system /Library/LaunchDaemons/com.local.nightly-shutdown.plist && sudo rm /Library/LaunchDaemons/com.local.nightly-shutdown.plist && pmset repeat cancel`
- **Wake schedule disappeared after a macOS update** — `pmset repeat` can be reset by major updates. Reconfigure from the app.

### Development

Only source file is `Schedule.applescript`. After edits, run `./build_schedule_app.command`.

### License

[MIT License](LICENSE)
