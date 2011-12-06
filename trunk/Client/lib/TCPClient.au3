#cs
File: TCPClient
	This UDF contains function for simply handling a TCP Client.

Example:
	This script is an example of using this UDF, it's a very basic TCP Chat client. You can use it with the 
	TCP Server example.
	
	(start code)
	;----------------------------------------------------------------------------
	;
	; AutoIt Version: 3.3.6.1
	; Author:         Matwachich
	;
	; Script Function:
	;	
	;
	;----------------------------------------------------------------------------
	#NoTrayIcon

	#include <GuiEdit.au3>
	#include "TCPClient.au3"

	TCPStartup()

	#include <ButtonConstants.au3>
	#include <EditConstants.au3>
	#include <GUIConstantsEx.au3>
	#include <WindowsConstants.au3>

	; On demande un nom d'utilisateur
	; Wee need a user name
	Do
		$__NickName = InputBox("Chat", "Entrez votre pseudo")
		If @error Then Exit
	Until $__NickName

	#Region ### START Koda GUI section ### Form=
	$GUI = GUICreate("Chat", 378, 256, 384, 171)
	$Edit = GUICtrlCreateEdit("", 6, 6, 365, 215, BitOR($ES_AUTOVSCROLL,$ES_READONLY,$ES_WANTRETURN,$WS_VSCROLL))
	$Input = GUICtrlCreateInput("", 6, 228, 283, 21)
	$Button1 = GUICtrlCreateButton("Envoyer", 294, 228, 75, 21)
	Global $accels[1][2] = [["{enter}", $Button1]]
	GuiSetAccelerators($accels)
	$accels = 0
	GUISetState(@SW_SHOW)
	#EndRegion ### END Koda GUI section ###

	Global $tmp, $connTimer = TimerInit()

	; On créer un client et on lui assigne des fonction callback
	; Client creation, and callbacks functions assigning
	Global $Client = _TCPClient_Create(@IPAddress1, 53698, "motdepassedecryptagedesdonneessupersecret")
	_TCPClient_SetCallbacks($Client, "_TCP_Recv")

	; Boucle principale
	; Main loop
	While 1
		Switch GUIGetMsg()
			; Avant de quitter, on detruit le client
			; Befor exit, we destroy the client
			Case $GUI_EVENT_CLOSE
				_TCPClient_Destroy($Client)
				TCPShutdown()
				Exit
			; ---
			; Envoi d'un message, seulement si le Input contient quelque chose
			; Sending message, only if there is something in the Input
			Case $Button1
				$tmp = GuiCtrlRead($Input)
				If $tmp Then
					_TCPClient_Send($Client, $tmp)
					GuiCtrlSetData($Input, "")
				EndIf
			; ---
		EndSwitch
		; ---
		; Si le client est déconnecté, on essay de se connecter 1 fois / seconde
		; If the client is disconnected, then we indefinitly try to connect once per second
		If Not _TCPClient_IsConnected($Client) Then
			If TimerDiff($connTimer) >= 1000 Then
				_TCPClient_Connect($Client)
				$connTimer = TimerInit()
			EndIf
		EndIf
		; ---
		; Fonction de traitement
		; Processing function
		_TCPClient_Process()
	WEnd

	; Fonction appelée à la reception d'un message depuis le serveur
	; Function called when a message is received from the server
	Func _TCP_Recv($iClient, $Data)
		; Cette ligne ne sert à rien puisque nous n'avons qu'un seul client dans le script, mais si nous
		; en avion plusieurs, elle permetterai si tous les clients avait la même fonction callback de réception,
		; de savoir de quel client émane le message reçu
		; This line isn't very usefull in our example, but it would be usefull in a script containing many clients
		; in order to (if all the client had the same callback function) know which client is concerned by the event
		If $iClient <> $Client Then Return
		; ---
		; Si le message reçu est une requète d'identification, alors on s'identify au pres du serveur
		; If the message received is an identification request, then we identify ourself to the server
		If $Data = "#IDENTIFY#" Then
			_TCPClient_Send($iClient, "#NAME#" & $__NickName)
			Return
		EndIf
		; ---
		; Si non, ça veut dir que c'est un simple message, alors on l'affiche de le Edit
		; Else, it's a simple chat message, so we display it in the Edit
		Local $read = GuiCtrlRead($Edit)
		GuiCtrlSetData($Edit, $read & $Data & @CRLF)
		_GUICtrlEdit_LineScroll($Edit, 0, _GUICtrlEdit_GetLineCount($Edit))
	EndFunc
	(end)
