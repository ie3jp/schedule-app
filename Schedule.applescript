-- 展示筐体用 起動/終了スケジュール設定 GUI
-- 起動: pmset repeat wakeorpoweron
-- 終了: launchd (StartCalendarInterval) で /sbin/shutdown -h now を発火

property plistPath : "/Library/LaunchDaemons/com.local.nightly-shutdown.plist"
property plistLabel : "com.local.nightly-shutdown"

on run
	repeat
		-- ダイアログが他アプリ(SecurityAgent等)の裏に隠れるのを防ぐため、毎回前面化
		tell me to activate
		set theChoice to choose from list ¬
			{"両方設定 (起動 + 終了)", "起動だけ設定/変更", "終了だけ設定/変更", "すべて削除", "現在の設定を確認"} ¬
			with title "スケジュール設定" ¬
			with prompt "操作を選択してください" ¬
			OK button name "選択" ¬
			cancel button name "閉じる"

		if theChoice is false then exit repeat
		set selected to item 1 of theChoice

		try
			if selected is "両方設定 (起動 + 終了)" then
				doSetBoth()
			else if selected is "起動だけ設定/変更" then
				doSetWakeOnly()
			else if selected is "終了だけ設定/変更" then
				doSetShutdownOnly()
			else if selected is "すべて削除" then
				doClearAll()
			else if selected is "現在の設定を確認" then
				doShowStatus()
			end if
		on error errMsg number errNum
			if errNum is -128 then
				-- ユーザーキャンセル: 何もせずメニューへ戻る
			else
				display dialog "エラー: " & errMsg buttons {"OK"} default button "OK" with icon stop
			end if
		end try
	end repeat
	-- アプリインスタンスが残らないよう確実に終了
	tell me to quit
end run

-- ===== 各操作 =====

on doSetBoth()
	set wakeTime to askTime("起動時刻を入力してください (HH:MM、24時間表記)", "08:00")
	set wakeDays to askWeekdays()
	set shutdownTime to askTime("終了時刻を入力してください (HH:MM、24時間表記)", "23:00")

	set msg to "以下の設定を行います:" & return & return & ¬
		"起動: " & formatDays(wakeDays) & " " & wakeTime & return & ¬
		"終了: 毎日 " & shutdownTime & return & return & ¬
		"管理者パスワードの入力を求められます。"
	confirmAction("両方設定", msg)

	set cmd to cancelPmsetCmd() & " ; " & cancelLaunchdCmd() & " ; " & setWakeCmd(wakeTime, weekdaysToFlags(wakeDays)) & " ; " & setShutdownCmd(shutdownTime)
	runShell(cmd)
	showResult("設定完了 (起動 + 終了)")
end doSetBoth

on doSetWakeOnly()
	set wakeTime to askTime("起動時刻を入力してください (HH:MM、24時間表記)", "08:00")
	set wakeDays to askWeekdays()

	set msg to "起動時刻を以下に設定します。" & return & ¬
		"※終了設定はそのまま残ります。" & return & return & ¬
		"起動: " & formatDays(wakeDays) & " " & wakeTime
	confirmAction("起動だけ設定/変更", msg)

	set cmd to cancelPmsetCmd() & " ; " & setWakeCmd(wakeTime, weekdaysToFlags(wakeDays))
	runShell(cmd)
	showResult("起動設定 完了")
end doSetWakeOnly

on doSetShutdownOnly()
	set shutdownTime to askTime("終了時刻を入力してください (HH:MM、24時間表記)", "23:00")

	set msg to "終了時刻を以下に設定します。" & return & ¬
		"※起動設定はそのまま残ります。" & return & return & ¬
		"終了: 毎日 " & shutdownTime
	confirmAction("終了だけ設定/変更", msg)

	set cmd to cancelLaunchdCmd() & " ; " & setShutdownCmd(shutdownTime)
	runShell(cmd)
	showResult("終了設定 完了")
end doSetShutdownOnly

on doClearAll()
	confirmAction("すべて削除", "起動・終了スケジュールをすべて削除します。" & return & "よろしいですか？")
	set cmd to cancelPmsetCmd() & " ; " & cancelLaunchdCmd()
	runShell(cmd)
	showResult("削除完了")
end doClearAll

on doShowStatus()
	showResult("現在の設定")
end doShowStatus

-- ===== 共通ハンドラ =====

on askTime(thePrompt, defaultValue)
	repeat
		set dlg to display dialog thePrompt default answer defaultValue with title "時刻入力" buttons {"キャンセル", "OK"} default button "OK" cancel button "キャンセル"
		set t to text returned of dlg
		if validateTime(t) then return t
		display dialog "形式が不正です。HH:MM (24時間表記、例: 08:30) で入力してください。" buttons {"OK"} default button "OK" with icon stop
	end repeat
end askTime

on askWeekdays()
	set dayOptions to {"月", "火", "水", "木", "金", "土", "日"}
	repeat
		tell me to activate
		set selectedDays to choose from list dayOptions ¬
			with title "起動曜日" ¬
			with prompt "起動する曜日を選択してください（複数選択可）" ¬
			OK button name "選択" ¬
			cancel button name "キャンセル" ¬
			default items dayOptions ¬
			with multiple selections allowed
		if selectedDays is false then error "ユーザーキャンセル" number -128
		if (count of selectedDays) > 0 then return selectedDays
		display dialog "1つ以上の曜日を選択してください。" buttons {"OK"} default button "OK" with icon stop
	end repeat
end askWeekdays

