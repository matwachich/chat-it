#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         Matwachich
 Date:			 29/09/2011

 Script Function:
	Simple Configuration, Version 2.0
		Restructuration et simplification complète du code
	
	Version 2.1
	- Correction du bug des valeurs numériques: toute variable stockée est d'abord
		convertie en String

#ce ----------------------------------------------------------------------------

#cs
File: AutoConfig
	This UDF contains functions that help managing the configuration of your scripts.
	
	You can use either an *.ini file, or registry keys, the UDF manage for you all
	IniRead/IniWrite or RegRead/RegWrite calls.

Version:
	- 1.1 - Added $iForceUpdate parameter for <CFG>
	- 1.0 - Initial release
	
Instructions:
	First, you must call <_AutoCfg_Init> to setup the system, which method will be used
	to stor the config (ini/reg), the path (ini file/reg key) and various options (data encryption,
	ini file section).
	
	After that, you must add the configuration entries that will be used, with their
	respective default value (use <_AutoCfg_AddEntry>).
	
	Next, you must call <_AutoCfg_Update> to update every entry with either it's corresponding value
	on the disk (ini/reg) or with it's default value if no value is present on the disk.
	
	Finally, you can use in your script the function <CFG> to get the current value of an entry, or
	an array of all the entries and their values and default values. And the function
	<_AutoCfg_SetEntry> the set the value of an entry or set it to it's default value.
	
Example:
	(start code)
	#include <ButtonConstants.au3>
	#include <EditConstants.au3>
	#include <GUIConstantsEx.au3>
	#include <WindowsConstants.au3>
	#include <Array.au3>

	#include <AutoConfig.au3>

	_AutoCfg_Init($ACFG_Ini, @ScriptDir & "\config.ini", "", "")
		_AutoCfg_AddEntry("nom", "Jean") ; on spécifie les paramètres
		_AutoCfg_AddEntry("prenom", "Dupon") ; avec leurs valeur par défaut
		_AutoCfg_AddEntry("age", "25")
		_AutoCfg_AddEntry("pass", "secret!")
		_AutoCfg_AddEntry("email", "rien@test.fr")
		_AutoCfg_AddEntry("pseudo", "matwachich")
	_AutoCfg_Update()

	#Region ### START Koda GUI section ### Form=
	$Form1 = GUICreate("Test", 272, 230, 444, 203)
	$Edit = GUICtrlCreateEdit("", 10, 10, 251, 176)
	GUICtrlSetData(-1, "")
	$B_go = GUICtrlCreateButton("Action!", 10, 195, 75, 25, $WS_GROUP)
	$B_cfg = GUICtrlCreateButton("Paramètres", 185, 195, 75, 25, $WS_GROUP)
	GUISetState(@SW_SHOW)
	#EndRegion ### END Koda GUI section ###

	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case $GUI_EVENT_CLOSE
				Exit
			Case $B_cfg
				_cfg()
			Case $B_go ; Ici, on montre comment récupérer les paramètres dans le programme
				_cw("Configuration Actuelle")
				_cw(" - Nom: " & 	CFG("nom"))
				_cw(" - Prénom: " & 	CFG("prenom"))
				_cw(" - Age: " & 	CFG("age"))
				_cw(" - E-mail: " & 	CFG("email"))
				_cw(" - Pseudo: " & 	CFG("pseudo"))
				_cw(" - Pass: " & 	CFG("pass"))
				_cw(" ------------------------------")
				$a = CFG()
				_ArrayDisplay($a)

		EndSwitch
	WEnd

	Func _cfg()
		#Region ### START Koda GUI section ### Form=
		$Form2 = GUICreate("Paramètres", 257, 220, 378, 206)
		$Input1 = GUICtrlCreateInput(CFG("nom"), 100, 20, 121, 21)
			GUICtrlCreateLabel("Nom", 25, 23, 26, 17)
		$Input2 = GUICtrlCreateInput(CFG("prenom"), 100, 45, 121, 21)
			GUICtrlCreateLabel("Prenom", 25, 48, 40, 17)
		$Input3 = GUICtrlCreateInput(CFG("age"), 100, 70, 121, 21)
			GUICtrlCreateLabel("Age", 25, 73, 23, 17)
		$Input4 = GUICtrlCreateInput(CFG("email"), 100, 95, 121, 21)
			GUICtrlCreateLabel("E-mail", 25, 98, 42, 17)
		$Input5 = GUICtrlCreateInput(CFG("pseudo"), 100, 120, 121, 21)
			GUICtrlCreateLabel("Pseudo", 25, 123, 40, 17)
		$Input6 = GUICtrlCreateInput(CFG("pass"), 100, 145, 121, 21)
			GUICtrlCreateLabel("Mot de passe", 25, 148, 68, 17)
		$B_ok = GUICtrlCreateButton("Valider", 90, 180, 75, 25, $WS_GROUP)
		GUISetState(@SW_SHOW)
		#EndRegion ### END Koda GUI section ###

		While 1
			$nMsg = GUIGetMsg()
			Switch $nMsg
				Case $GUI_EVENT_CLOSE
					GUIDelete($Form2)
					ExitLoop
				Case $B_ok ; On enregistre tous les paramètres
					_AutoCfg_SetEntry("nom", GUICtrlRead($Input1))
					_AutoCfg_SetEntry("prenom", GUICtrlRead($Input2))
					_AutoCfg_SetEntry("age", GUICtrlRead($Input3))
					_AutoCfg_SetEntry("email", GUICtrlRead($Input4))
					_AutoCfg_SetEntry("pseudo", GUICtrlRead($Input5))
					_AutoCfg_SetEntry("pass", GUICtrlRead($Input6))

					GUIDelete($Form2)
					ExitLoop

			EndSwitch
		WEnd

	EndFunc

	Func _cw($data)
		GUICtrlSetData($Edit, "> " & $data & @CRLF, 1)
	EndFunc
	(end)