#ce

#Include-Once
#include <Crypt.au3>
#include <String.au3>
#include "zlib.au3" ; Comment this line and ignore compile errors if you don't use compression

; Modify this as your needs
Global Const $__TCPClient_MaxClientsPerScript = 5

; ##############################################################
; Internals, do not modify!
Global Enum $__TCPc_IP, $__TCPc_PORT, $__TCPc_TIMER, $__TCPc_TIMERIDLE, $__TCPc_TIMEOUT, $__TCPc_HKEY, $__TCPc_COMPLVL, $__TCPc_HSOCKET, $__TCPc_BUFFER, _
			$__TCPc_CB_LOST, $__TCPc_CB_RECV, $__TCPc_CB_RECEIVING, $__TCPc_CB_TIMEDOUT, $__TCPc_SLOTSTAT

Global $__TCPClient_Clients[$__TCPClient_MaxClientsPerScript + 1][14] = [[$__TCPClient_MaxClientsPerScript, ""]] ; Array containing all clients
__TCPClient_InitClientsArray()

; ##############################################################
; NameSpace: Creation/Destruction, Connect/Disconnect

#cs
Function: _TCPClient_Create
	Create a TCP Client

Syntax:
	>_TCPClient_Create($sIP, $iPort, $sCryPwd = "", $iTimeOut = 60)

Parameters:
	$sIP - Server's IP Address
	$iPort - Server's listening port
	$sCryPwd - If specified, then the exchanged data between server and clients will be encrypted (must be the same as the client)
	$iCompressLvl - ZLib compression level, 0 - No compression, 9 - Max compression
	$iTimeOut - Server Time-out (seconds)

Return:
	Succes - A Client Handle
	Failed - 0 and set @error to 1 if maximum clients number is already reached, in this case, 
	you must destroy some other client to create a new one (see <_TCPClient_Destroy>).
#ce
Func _TCPClient_Create($sIP, $iPort, $sCryPwd = "", $iCompressLvl = 0, $iTimeOut = 60)
	Local $iClient = __TCPClient_GetFreeClientSlot()
	If Not $iClient Then Return SetError(1, 0, 0)
	; ---
	If $iTimeOut <= 0 Then $iTimeOut = 5
	; ---
	$__TCPClient_Clients[$iClient][$__TCPc_IP] = $sIP
	$__TCPClient_Clients[$iClient][$__TCPc_PORT] = $iPort
	$__TCPClient_Clients[$iClient][$__TCPc_COMPLVL] = $iCompressLvl
	$__TCPClient_Clients[$iClient][$__TCPc_TIMEOUT] = $iTimeOut * 1000
	; ---
	If $sCryPwd Then
		_Crypt_Startup()
		$__TCPClient_Clients[$iClient][$__TCPc_HKEY] = _Crypt_DeriveKey($sCryPwd, $CALG_RC4)
	EndIf
	; ---
	__TCPClient_SetSlot_NotFree($iClient)
	; ---
	Return $iClient
EndFunc

#cs
Function: _TCPClient_Destroy
	Destroy a client

Syntax:
	>_TCPClient_Destroy($iClient)

Parameters:
	$iClient - Client Handle (Returned by <_TCPClient_Create>)

Return:
	Sucess - 1
	Failed - 0 and set @error to -1 if the Client Handle isn't valid

Remark:
	If the client was connect, then the <_TCPClient_Disconnect> function is called befor destroying the client.
	Consequently, the Lost Connexion Callback function will be called for this client.
