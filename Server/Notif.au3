#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

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