#ce

#include <Crypt.au3>

Global Enum $ACFG_REG, $ACFG_INI
Global $__ACFG_Array[1][2] = [[0,""]]
; ---
Global Enum $__ACFG_INITED, $__ACFG_TYPE, $__ACFG_PATH, $__ACFG_SECTION, $__ACFG_CRY, $__ACFG_PWD
Global $__ACFG_CONFIG[6] = [0, -1, -1, -1, -1, -1]
; ---
Global $__ACFG_hKey = -1, $__ACFG_VarPrefix = "__X_X_X__"

; ##############################################################
; Main functions

#cs
Function: _AutoCfg_Init
	Initiate the AutoConfig System.

Prototype:
	>_AutoCfg_Init($Type, $Path, $Section = "Auto_Cfg", $Pwd = "")

Parameters:
	$Type - Type of data storage (*$ACFG_INI* for an \*.ini file, or *$ACFG_REG* for a registery key)
	$Path - Path of the *.ini file, or registery key
	$Section - Section of the *.ini file (ignored if registery key)
	$Pwd - If Empry, no  then no data encryption will be used, if not empty, than the stored data
	will be encrypted using this password (RC4 Encryption)

Returns:
	Succes - 1
	Failed - 0 and set @error
	
	- 1 = AutoConfig is already initiated
#ce
Func _AutoCfg_Init($Type, $Path, $Section = "Auto_Cfg", $Pwd = "")
	If $Type <> $ACFG_REG And $Type <> $ACFG_INI Then Return SetError(1, 0, 0)
	; ---
	$__ACFG_CONFIG[$__ACFG_TYPE] = $Type
	; ---
	If Not $Pwd Then
		$__ACFG_CONFIG[$__ACFG_CRY] = False
		$__ACFG_CONFIG[$__ACFG_PWD] = ""
	Else
		$__ACFG_CONFIG[$__ACFG_CRY] = True
		$__ACFG_CONFIG[$__ACFG_PWD] = $Pwd
		; ---
		__ACFG_CryptInit($Pwd)
		OnAutoItExitRegister("__ACFG_CryptDeInit")
	EndIf
	; ---
	$__ACFG_CONFIG[$__ACFG_PATH] = $Path
	$__ACFG_CONFIG[$__ACFG_SECTION] = $Section
	; ---
	$__ACFG_CONFIG[$__ACFG_INITED] = 1
	; ---
	Return 1
EndFunc

#cs
Function: _AutoCfg_AddEntry
	Add a configuration parameter (An entry), with it's default value.

