#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         Matwachich

 Script Function:
	Fonctions simplifiants la gestions de certains aspects des scripts TCP

#ce ----------------------------------------------------------------------------
;File: Helper Functions

#cs
Function: _TCP_GetCmd
	Analyse a packet created by <_TCP_MakeCmd>, and extract the packet name, the parameters, and the data

Syntax:
	>_TCP_GetCmd($rData, ByRef $sCmd, ByRef $aParams, ByRef $Data)

Parameters:
	$rData - The packet
	$sCmd - Will be filled with the packet name
	$aParams - Will be filled with a 1-Based array, where Elem[0] is the number of parameters, and
				the other elements Elem[x], will be the parameters
	$Data - Will be filled with the packet's Data

Return:
	Succes - 1
	Failed - 0 And set @error = 1 if the packet isn't valid
#ce
Func _TCP_GetCmd($rData, ByRef $sCmd, ByRef $aParams, ByRef $Data)
	$rData = StringSplit($rData, Chr(29), 1)
	If $rData[0] <> 3 Then Return SetError(1, 0, 0)
	; ---
	$sCmd = $rData[1]
	$Data = $rData[3]
	$aParams = StringSplit($rData[2], Chr(31), 1)
	; ---
	Return 1
EndFunc

#cs
Function: _TCP_MakeCmd
	Create a packet to be sent over TCP, can have
	
	- A command name
	- A variable number of parameters
	- Some Data

Syntax:
	>_TCP_MakeCmd($sCmd, $aParams, $Data)

Parameters:
	$sCmd - Command name
	$aParams - Eiter an 0-Based array containing the parameters, or a string with the parameters
				delimited by Chr(31)
	$Data - The data of the packet, string, binary string...

Return:
	Succes - The packet
#ce
Func _TCP_MakeCmd($sCmd, $aParams, $Data)
	If IsArray($aParams) Then
		Local $str = ""
		For $elem In $aParams
			$str &= $elem & Chr(31)
		Next
		$aParams = StringTrimRight($str, 1)
	EndIf
	; ---
	Return $sCmd & Chr(29) & $aParams & Chr(29) & $Data
EndFunc

