#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.0
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <GUIConstants.au3>
#include <GuiEdit.au3>

Func _Ask($sQuestion)
	If MsgBox(36, LNG($_L_ProgName), $sQuestion) = 6 Then Return 1
	Return 0
EndFunc

Func _Notif($sText)
	MsgBox(64, LNG($_L_ProgName), $sText)
EndFunc

Func _Err($sText, $iCritical = 0)
	MsgBox(16, LNG($_L_ProgName), $sText)
	If $iCritical Then Exit $iCritical
EndFunc

; ##############################################################

Func _Input($sText, $sDefault = "", $iPwd = 0)
	If $iPwd Then
		$iPwd = "•"
	Else
		$iPwd = ""
	EndIf
	; ---
	Local $count = StringRegExp($sText, @CRLF, 3)
	If Not IsArray($count) Then
		$count = 0
	Else
		$count = UBound($count)
	EndIf
	Local $h = 130 + (20 * $count)
	; ---
	Local $ret = InputBox(LNG($_L_ProgName), $sText, $sDefault, $iPwd, 240, $h)
	If $ret And Not @error Then
		Return SetError(0, 0, $ret)
	Else
		Return SetError(1, 0, "")
	EndIf
EndFunc

; ##############################################################
; Debug

Global $GUI_Debug, $__DEBUG_Edit

Func _dbg($data)
	If Not $DEBUG Then Return
	; ---
	If @Compiled Then
		_GuiCtrlEdit_AppendText($__DEBUG_Edit, "> " & $data & @CRLF)
		_GuiCtrlEdit_LineScroll($__DEBUG_Edit, 0, 1000000)
	Else
		ConsoleWrite("> " & $data & @CRLF)
	EndIf
EndFunc

Func _Debug_Check()
	If Not $DEBUG Then Return
	; ---
	$GUI_Debug = GuiCreate(LNG($_L_ProgName) & " - Debug Console", 400, 300, 50, 50, $WS_POPUPWINDOW + $WS_SIZEBOX)
	$__DEBUG_Edit = GuiCtrlCreateEdit("", 5, 5, 390, 290, BitOR($ES_AUTOVSCROLL,$ES_READONLY,$ES_WANTRETURN,$WS_VSCROLL), $WS_EX_STATICEDGE)
		GuiCtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKBOTTOM)
		$__DEBUG_Edit = GuiCtrlGetHandle($__DEBUG_Edit)
	; ---
	GuiSetState(@SW_SHOW, $GUI_Debug)
EndFunc