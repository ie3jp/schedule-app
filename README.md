# schedule-app

展示筐体・キオスク端末用の **Mac 自動起動 / 自動終了 スケジューラ GUI**。

毎日決まった時刻に Mac を自動で電源ONして、夜に自動でシャットダウンする設定を、ターミナル不要のGUIから行えます。AppleScript 1ファイルで実装した軽量ツール。

## なぜ作ったか

展示用 Mac の運用で、毎朝決まった時刻に起動して夜に終了させたい、という要件は頻繁にあります。標準の方法は2つありますが、それぞれ問題があります:

- **システム設定の「スケジュール」UI** — macOS 13 で削除されました
- **`pmset repeat shutdown`** — シャットダウン前に警告ダイアログを出し、画面共有や `caffeinate` 等の power assertion で中断される

このアプリは:

- **起動** → `pmset repeat wakeorpoweron`（電源OFF/スリープから確実に復帰）
- **終了** → `launchd` の `StartCalendarInterval` で `/sbin/shutdown -h now` を発火（root権限の強制シャットダウンなので assertion でブロックされない）

この分業で確実に動かします。

## 動作環境

- macOS 13 (Ventura) 〜 26 (Tahoe)
- Apple Silicon / Intel どちらでも可
- 管理者権限（パスワード入力できるユーザー）が必要

## インストール

```bash
git clone https://github.com/ie3jp/schedule-app.git
cd schedule-app
./build_schedule_app.command
```

または `osacompile` を直接:

```bash
osacompile -x -o bin/Schedule.app Schedule.applescript
```

