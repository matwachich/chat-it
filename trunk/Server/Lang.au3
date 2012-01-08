#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

Global Enum _
	$_L_ProgName, _
	$_L_SQLiteStartupFail

Global $__Lang[1] = _
[
	"ChatIt! Server",
	"SQLite Startup Failed!"
]

Func LNG($id, $v1 = Default, $v2 = Default, $v3 = Default, $v4 = Default, $v5 = Default)
	Switch @NumParams
		Case 2
			Return StringFormat($__Lang[$id], $v1)
		Case 3
			Return StringFormat($__Lang[$id], $v1, $v2)
		Case 4
			Return StringFormat($__Lang[$id], $v1, $v2, $v3)
		Case 5
			Return StringFormat($__Lang[$id], $v1, $v2, $v3, $v4)
		Case 6
			Return StringFormat($__Lang[$id], $v1, $v2, $v3, $v4, $v5)
		Case Else
			Return $__Lang[$id]
	EndSwitch
EndFunc