Prototype:
	>_AutoCfg_AddEntry($Name, $DefaultVal)

Parameters:
	$Name - Entry name
	$DefaultVal - Default value of the entry

Returns:
	Succes - 1
	Failed - 0 And set @error
	
	- 1 = AutoConfig isn't initiated
	- 2 = The entry already exists	
#ce
Func _AutoCfg_AddEntry($Name, $DefaultVal)
	If Not __ACFG_IsInit() Then Return SetError(1, 0, 0)
	If __ACFG_EntryExists($Name) Then Return SetError(2, 0, 0)
	; ---
	Local $ub = $__ACFG_Array[0][0]
	ReDim $__ACFG_Array[$ub + 2][2]
	$__ACFG_Array[$ub + 1][0] = $Name
	$__ACFG_Array[$ub + 1][1] = $DefaultVal
	$__ACFG_Array[0][0] += 1
	; ---
	Return 1
EndFunc

#cs
Function: _AutoCfg_Update
	Update all/one entry(ies) with either it's corresponding value on the disk (ini/reg), or with
	it's default value.

Prototype:
	>_AutoCfg_Update($Name = Default)

Parameters:
	$Name - Entry name to update (if default then all entries are updated)

Returns:
	Succes - 1
	Failed - 0 And set @error
	
	- 1 = AutoConfig isn't initiated
#ce
Func _AutoCfg_Update($Name = Default)
	If Not __ACFG_IsInit() Then Return SetError(1, 0, 0)
	; ---
	If $Name <> Default Then
		If Not __ACFG_EntryExists($Name) Then Return SetError(2, 0, 0)
		; ---
		Assign($__ACFG_VarPrefix & $Name, __ACFG_EntryRead($Name, __ACFG_EntryGetDefault($Name)), 2)
		Return 1
	EndIf
	; ---
	For $i = 1 To $__ACFG_Array[0][0]
		Assign($__ACFG_VarPrefix & $__ACFG_Array[$i][0], __ACFG_EntryRead($__ACFG_Array[$i][0], $__ACFG_Array[$i][1]), 2)
	Next
	; ---
	Return 1
EndFunc

#cs
Function: _AutoCfg_SetEntry
	Set the value of an entry, or set it to it's default value.

Prototype:
	>_AutoCfg_SetEntry($Name, $Value = Default)

Parameters:
	$Name - Entry name
	$Value - Value to assign. If Default then the default value is assigned.

Returns:
	Succes - 1
	Failed - 0 And set @error
	
	- 1 = AutoConfig isn't initiated
	- 2 = The entry doesn't exists
#ce
Func _AutoCfg_SetEntry($Name, $Value = Default)
	If Not __ACFG_IsInit() Then Return SetError(1, 0, 0)
	If Not __ACFG_EntryExists($Name) Then Return SetError(2, 0, 0)
	; ---
	If $Value = Default Then Return __ACFG_EntryResetToDefault($Name)
	; ---
	Assign($__ACFG_VarPrefix & $Name, $Value, 2)
	$Value = __ACFG_Cry($Value)
	; ---
	Switch $__ACFG_CONFIG[$__ACFG_TYPE]
		Case $ACFG_INI
			IniWrite($__ACFG_CONFIG[$__ACFG_PATH], $__ACFG_CONFIG[$__ACFG_SECTION], $Name, $Value)
		Case $ACFG_REG
			RegWrite($__ACFG_CONFIG[$__ACFG_PATH], $Name, "REG_SZ", $Value)
	EndSwitch
	; ---
	Return 1
EndFunc

#cs
Function: CFG
	Return the current value of an entry.

Prototype:
	>CFG($Name = Default)

Parameters:
	$Name - Entry name. If Default then an array of all entries and their respective values and default values
		is returned (see Returns).
	$iForceUpdate - If set, then <_AutoCfg_Update> is called befor returning the value(s)

Returns:
	Succes - Value of the entry or (if $Name = Default)
	
	*$array[0][0]* = Number of entries
	
	*$array[$i][0]* = Entry name
	
	*$array[$i][1]* = Entry current value
	
	*$array[$i][2]* = Entry default value
	
	Failed - 0 And set @error
	
	- 1 = AutoConfig isn't initiated
	- 2 = The entry doesn't exists