> **macOS 26 Tahoe の重要な注意**
> `osacompile` の `-x` オプション（run-only）は **必須** です。これを付けないと macOS 26 Tahoe の AppleScript ランタイムバグ ([FB20174869](https://mjtsai.com/blog/2025/09/17/tahoe-applescript-timeouts/)) で UI 操作のたびに10〜20秒のビーチボールが発生します。本プロジェクトのビルドスクリプトは `-x` 付きでビルドします。

ビルドが成功すると `bin/Schedule.app` が生成されます。これだけが運用に必要なファイルです。

## 初回起動 (Gatekeeper 承認)

未署名アプリのため、ダブルクリックでは「壊れている」「開発元を確認できない」等の警告が出ます。以下のいずれかで承認してください。

### 方法A: 右クリック → 開く
1. Finder で `Schedule.app` を右クリック → 「開く」
2. 警告ダイアログで「開く」を選択

### 方法B: システム設定で承認
1. 普通にダブルクリック（ブロックされる）
2. システム設定 → 「プライバシーとセキュリティ」 → 一番下の「このまま開く」

### 方法C: quarantine 属性を剥がす（上記が効かないとき）

```bash
sudo xattr -cr /path/to/Schedule.app
```

## 使い方

`Schedule.app` をダブルクリック起動すると操作メニューが表示されます。

| 操作 | 起動 (pmset) | 終了 (launchd) |
|---|---|---|
| **両方設定 (起動 + 終了)** | 上書き | 上書き |
| **起動だけ設定/変更** | 上書き | **触らない** |
| **終了だけ設定/変更** | **触らない** | 上書き |
| **すべて削除** | 削除 | 削除 |
| **現在の設定を確認** | 表示のみ | 表示のみ |

### 操作の流れ

1. 操作を選択
2. （設定操作なら）時刻を `HH:MM` で入力（24時間表記、例: `08:00` / `23:00`）
3. 確認ダイアログで内容を確認 → 「実行」
4. 管理者パスワードを入力
5. 結果ダイアログで現在の設定が表示される
6. メニューに戻る（連続操作可能）。終わるときは「閉じる」

### 「起動だけ」「終了だけ」の使い所

運用中に片方の時刻だけ変えたいときに、もう片方の設定を消さずに済みます。両方を一気にリセットしたいときは「両方設定」または「すべて削除」を使ってください。

## 仕組み

### LaunchDaemon plist

書き出し先: `/Library/LaunchDaemons/com.local.nightly-shutdown.plist`

```xml
<plist version="1.0">
<dict>
    <key>Label</key><string>com.local.nightly-shutdown</string>
    <key>ProgramArguments</key>
    <array>
        <string>/sbin/shutdown</string>
        <string>-h</string>
        <string>now</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>HH</integer>
        <key>Minute</key><integer>MM</integer>
    </dict>
    <key>StandardOutPath</key><string>/var/log/nightly-shutdown.log</string>
    <key>StandardErrorPath</key><string>/var/log/nightly-shutdown.err</string>
</dict>
</plist>
```

`RunAtLoad` は指定しないため、load 直後に即実行されることはありません。

### 内部で叩いているシェルコマンド

| 操作 | コマンド |
|---|---|
| pmset解除 | `pmset repeat cancel` |
| launchd解除 | `launchctl bootout system <plist>` + plistファイル削除 |
| 起動設定 | `pmset repeat wakeorpoweron MTWRFSU HH:MM:00` |
| 終了設定 | plist書出 → `chown` → `chmod` → `plutil -lint` → `launchctl bootstrap system <plist>` |

終了設定は `&&` でチェーンされており、`plutil -lint` で plist が壊れていたら検知して `bootstrap` させずに止まります。

すべて1回の `do shell script with administrator privileges` で実行するため、**管理者パスワードの入力は1回**で済みます。

### AppleScript 実装ポイント

- `linefeed` で plist 文字列を組み、shell に `quoted form of` で渡す
- `tell me to activate` でメインメニュー/結果ダイアログを毎回前面化（SecurityAgent 後にも対応）
- ユーザーキャンセル (`-128`) は `try/on error` で握り潰してメニューに戻る
- ループ脱出時は `tell me to quit` で確実にプロセス終了

## 状態をCLIから確認

アプリ外から登録状態を見たいとき:

```bash
# 起動スケジュール
pmset -g sched

# 終了スケジュール
sudo launchctl print system/com.local.nightly-shutdown
ls -l /Library/LaunchDaemons/com.local.nightly-shutdown.plist
```

`launchctl list` 等の legacy コマンドは system domain の LaunchDaemon が見えないので、`launchctl print system/<label>` を使ってください。

## ログ

シャットダウン実行時のログ出力先:

- `/var/log/nightly-shutdown.log` (stdout)
- `/var/log/nightly-shutdown.err` (stderr)

shutdown 直前のログなので通常は空に近く、手動ローテーションは不要です。

## 運用上の前提

展示筐体・キオスク端末として運用する際は、以下を別途設定してください。

### 必須
- **AC電源常時接続** — `pmset repeat wakeorpoweron` の信頼性確保
- **FileVault 無効** — 自動起動後にログイン画面で止まらないため
- **自動ログイン有効** — 起動 → 自動で展示アプリ起動の流れに必須

### 推奨
- **macOS の自動アップデート再起動を無効化**
  システム設定 → 一般 → ソフトウェアアップデート → 詳細
  予期しない再起動と本スケジュールの衝突を防ぐ
- **省エネルギー (電源) 設定**
  システム設定 → 省エネルギー / バッテリー → 「スリープしない」「停電後に自動的に起動」

## トラブルシューティング

### Q. アプリを起動すると操作のたびにビーチボール (macOS 26 Tahoe)

`-x` フラグ（run-only）なしでビルドした場合の症状です。Apple Bug ID **FB20174869**、GMリリースまで未修正。`osacompile -x` で再ビルドしてください。詳細は [Michael Tsai のブログ](https://mjtsai.com/blog/2025/09/17/tahoe-applescript-timeouts/) と [Apple Community のスレッド](https://discussions.apple.com/thread/256228093) を参照。

### Q. 設定したのに起動/終了しない

```bash
# 起動側
pmset -g sched

# 終了側
sudo launchctl print system/com.local.nightly-shutdown
sudo cat /var/log/nightly-shutdown.err
```

`launchctl print` 出力の `state` と `event triggers` の `Hour/Minute` が想定通りか確認してください。

### Q. 「すべて削除」したのに古い設定が残っている

過去に `launchctl load -w` で登録された残骸かもしれません。手動で除去:

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.local.nightly-shutdown.plist
sudo rm /Library/LaunchDaemons/com.local.nightly-shutdown.plist
pmset repeat cancel
```

### Q. macOS のアップデート後に起動設定が消えた

`pmset repeat` 設定はメジャーアップデートでリセットされることがあります。再度アプリから設定してください。

### Q. Gatekeeper で開けない

`sudo xattr -cr /path/to/Schedule.app` で extended attributes をすべて削除してから再度ダブルクリック。

## リポジトリ構成

```
schedule-app/
├── README.md
├── LICENSE
├── .gitignore
├── Schedule.applescript           ← ソース
├── build_schedule_app.command     ← ビルドスクリプト
└── bin/
    └── Schedule.app               ← ビルド成果物 (gitignore対象)
```

`bin/Schedule.app` は git 管理外です。`./build_schedule_app.command` で生成してください。

## 開発

ソースは `Schedule.applescript` の1ファイルのみ。修正後:

```bash
./build_schedule_app.command
open bin/Schedule.app
```

## ライセンス

[MIT License](LICENSE)
