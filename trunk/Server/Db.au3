#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.0
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

#include <Crypt.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>

Global Enum Step *2 $DB_OK = 1, $DB_CONSTRAINT, $DB_MAILBANNED, $DB_BADPWD, $DB_ERROR
Global Enum Step *2 $STATUS_ONLINE = 1, $STATUS_BUSY, $STATUS_AWAY, $STATUS_INVISIBLE, $STATUS_OFFLINE

; ##############################################################
; Main

Func _DB_Startup($sDebug = 0)
	_File_SQLite_dll(@ScriptDir & "\SQLite.dll")
	_SQLite_Startup(@ScriptDir & "\SQLite.dll", False, 1)
	If @error Then _Err(LNG($_L_SQLiteStartupFail), 1)
	; ---
	If $sDebug Then
		_SQLite_Open()
	Else
		_SQLite_Open($__AppData & "\db")
	EndIf
	_DB_CheckErr(1, "_SQLite_Open")
	; ---
	_SQLite_Exec(-1, 'CREATE TABLE IF NOT EXISTS users (pseudo UNIQUE ON CONFLICT FAIL, nom, email UNIQUE ON CONFLICT FAIL, age, sexe, localisation, presentation, password, avatar_id, socket, status, last_online, last_ip)')
	_SQLite_Exec(-1, 'CREATE TABLE IF NOT EXISTS banned_ip (ip UNIQUE ON CONFLICT FAIL)')
	_SQLite_Exec(-1, 'CREATE TABLE IF NOT EXISTS banned_mail (mail UNIQUE ON CONFLICT FAIL)')
	_SQLite_Exec(-1, 'CREATE TABLE IF NOT EXISTS deleted_users (nom UNIQUE ON CONFLICT FAIL, delete_date)')
	_SQLite_Exec(-1, 'CREATE TABLE IF NOT EXISTS avatars (bin_data)')
	; ---
	OnAutoItExitRegister("_DB_Shutdown")
EndFunc

Func _DB_Shutdown()
	_SQLite_Close()
	_SQLite_Shutdown()
	FileDelete(@ScriptDir & "\SQLite.dll")
EndFunc

; ##############################################################
; Insert

Func _DB_User_Add($sPseudo, $sMail, $sPwdHash)
	$sPseudo = _SQLite_Escape($sPseudo)
	$sMail = _SQLite_Escape($sMail)
	$sPwdHash = _SQLite_Escape($sPwdHash)
	; ---
	If _DB_Mail_IsBanned($sMail) Then Return SetError(1, 0, $DB_MAILBANNED)
	; ---
	Local $val = $sPseudo & ', "", ' & $sMail & ', "", "", "", "", ' & $sPwdHash & ', "", -1, "", "", ""'
	Switch _SQLite_Exec(-1, 'INSERT INTO users VALUES (' & $val & ')')
		Case $SQLITE_OK
			Return $DB_OK
		Case $SQLITE_CONSTRAINT
			Return $DB_CONSTRAINT
		Case Else
			Return $DB_ERROR
	EndSwitch
EndFunc

Func _DB_User_Update($sPseudo, _
						$sNom = Default, _
						$sMail = Default, _
						$sAge = Default, _
						$sSexe = Default, _
						$sLocalisation = Default, _
						$sPresentation = Default)
	; ---
	$sPseudo = _SQLite_Escape($sPseudo)
	; ---
	Local $val
	If $sNom <> Default Then
		$sNom = _SQLite_Escape($sNom)
		If $val <> "" Then $val &= ","
		$val &= ' nom=' & $sNom
	EndIf
	If $sMail <> Default Then
		If _DB_Mail_IsBanned($sMail) Then Return $DB_MAILBANNED
		; ---
		$sMail = _SQLite_Escape($sMail)
		If $val <> "" Then $val &= ","
		$val &= ' email=' & $sMail
	EndIf
	If $sAge <> Default Then
		$sAge = _SQLite_Escape($sAge)
		If $val <> "" Then $val &= ","
		$val &= ' age=' & $sAge
	EndIf
	If $sSexe <> Default Then
		$sSexe = _SQLite_Escape($sSexe)
		If $val <> "" Then $val &= ","
		$val &= ' sexe=' & $sSexe
	EndIf
	If $sLocalisation <> Default Then
		$sLocalisation = _SQLite_Escape($sLocalisation)
		If $val <> "" Then $val &= ","
		$val &= ' localisation=' & $sLocalisation
	EndIf
	If $sPresentation <> Default Then
		$sPresentation = _SQLite_Escape($sPresentation)
		If $val <> "" Then $val &= ","
		$val &= ' presentation=' & $sPresentation
	EndIf
	; ---
	Switch _SQLite_Exec(-1, 'UPDATE users SET' & $val & ' WHERE pseudo=' & $sPseudo)
		Case $SQLITE_OK
			Return $DB_OK
		Case $SQLITE_CONSTRAINT
			Return $DB_CONSTRAINT
		Case Else
			Return $DB_ERROR
	EndSwitch
EndFunc

