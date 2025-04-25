#!/usr/bin/env osascript
----+----1----+----2----+-----3----+----4----+----5----+----6----+----7
(*
AppleのカラーパレットCLRファイル（キーアーカイブされたPLIST）
を
Simple Color Palette形式のJSONに変換します
https://github.com/simple-color-palette

Simple Color Palette Spec v0.1
MIT license

CLR2JSON.applescript (THIS APPLESCRIPT)
CC0-1.0 license

v1 20250425 初回作成  テスト中

com.cocolog-nifty.quicktimer.icefloe *)
----+----1----+----2----+-----3----+----4----+----5----+----6----+----7
use AppleScript version "2.8"
use framework "Foundation"
use framework "AppKit"
use scripting additions
property refMe : a reference to current application

########################
#CLRファイルの収集
#ユーザーのカラーパレットインストール先
set appFileManager to refMe's NSFileManager's defaultManager()
set ocidURLsArray to (appFileManager's URLsForDirectory:(refMe's NSLibraryDirectory) inDomains:(refMe's NSUserDomainMask))
set ocidLibraryDirPathURL to ocidURLsArray's firstObject()
set ocidColorsDirPathURL to ocidLibraryDirPathURL's URLByAppendingPathComponent:("Colors") isDirectory:(true)
#ユーザーのインストール済みCLRファイルの収集
set ocidOption to (refMe's NSDirectoryEnumerationSkipsHiddenFiles)
set ocidKeyArray to refMe's NSArray's arrayWithArray:({(refMe's NSURLPathKey), (refMe's NSURLIsDirectoryKey), (refMe's NSURLIsSymbolicLinkKey)})
set listSubPathResult to (appFileManager's contentsOfDirectoryAtURL:(ocidColorsDirPathURL) includingPropertiesForKeys:(ocidKeyArray) options:(ocidOption) |error|:(reference))
set ocidSubPathURLArray to item 1 of listSubPathResult
#ダイアログ用のArray＝ファイル名のみのArrayを生成
set ocidFileNameArray to refMe's NSMutableArray's alloc()'s init()
#収集したURLを順番に
repeat with itemURL in ocidSubPathURLArray
	#拡張子が
	set strExtensionName to itemURL's pathExtension() as text
	#CLRなら
	if strExtensionName is "clr" then
		#ファイル名を
		set ocidFileName to itemURL's lastPathComponent()
		#ダイアログ用のArrayに追加
		(ocidFileNameArray's addObject:(ocidFileName))
	end if
end repeat
#ソートして
set ocidFileNameArray to ocidFileNameArray's sortedArrayUsingSelector:("localizedStandardCompare:")
#ダイアログ用にLISTにする
set listFileName to ocidFileNameArray as list

########################
#ダイアログ
set strName to (name of current application) as text
if strName is "osascript" then
	tell application "System Events" to activate
else
	tell current application to activate
end if
set strTitle to ("選んでください") as text
set strPrompt to ("ひとつ選んでください") as text
try
	tell application "System Events"
		activate
		set valueResponse to (choose from list listFileName with title strTitle with prompt strPrompt default items (item 1 of listFileName) OK button name "OK" cancel button name "キャンセル" with empty selection allowed without multiple selections allowed)
	end tell
on error
	log "Error choose from list"
	return false
end try
if (class of valueResponse) is boolean then
	log "Error キャンセルしました"
	error "ユーザによってキャンセルされました。" number -128
else if (class of valueResponse) is list then
	if valueResponse is {} then
		log "Error 何も選んでいません"
		return false
	else
		set strResponse to (item 1 of valueResponse) as text
	end if
end if
########################
#選んだファイルをURLにして
set ocidColorsFilePathURL to ocidColorsDirPathURL's URLByAppendingPathComponent:(strResponse) isDirectory:(false)
set ocidColorsFilePath to ocidColorsFilePathURL's |path|()
#ファイル名
set ocidFileName to ocidColorsFilePath's lastPathComponent()
#ファイル名から拡張子を取り除いたベースファイル名
set ocidBaseFileName to ocidFileName's stringByDeletingPathExtension()

########################
#カラーデータ読み込み
set ocidReadData to refMe's NSColorList's alloc()'s initWithName:(ocidBaseFileName) fromFile:(ocidColorsFilePath)
#ALLKEYS＝読み込んだカラーデータの色名
set ocidKeyArray to ocidReadData's allKeys()
#保存用のDICT
set ocidPaletteDict to refMe's NSMutableDictionary's alloc()'s init()
ocidPaletteDict's setValue:(ocidBaseFileName) forKey:("name")
#保存用のDICTにセットするカラーのARRAY
set ocidColorArray to refMe's NSMutableArray's alloc()'s init()

repeat with itemKey in ocidKeyArray
	set ocidClolor to (ocidReadData's colorWithKey:(itemKey))
	#RGB以外処理しない
	set ocidColorSpace to ocidClolor's colorSpace()'s colorSpaceModel()
	#カラースペースがRGBなら
	if ocidColorSpace = (refMe's NSColorSpaceModelRGB) then
		log (itemKey as text) & ": RGBです"
		#各色データを取り出して
		set ocidR to ocidClolor's redComponent()
		set ocidG to ocidClolor's greenComponent()
		set ocidB to ocidClolor's blueComponent()
		set ocidA to ocidClolor's alphaComponent()
		#保存用の色要素のARRAYにセットして
		set ocidRGBArray to refMe's NSMutableArray's alloc()'s init()
		(ocidRGBArray's addObject:(ocidR))
		(ocidRGBArray's addObject:(ocidG))
		(ocidRGBArray's addObject:(ocidB))
		(ocidRGBArray's addObject:(ocidA))
		#色名と色要素でDICTにして
		set ocidSetDict to refMe's NSMutableDictionary's alloc()'s init()
		(ocidSetDict's setValue:(itemKey) forKey:("name"))
		(ocidSetDict's setObject:(ocidRGBArray) forKey:("components"))
		#出力用の色ARRAYにセット
		(ocidColorArray's addObject:(ocidSetDict))
	else
		log (itemKey as text) & ":  はRGB以外のカラースペースなので処理しない"
	end if
end repeat
#全色収集した色Arrayを出力用のDICTに追加
ocidPaletteDict's setObject:(ocidColorArray) forKey:("colors")

########################
#保存先 デスクトップ
set appFileManager to refMe's NSFileManager's defaultManager()
set ocidURLsArray to (appFileManager's URLsForDirectory:(refMe's NSDesktopDirectory) inDomains:(refMe's NSUserDomainMask))
set ocidDesktopDirPathURL to ocidURLsArray's firstObject()
set ocidBaseSaveFilePathURL to ocidDesktopDirPathURL's URLByAppendingPathComponent:(ocidBaseFileName) isDirectory:(false)
#ファイルパス
set ocidSavePlistFilePathURL to ocidBaseSaveFilePathURL's URLByAppendingPathExtension:("plist")
set ocidSaveJsonFilePathURL to ocidBaseSaveFilePathURL's URLByAppendingPathExtension:("json")

########################
#保存
log doSaveDict2Plist(ocidPaletteDict, ocidSavePlistFilePathURL)
log doSaveDict2Json(ocidPaletteDict, ocidSaveJsonFilePathURL)


########################
#JSONで保存
to doSaveDict2Json(argDict, argSavePlistFilePathURL)
	#NSJSONSerialization's
	set ocidOption to (current application's NSJSONReadingJSON5Allowed)
	set listResponse to (current application's NSJSONSerialization's dataWithJSONObject:(argDict) options:(ocidOption) |error|:(reference))
	if (item 2 of listResponse) is (missing value) then
		set ocidSaveData to (item 1 of listResponse)
		log "dataWithJSONObject　正常終了"
	else
		set strErrorNO to (item 2 of listResponse)'s code() as text
		set strErrorMes to (item 2 of listResponse)'s localizedDescription() as text
		refMe's NSLog("■：" & strErrorNO & strErrorMes)
		log ("dataWithJSONObject　でエラーしました")
		return false
	end if
	#保存
	set ocidOption to (current application's NSDataWritingAtomic)
	set listDone to (ocidSaveData's writeToURL:(argSavePlistFilePathURL) options:(ocidOption) |error|:(reference))
	return (first item of listDone)
end doSaveDict2Json


########################
#PLISTで保存
to doSaveDict2Plist(argDict, argSavePlistFilePathURL)
	#PropertyListSerialization
	set ocidSaveFormat to (current application's NSPropertyListBinaryFormat_v1_0)
	set listResponse to (current application's NSPropertyListSerialization's dataWithPropertyList:(argDict) format:(ocidSaveFormat) options:0 |error|:(reference))
	if (item 2 of listResponse) is (missing value) then
		set ocidSaveData to (item 1 of listResponse)
	else
		set strErrorNO to (item 2 of listResponse)'s code() as text
		set strErrorMes to (item 2 of listResponse)'s localizedDescription() as text
		refMe's NSLog("■：" & strErrorNO & strErrorMes)
		log ("dataWithPropertyList　でエラーしました")
		return false
	end if
	#保存
	set ocidOption to (current application's NSDataWritingAtomic)
	set listDone to (ocidSaveData's writeToURL:(argSavePlistFilePathURL) options:(ocidOption) |error|:(reference))
	return (first item of listDone)
end doSaveDict2Plist


return 0