#ce
Func _TCPClient_Destroy($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If _TCPClient_IsConnected($iClient) Then _TCPClient_Disconnect($iClient)
	; ---
	If $__TCPClient_Clients[$iClient][$__TCPc_HKEY] Then
		_Crypt_DestroyKey($__TCPClient_Clients[$iClient][$__TCPc_HKEY])
		_Crypt_Shutdown()
	EndIf
	; ---
	__TCPClient_ResetClientSlot($iClient)
	__TCPClient_SetSlot_Free($iClient)
	Return 1
EndFunc

#cs
Function: _TCPClient_Connect
	Order a Client to connect

Syntax:
	>_TCPClient_Connect($iClient)

Parameters:
	$iClient - Client Handle (Returned by <_TCPClient_Create>)

Return:
	Succes - 1
	Failed - 0 (Check Server IP, and Port)
#ce
Func _TCPClient_Connect($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If _TCPClient_IsConnected($iClient) Then _TCPClient_Disconnect($iClient)
	; ---
	Local $ret = TCPConnect($__TCPClient_Clients[$iClient][$__TCPc_IP], $__TCPClient_Clients[$iClient][$__TCPc_PORT])
	If $ret > 0 Then
		$__TCPClient_Clients[$iClient][$__TCPc_HSOCKET] = $ret
		$__TCPClient_Clients[$iClient][$__TCPc_TIMERIDLE] = TimerInit()
		Return 1
	Else
		Return 0
	EndIf
EndFunc

#cs
Function: _TCPClient_Disconnect
	Order a client to disconnect

Syntax:
	>_TCPClient_Disconnect($iClient)

Parameters:
	$iClient - Client Handle (Returned by <_TCPClient_Create>)

Return:
	Sucess - 1
	Failed - 0 and set @error to
	
	- -1 if the Client Handle isn't valid
	- 1 if the client isn't connected to any server
#ce
Func _TCPClient_Disconnect($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	If Not _TCPClient_IsConnected($iClient) Then Return SetError(1, 0, 0)
	; ---
	If TCPCloseSocket($__TCPClient_Clients[$iClient][$__TCPc_HSOCKET]) Then
		$__TCPClient_Clients[$iClient][$__TCPc_HSOCKET] = -1
		Return 1
	Else
		Return 0
	EndIf
EndFunc

#cs
Function: _TCPClient_IsConnected
	Check if a client is connected

Syntax:
	>_TCPClient_IsConnected($iClient)

Parameters:
	$iClient - Client Handle (Returned by <_TCPClient_Create>)

Return:
	Succes - 1 if the client is connected, 0 if it isn't connect
	Failed - 0 and set @error to -1 if the Client Handle isn't valid
#ce
Func _TCPClient_IsConnected($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If $__TCPClient_Clients[$iClient][$__TCPc_HSOCKET] <> -1 Then
		Return 1
	Else
		Return 0
	EndIf
EndFunc

; ##############################################################
; NameSpace: Configuration

#cs
Function: _TCPClient_Config
	Set client's configuration

Syntax:
	>_TCPClient_Config($iClient, $sIP = Default, $iPort = Default, $iTimeOut = Default)

Parameters:
	$iClient - Client Handle (Returned by <Creation/Destruction, Connect/Disconnect._TCPClient_Create>)
	$sIP - Server's IP Address
	$iPort - Server's listening port
	$iTimeOut - Server Time-out (seconds)

Returns:
	Succes - 1
	Failed - 0 and set @error to -1 if the Client Handle isn't valid
#ce
Func _TCPClient_Config($iClient, $sIP = Default, $iPort = Default, $iTimeOut = Default)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If $sIP <> Default 			Then $__TCPClient_Clients[$iClient][$__TCPc_IP] = $sIP
	If $iPort <> Default 		Then $__TCPClient_Clients[$iClient][$__TCPc_PORT] = $iPort
	If $iTimeOut <> Default 	Then $__TCPClient_Clients[$iClient][$__TCPc_TIMEOUT] = $iTimeOut
	; ---
	Return 1
EndFunc

#cs
Function: _TCPClient_SetCallbacks
	Set the callback functions that will be called when an event occurs

Syntax:
	>_TCPClient_SetCallbacks($iClient, $sCB_Recv = Default, $sCB_Receiving = Default, $sCB_LostConnection = Default, $sCB_TimedOut = Default)

Parameters:
	$iClient - Client Handle (Returned by <Creation/Destruction, Connect/Disconnect._TCPClient_Create>)
	$sCB_Recv - Function called when data is received from the server
	$sCB_Receiving - Function called when being receiving data from the server
	$sCB_LostConnection - Function called when disconnecting from the server
	$sCB_TimedOut - Function called when the server is timed out

Returns:
	Succes - 1
	Failed - 0 and set @error to -1 if the Client Handle isn't valid

Remark:
	The syntax for each callback function is:
	- *$sCB_Recv* _Function($iClient, $Data)
	- *$sCB_Receiving* & *sCB_TimedOut* _Function($iClient, $iBufferLenght)
	- *$sCB_LostConnection* _Function($iClient)
	
	$iClient - Client Handle concerned by the event
	$Data - Data received, either String or Binary (is it was sent)
	$iBufferLenght - Lenght of the buffer at the moment whet the function is called
	
	When the server is timed out, the buffer will be flushed, so $iBufferLenght corresponds to the amount of lost data.
#ce
Func _TCPClient_SetCallbacks($iClient, $sCB_Recv = Default, $sCB_Receiving = Default, $sCB_LostConnection = Default, $sCB_TimedOut = Default)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If $sCB_Recv <> Default 			Then $__TCPClient_Clients[$iClient][$__TCPc_CB_RECV] = $sCB_Recv
	If $sCB_Receiving <> Default 		Then $__TCPClient_Clients[$iClient][$__TCPc_CB_RECEIVING] = $sCB_Receiving
	If $sCB_LostConnection <> Default 	Then $__TCPClient_Clients[$iClient][$__TCPc_CB_LOST] = $sCB_LostConnection
	If $sCB_TimedOut <> Default 		Then $__TCPClient_Clients[$iClient][$__TCPc_CB_TIMEDOUT] = $sCB_TimedOut
	; ---
	Return 1
EndFunc

; ##############################################################
; NameSpace: Communication with server

#cs
Function: _TCPClient_Send
	Send data to the server

Syntax:
	>_TCPClient_Send($iClient, $Data)

Parameters:
	$iClient - Client Handle (Returned by <Creation/Destruction, Connect/Disconnect._TCPClient_Create>)
	$Data - Data we want to send (See remark)

Returns:
	Succes - Returns number of bytes sent.
	Failed - 0 and set @error to
	
	- -1 if the Client Handle isn't valid
	- 1 if the client isn't connected to any server
	- Or windows API WSAGetError return value (see <http://msdn.microsoft.com/en-us/library/ms740668.aspx>)

Remark:
	About *$Data* parameter, anything other than Binary data will be sent as string, and received as a string. Binary data
	will be sent as it is, and received as binary too. 
#ce
Func _TCPClient_Send($iClient, $Data)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	If Not _TCPClient_IsConnected($iClient) Then Return SetError(1, 0, 0)
	; ---
	Return TCPSend($__TCPClient_Clients[$iClient][$__TCPc_HSOCKET], Chr(2) & __TCPClient_Cry($iClient, $Data) & Chr(3))
EndFunc

#cs
Function: _TCPClient_ServerIdleTime
	Return the idle time of the server wich the specified client is connected to (since last data receive from that server)

Syntax:
	>_TCPClient_ServerIdleTime($iClient)

Parameters:
	$iClient - Client Handle (Returned by <Creation/Destruction, Connect/Disconnect._TCPClient_Create>)

Return:
	Succes - Returns the idle time (in ms)
	Failed - -1 and set @error to
	
	- -1 if the Client Handle isn't valid
	- 1 if the client isn't connected to any server
#ce
Func _TCPClient_ServerIdleTime($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, -1)
	If Not _TCPClient_IsConnected($iClient) Then Return SetError(1, 0, -1)
	; ---
	Return TimerDiff($__TCPClient_Clients[$iClient][$__TCPc_TIMERIDLE])
EndFunc

#cs
Function: _TCPClient_GetBufferLen
	Return the current specified client's buffer lenght

Syntax:
	>_TCPClient_GetBufferLen($iClient)

Parameters:
	$iClient - Client Handle (Returned by <Creation/Destruction, Connect/Disconnect._TCPClient_Create>)

Return:
	Succes - Current buffer lenght (BinaryLen)
	Failed - -1 and set @error to
	
	- -1 if the Client Handle isn't valid
	- 1 if the client isn't connected to any server
#ce
Func _TCPClient_GetBufferLen($iClient)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, -1)
	If Not _TCPClient_IsConnected($iClient) Then Return SetError(1, 0, -1)
	; ---
	Return BinaryLen($__TCPClient_Clients[$iClient][$__TCPc_BUFFER])
EndFunc

; ##############################################################
; NameSpace: Processing

#cs
Function: _TCPClient_Process
	This function makes all clients work, all data is processed here, and all callbacks are called from here

Syntax:
	>_TCPClient_Process()

Parameters:
	None

Returns:
	1
#ce
Func _TCPClient_Process()
	For $i = 1 To $__TCPClient_MaxClientsPerScript
		If _TCPClient_IsConnected($i) Then
			__TCPClient_Process($i)
		EndIf
	Next
	; ---
	Return 1
EndFunc

Func __TCPClient_Process($iClient)
	Local $recv, $tmp
	; ---
	$recv = TCPRecv($__TCPClient_Clients[$iClient][$__TCPc_HSOCKET], 4096)
	; ---
	; Check disconnection
	If @error Then
		_TCPClient_Disconnect($iClient)
		; ---
		If $__TCPClient_Clients[$iClient][$__TCPc_CB_LOST] Then _
			Call($__TCPClient_Clients[$iClient][$__TCPc_CB_LOST], $iClient)
	EndIf
	; ---
	; Check receiving
	If $recv Then
		$__TCPClient_Clients[$iClient][$__TCPc_BUFFER] &= $recv
		$__TCPClient_Clients[$iClient][$__TCPc_TIMER] = TimerInit()
		$__TCPClient_Clients[$iClient][$__TCPc_TIMERIDLE] = TimerInit()
		; ---
		If $__TCPClient_Clients[$iClient][$__TCPc_CB_RECEIVING] Then _
			Call($__TCPClient_Clients[$iClient][$__TCPc_CB_RECEIVING], $iClient, BinaryLen($__TCPClient_Clients[$iClient][$__TCPc_BUFFER]))
	EndIf
	; ---
	; Check timeout
	If $__TCPClient_Clients[$iClient][$__TCPc_BUFFER] Then
		If TimerDiff($__TCPClient_Clients[$iClient][$__TCPc_TIMER]) >= $__TCPClient_Clients[$iClient][$__TCPc_TIMEOUT] Then
			If $__TCPClient_Clients[$iClient][$__TCPc_CB_TIMEDOUT] Then _
				Call($__TCPClient_Clients[$iClient][$__TCPc_CB_TIMEDOUT], $iClient, BinaryLen($__TCPClient_Clients[$iClient][$__TCPc_BUFFER]))
			; ---
			$__TCPClient_Clients[$iClient][$__TCPc_BUFFER] = ""
		EndIf
	EndIf
	; ---
	; Check buffer ok
	$tmp = __TCPClient_CheckBuffer($iClient)
	If IsArray($tmp) Then
		For $elem In $tmp
			If $__TCPClient_Clients[$iClient][$__TCPc_CB_RECV] Then _
				Call($__TCPClient_Clients[$iClient][$__TCPc_CB_RECV], $iClient, $elem)
		Next
		; ---
		$__TCPClient_Clients[$iClient][$__TCPc_BUFFER] = ""
	EndIf
EndFunc

Func __TCPClient_CheckBuffer($iClient)
	If $__TCPClient_Clients[$iClient][$__TCPc_BUFFER] = "" Then Return 0
	; ---
	$bet = _StringBetween($__TCPClient_Clients[$iClient][$__TCPc_BUFFER], Chr(2), Chr(3))
	If IsArray($bet) Then
		For $i = 0 To UBound($bet) - 1
			$bet[$i] = __TCPClient_dCry($iClient, $bet[$i])
		Next
		Return $bet
	Else
		Return 0
	EndIf
EndFunc

; ##############################################################
; Internals

Func __TCPClient_GetFreeClientSlot()
	For $i = 1 To $__TCPClient_MaxClientsPerScript
		If __TCPClient_Slot_IsFree($i) Then Return $i
	Next
	; ---
	Return 0
EndFunc

Func __TCPClient_InitClientsArray()
	For $i = 1 To $__TCPClient_MaxClientsPerScript
		__TCPClient_ResetClientSlot($i)
	Next
EndFunc

Func __TCPClient_ResetClientSlot($i)
	$__TCPClient_Clients[$i][0] = ""	; ip
	$__TCPClient_Clients[$i][1] = 0		; Port
	$__TCPClient_Clients[$i][2] = 0		; timer timeout
	$__TCPClient_Clients[$i][3] = 0		; timer idle
	$__TCPClient_Clients[$i][4] = 0		; time-out
	$__TCPClient_Clients[$i][5] = 0		; hKey
	$__TCPClient_Clients[$i][6] = 0		; Compression lvl
	$__TCPClient_Clients[$i][7] = -1	; hSocket
	$__TCPClient_Clients[$i][8] = ""	; Buffer
	$__TCPClient_Clients[$i][9] = ""	; CB_Lost
	$__TCPClient_Clients[$i][10] = ""	; CB_Recv
	$__TCPClient_Clients[$i][11] = ""	; CB_Receiving
	$__TCPClient_Clients[$i][12] = ""	; CB_Timed-out
	$__TCPClient_Clients[$i][13] = 1	; Is slot free
EndFunc

Func __TCPClient_SetSlot_Free($iClient)
	$__TCPClient_Clients[$iClient][$__TCPc_SLOTSTAT] = 1
EndFunc

Func __TCPClient_SetSlot_NotFree($iClient)
	$__TCPClient_Clients[$iClient][$__TCPc_SLOTSTAT] = 0
EndFunc

Func __TCPClient_Slot_IsFree($iClient)
	Return $__TCPClient_Clients[$iClient][$__TCPc_SLOTSTAT]
EndFunc

Func __TCPClient_Cry($iClient, $Data)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If Not $__TCPClient_Clients[$iClient][$__TCPc_HKEY] Then Return $Data
	; ---
	Local $bin = 1
	If Not IsBinary($Data) Then
		$bin = 0
		$Data = StringToBinary($Data, 4)
	EndIf
	; ---
	$Data = _Crypt_EncryptData($Data, $__TCPClient_Clients[$iClient][$__TCPc_HKEY], $CALG_USERKEY)
	; ---
	If $__TCPClient_Clients[$iClient][$__TCPc_COMPLVL] > 0 Then _
		$Data = _ZLIB_Compress($Data, $__TCPClient_Clients[$iClient][$__TCPc_COMPLVL])
	; ---
	If Not $bin Then $Data = StringTrimLeft($Data, 2)
	; ---
	Return $Data
EndFunc

Func __TCPClient_dCry($iClient, $Data)
	If Not __TCPClient_IsHandleClient($iClient) Then Return SetError(-1, 0, 0)
	; ---
	If Not $__TCPClient_Clients[$iClient][$__TCPc_HKEY] Then Return $Data
	; ---
	Local $bin = 0
	If StringLeft($Data, 2) = "0x" Then
		$bin = 1
		$Data = Binary($Data)
	Else
		$Data = Binary("0x" & $Data)
	EndIf
	; ---
	If $__TCPClient_Clients[$iClient][$__TCPc_COMPLVL] > 0 Then _
		$Data = _ZLIB_Uncompress($Data)
	; ---
	$Data = _Crypt_DecryptData($Data, $__TCPClient_Clients[$iClient][$__TCPc_HKEY], $CALG_USERKEY)
	If Not $bin Then $Data = BinaryToString($Data, 4)
	; ---
	Return $Data
EndFunc

Func __TCPClient_IsHandleClient($iClient)
	If $iClient <= 0 Or $iClient > $__TCPClient_MaxClientsPerScript Then Return 0
	Return 1
EndFunc