Func _DB_User_Update2($sPseudo, _
						$avatar_id = Default, _
						$socket = Default, _
						$status = Default, _
						$last_online = Default, _
						$last_ip = Default)
	; ---
	$sPseudo = _SQLite_Escape($sPseudo)
	; ---
	Local $val
	If $avatar_id <> Default Then
		$avatar_id = _SQLite_Escape($avatar_id)
		If $val <> "" Then $val &= ","
		$val &= ' avatar_id=' & $avatar_id
	EndIf
	If $socket <> Default Then
		$socket = _SQLite_Escape($socket)
		If $val <> "" Then $val &= ","
		$val &= ' socket=' & $socket
	EndIf
	If $status <> Default Then
		$socket = _SQLite_Escape($status)
		If $val <> "" Then $val &= ","
		$val &= ' status=' & $status
	EndIf
	If $last_online <> Default Then
		$last_online = _SQLite_Escape($last_online)
		If $val <> "" Then $val &= ","
		$val &= ' last_online=' & $last_online
	EndIf
	If $last_ip <> Default Then
		$last_ip = _SQLite_Escape($last_ip)
		If $val <> "" Then $val &= ","
		$val &= ' last_ip=' & $last_ip
	EndIf
	; ---
	Switch _SQLite_Exec(-1, 'UPDATE users SET' & $val & ' WHERE pseudo=' & $sPseudo)
		Case $SQLITE_OK
			Return $DB_OK
		Case Else
			Return $DB_ERROR
	EndSwitch
EndFunc

Func _DB_ChangePwd($sPseudo, $sOldPwdHash, $sNewPwdHash)
	Local $pwd = _DB_User_GetInfo($sPseudo, "password")
	If Not IsArray($pwd) Then Return $DB_ERROR
	$pwd = $pwd[0]
	; ---
	If $pwd <> $sOldPwdHash Then Return $DB_BADPWD
	; ---
	_SQLite_Exec(-1, 'UPDATE users SET password=' & _SQLite_Escape($sNewPwdHash) & ' WHERE pseudo=' & _SQLite_Escape($sPseudo))
	Return $DB_OK
EndFunc

Func _DB_BannIP($sIP)
	Switch _SQLite_Exec(-1, 'INSERT INTO banned_ip VALUES (' & _SQLite_Escape($sIP) & ')')
		Case $SQLITE_OK
			Return $DB_OK
		Case Else
			Return $DB_ERROR
	EndSwitch
EndFunc

Func _DB_BannMail($sMail)
	Switch _SQLite_Exec(-1, 'INSERT INTO banned_mail VALUES (' & _SQLite_Escape($sMail) & ')')
		Case $SQLITE_OK
			Return $DB_OK
		Case Else
			Return $DB_ERROR
	EndSwitch
EndFunc

; ##############################################################
; Select

Func _DB_User_GetInfo($sUser, $sInfo = "*")
	Local $query, $row, $ret
	_SQLite_Query(-1, 'SELECT ' & $sInfo & ' FROM users WHERE pseudo=' & _SQLite_Escape($sUser), $query)
	If _SQLite_FetchData($query, $row) = $SQLITE_OK Then
		$ret = $row
	Else
		$ret = $DB_ERROR
	EndIf
	; ---
	_SQLite_QueryFinalize($query)
	Return $ret
EndFunc

Func _DB_User_Login($sPseudo, $sPwdHash)
	Local $pwd = _DB_User_GetInfo($sPseudo, "password")
	If Not IsArray($pwd) Then Return 0
	$pwd = $pwd[0]
	; ---
	If $pwd = $sPwdHash Then Return 1
	Return 0
EndFunc

Func _DB_IP_IsBanned($sIP)
	Local $query, $row, $ret
	_SQLite_Query(-1, 'SELECT ip FROM banned_ip WHERE ip=' & _SQLite_Escape($sIP), $query)
	If _SQLite_FetchData($query, $row) = $SQLITE_OK Then
		$ret = 1
	Else
		$ret = 0
	EndIf
	; ---
	_SQLite_QueryFinalize($query)
	Return $ret
EndFunc

Func _DB_Mail_IsBanned($sMail)
	Local $query, $row, $ret
	_SQLite_Query(-1, 'SELECT mail FROM banned_mail WHERE ip=' & _SQLite_Escape($sMail), $query)
	If _SQLite_FetchData($query, $row) = $SQLITE_OK Then
		$ret = 1
	Else
		$ret = 0
	EndIf
	; ---
	_SQLite_QueryFinalize($query)
	Return $ret
EndFunc

; ##############################################################
; Delete

Func _DB_User_Delete($sPseudo)
	$sPseudo = _SQLite_Escape($sPseudo)
	If _SQLite_Exec(-1, 'DELETE FROM avatars WHERE rowid=(SELECT avatar_id FROM users WHERE pseudo=' & $sPseudo & ')') <> $SQLITE_OK Or _
		_SQLite_Exec(-1, 'DELETE FROM users WHERE pseudo=' & $sPseudo) <> $SQLITE_OK Then Return $DB_ERROR
	; ---
	Return $DB_OK
EndFunc

; ##############################################################
; Misc

Func _DB_Debug_Display()
	Local $a, $1, $2
	_SQLite_GetTable2D(-1, 'SELECT * FROM users', $a, $1, $2)
	_ArrayDisplay($a, 'users')
	; ---
	_SQLite_GetTable2D(-1, 'SELECT * FROM banned_ip', $a, $1, $2)
	_ArrayDisplay($a, 'banned_ip')
	; ---
	_SQLite_GetTable2D(-1, 'SELECT * FROM banned_mail', $a, $1, $2)
	_ArrayDisplay($a, 'banned_mail')
	; ---
	_SQLite_GetTable2D(-1, 'SELECT * FROM deleted_users', $a, $1, $2)
	_ArrayDisplay($a, 'deleted_users')
	; ---
EndFunc

Func _DB_CheckErr($critical = 0, $sFunc = "")
	If _SQLite_ErrCode() <> $SQLITE_OK Then
		Local $err = _SQLite_ErrMsg()
		If Not @Compiled Then $err = $sFunc & ":" & @CRLF & $err
		_Err($err, $critical)
		Return 1
	EndIf
	Return 0
EndFunc