#ce
Func CFG($Name = Default, $iForceUpdate = 0)
	If Not __ACFG_IsInit() Then Return SetError(1, 0, 0)
	; ---
	If $iForceUpdate Then _AutoCfg_Update($Name)
	; ---
	If $Name = Default Then Return __ACFG_GetAllEntries()
	; ---
	Local $tmp = Eval($__ACFG_VarPrefix & $Name)
	If @error Then Return SetError(2, 0, 0)
	; ---
	Return $tmp
EndFunc

; ##############################################################
; Internals

; Checks if an entry exists or not
Func __ACFG_EntryExists($Name)
	For $i = 1 To $__ACFG_Array[0][0]
		If $__ACFG_Array[$i][0] = $Name Then Return 1
	Next
	Return 0
EndFunc

; Returns the default value of an entry
Func __ACFG_EntryGetDefault($Name)
	For $i = 1 To $__ACFG_Array[0][0]
		If $__ACFG_Array[$i][0] = $Name Then Return $__ACFG_Array[$i][1]
	Next
	Return SetError(1, 0, 0)
EndFunc

; Read the value of an entry from disk if there is some value stored, or return the default value
Func __ACFG_EntryRead($Name, $Default)
	Local $tmp
	; ---
	Switch $__ACFG_CONFIG[$__ACFG_TYPE]
		Case $ACFG_INI
			$tmp = IniRead($__ACFG_CONFIG[$__ACFG_PATH], $__ACFG_CONFIG[$__ACFG_SECTION], $Name, Chr(2))
		Case $ACFG_REG
			$tmp = RegRead($__ACFG_CONFIG[$__ACFG_PATH], $Name)
			If $tmp = 0 And @error Then $tmp = Chr(2)
	EndSwitch
	; ---
	If $tmp = Chr(2) Then Return $Default
	; ---
	$tmp = __ACFG_dCry($tmp)
	Return $tmp
EndFunc

; Reset the entry to it's default value by deleting the stored value on disk, and updating the entry
Func __ACFG_EntryResetToDefault($Name)
	Switch $__ACFG_CONFIG[$__ACFG_TYPE]
		Case $ACFG_INI
			IniDelete($__ACFG_CONFIG[$__ACFG_PATH], $__ACFG_CONFIG[$__ACFG_SECTION], $Name)
		Case $ACFG_REG
			RegDelete($__ACFG_CONFIG[$__ACFG_PATH], $Name)
	EndSwitch
	; ---
	Return _AutoCfg_Update($Name)
EndFunc

; Returns an array of all the entries, their current value, and their default ones
Func __ACFG_GetAllEntries()
	Local $ret[$__ACFG_Array[0][0] + 1][3] = [[$__ACFG_Array[0][0],"",""]]
	For $i = 1 To $__ACFG_Array[0][0]
		$ret[$i][0] = $__ACFG_Array[$i][0]		; Name
		$ret[$i][1] = CFG($__ACFG_Array[$i][0])	; Current Value
		$ret[$i][2] = $__ACFG_Array[$i][1]		; Default Value
	Next
	; ---
	Return $ret
EndFunc

; ##############################################################
; Misc

Func __ACFG_IsInit()
	Return $__ACFG_CONFIG[$__ACFG_INITED]
EndFunc

Func __ACFG_Cry($data)
	If $__ACFG_CONFIG[$__ACFG_CRY] = False Then Return $data
	; ---
	Return StringTrimLeft(_Crypt_EncryptData(String($data), $__ACFG_hKey, $CALG_USERKEY), 2)
EndFunc

Func __ACFG_dCry($data)
	If $__ACFG_CONFIG[$__ACFG_CRY] = False Then Return $data
	; ---
	Return BinaryToString(_Crypt_DecryptData(Binary("0x" & $data), $__ACFG_hKey, $CALG_USERKEY))
EndFunc

Func __ACFG_CryptInit($Pwd)
	$__ACFG_hKey = _Crypt_DeriveKey($Pwd, $CALG_RC4)
EndFunc

Func __ACFG_CryptDeInit()
	_Crypt_DestroyKey($__ACFG_hKey)
EndFunc