on formatDays(days)
	if (count of days) is 7 then return "毎日"
	-- 月→日の順で並べ替えて表示
	set ordered to {}
	repeat with d in {"月", "火", "水", "木", "金", "土", "日"}
		if days contains (d as text) then set end of ordered to (d as text)
	end repeat
	set result to ""
	repeat with d in ordered
		if result is "" then
			set result to (d as text)
		else
			set result to result & "・" & (d as text)
		end if
	end repeat
	return result & "曜"
end formatDays

on weekdaysToFlags(days)
	set flags to ""
	if days contains "月" then set flags to flags & "M"
	if days contains "火" then set flags to flags & "T"
	if days contains "水" then set flags to flags & "W"
	if days contains "木" then set flags to flags & "R"
	if days contains "金" then set flags to flags & "F"
	if days contains "土" then set flags to flags & "S"
	if days contains "日" then set flags to flags & "U"
	return flags
end weekdaysToFlags

on validateTime(t)
	try
		if length of t is not 5 then return false
		if character 3 of t is not ":" then return false
		set hh to (text 1 thru 2 of t) as integer
		set mm to (text 4 thru 5 of t) as integer
		if hh < 0 or hh > 23 then return false
		if mm < 0 or mm > 59 then return false
		return true
	on error
		return false
	end try
end validateTime

on confirmAction(theTitle, theMsg)
	display dialog theMsg with title theTitle buttons {"キャンセル", "実行"} default button "実行" cancel button "キャンセル"
end confirmAction

on runShell(cmd)
	do shell script cmd with administrator privileges
end runShell

on showResult(theTitle)
	-- launchctl の system domain は root でないと見えないので、
	-- print system/<label> で存在チェックし、StartCalendarInterval を抽出
	set statusCmd to "echo '=== 起動 (pmset -g sched) ===' ; pmset -g sched 2>&1 ; echo ; echo '=== 終了 (launchctl) ===' ; if launchctl print system/" & plistLabel & " >/dev/null 2>&1 ; then echo '登録済み: " & plistLabel & "' ; launchctl print system/" & plistLabel & " 2>/dev/null | grep -E 'state|Hour|Minute|path' | head -10 ; else echo '(未設定)' ; fi ; echo ; echo '=== plistファイル ===' ; (ls -l " & quoted form of plistPath & " 2>/dev/null || echo '(plistなし)')"
	-- with administrator privileges を付けないと system domain が見えない
	set resultText to do shell script statusCmd with administrator privileges
	tell me to activate
	display dialog resultText with title theTitle buttons {"OK"} default button "OK"
end showResult

-- ===== コマンド文字列生成 =====

on cancelPmsetCmd()
	return "pmset repeat cancel 2>/dev/null || true"
end cancelPmsetCmd

on cancelLaunchdCmd()
	-- bootout は非同期完了。ジョブが消えてから rm しないと、後続の bootstrap が
	-- "already loaded" で失敗することがある。最大2秒待ってから plist 削除。
	return "launchctl bootout system " & quoted form of plistPath & " 2>/dev/null ; " & ¬
		"for i in 1 2 3 4 5 6 7 8 9 10; do launchctl print system/" & plistLabel & " >/dev/null 2>&1 || break; sleep 0.2; done ; " & ¬
		"rm -f " & quoted form of plistPath
end cancelLaunchdCmd

on setWakeCmd(t, flags)
	set hh to text 1 thru 2 of t
	set mm to text 4 thru 5 of t
	return "pmset repeat wakeorpoweron " & flags & " " & hh & ":" & mm & ":00"
end setWakeCmd

on setShutdownCmd(t)
	set hhInt to (text 1 thru 2 of t) as integer
	set mmInt to (text 4 thru 5 of t) as integer

	set plistContent to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" & linefeed & ¬
		"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" & linefeed & ¬
		"<plist version=\"1.0\">" & linefeed & ¬
		"<dict>" & linefeed & ¬
		"    <key>Label</key><string>" & plistLabel & "</string>" & linefeed & ¬
		"    <key>ProgramArguments</key>" & linefeed & ¬
		"    <array>" & linefeed & ¬
		"        <string>/sbin/shutdown</string>" & linefeed & ¬
		"        <string>-h</string>" & linefeed & ¬
		"        <string>now</string>" & linefeed & ¬
		"    </array>" & linefeed & ¬
		"    <key>StartCalendarInterval</key>" & linefeed & ¬
		"    <dict>" & linefeed & ¬
		"        <key>Hour</key><integer>" & hhInt & "</integer>" & linefeed & ¬
		"        <key>Minute</key><integer>" & mmInt & "</integer>" & linefeed & ¬
		"    </dict>" & linefeed & ¬
		"    <key>StandardOutPath</key><string>/var/log/nightly-shutdown.log</string>" & linefeed & ¬
		"    <key>StandardErrorPath</key><string>/var/log/nightly-shutdown.err</string>" & linefeed & ¬
		"</dict>" & linefeed & ¬
		"</plist>" & linefeed

	set writeCmd to "printf '%s' " & quoted form of plistContent & " > " & quoted form of plistPath
	set chownCmd to "chown root:wheel " & quoted form of plistPath
	set chmodCmd to "chmod 644 " & quoted form of plistPath
	set lintCmd to "plutil -lint " & quoted form of plistPath
	set loadCmd to "launchctl bootstrap system " & quoted form of plistPath

	-- 各ステップは && で繋ぎ、plistが壊れていたら bootstrap 前に止める
	return writeCmd & " && " & chownCmd & " && " & chmodCmd & " && " & lintCmd & " && " & loadCmd
end setShutdownCmd
