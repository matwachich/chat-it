#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.0
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

Global Enum $__GUI_Create, $__GUI_Delete, $__GUI_Show, $__GUI_Hide
; ---



Func _GUI_Main($flag = $__GUI_CREATE)
	Switch $flag
		Case $__GUI_CREATE
			
		Case $__GUI_SHOW
			GuiSetState(@SW_SHOW, $GUI_Main)
		Case $__GUI_HIDE
			GuiSetState(@SW_HIDE, $GUI_Main)
		Case $__GUI_DELETE
			GuiDelete($GUI_Main)
			$GUI_Main
	EndSwitch
EndFunc
