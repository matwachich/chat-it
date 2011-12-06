#cs
File: TCPServer
	This UDF contains function for handling a *multi-clients, encrypted* TCP Server.

Example:
	This script is an example of using this UDF, it's a very basic TCP Chat server. You can use it with the 
	TCP Client example.
	
	(start code)
	;----------------------------------------------------------------------------
	;
	; AutoIt Version: 3.3.6.1
	; Author:         Matwachich
	;
	; Script Function:
	;	TCP Chat Server example
	;
	;----------------------------------------------------------------------------
	#NoTrayIcon

	#include "TCPServer.au3"

	TCPStartup()

	; Créer un serveur TCP
	; Create the server
	_TCPServer_Create(@IPAddress1, 53698, 50, 1, "motdepassedecryptagedesdonneessupersecret")

	; Lui assigner ses fonctions callback en fonction des evenements
	; Assign it callback functions, that will be called when events occurs
	_TCPServer_SetCallbacks("_TCP_New", "_TCP_Lost", "_TCP_Recv")

	; On démare le serveur
	; Start the server
	If Not _TCPServer_Start() Then Exit MsgBox(16, "Erreur", "Impossible de démarer le serveur!")

	; Boucle principale, où est appelée la fonction de traitement
	; Main loop, where the processing function is called
	Global $run = 1
	While $run
		_TCPServer_Process()
	Wend

	; A la sortie de la boucle, on détruit le serveur
	; Destroy the server and free ressources
	_TCPServer_Destroy()
	TCPShutdown()

	; ##############################################################

	; Fonction appelée lors de la connexion d'un nouveau client
	; elle envoi à ce client une requète d'identification
	; Function called when a new client connects
	; it sends to the new connected client an identify request
	Func _TCP_New($iSocket, $sIP)
		_TCPServer_Send($iSocket, "#IDENTIFY#")
		; ---
		ConsoleWrite("New Client!" & @CRLF)
	EndFunc

	; Fonction appelée lors de la deconnexion d'un client
	; elle envoi à tous le monde la notification de deconnexion
	; Function called when a client disconnects
	; it sends to other clients a disconnect notification
	Func _TCP_Lost($iSocket, $sIP)
		Local $nick = _TCPServer_ClientPropertyGet($iSocket, 0)
		If $nick Then _TCPServer_Broadcast($nick & " Disconnected!")
		; ---
		ConsoleWrite("Lost Client!" & @CRLF)
	EndFunc

	; Fonction appelée lors de la réception d'un message d'un client
	; Function called when a message is received from a client
	Func _TCP_Recv($iSocket, $sIP, $Data)
		; Si le message est #CLOSE#:
		;	Notifie que quelqu'un a demandé la fermeture du serveur
		;	Et met la variable $run à 0
		; If the message is #CLOSE#:
		;	We notify all clients that somebody requested closing the server
		;	We set $run to 0
		If $Data = "#CLOSE#" Then
			Local $nick = _TCPServer_ClientPropertyGet($iSocket, 0)
			If $nick Then
				_TCPServer_Broadcast($nick & " closed the server...")
				$run = 0
			EndIf
		; ---
		; Si le message commence par #NAME#: Ca veut dir que ce client s'identifie
		;	On extrait son nom du message (avec le StringTrimLeft)
		;	On l'assigne à la propriété N°0 de sa socket
		;	On notifie de la connexion d'une nouvelle personne dans le chat
		; If the message starts with #NAME#: It means that it's an identification
		;	We extract the name from the received data (With StringTrimleft)
		;	We assign it to the client's property N°0
		;	We notify everybody that a new client is connected
		ElseIf StringLeft($Data, 6) = "#NAME#" Then
			Local $nick = StringTrimLeft($Data, 6)
			_TCPServer_ClientPropertySet($iSocket, 0, $nick)
			_TCPServer_Broadcast($nick & " Connected!")
		; ---
		; Si non, ça veut dir que c'est un simple message, alors on le renvoi
		; à tous le monde, en y préfixant le nom de la personne (contenu dans la
		; propriété N°0 de la socket)
		; Else, it's a simple message, so we broadcast it to every body, after adding
		; to it as a prefix, the name of the client (contained in the client's property N°0)
		Else
			Local $nick = _TCPServer_ClientPropertyGet($iSocket, 0)
			If $nick Then _TCPServer_Broadcast("[" & $nick & "] " & $Data)
		EndIf
	EndFunc

	(end)
#ce

#Include-Once
#include <Crypt.au3>
#include <String.au3>
#include "zlib.au3" ; Comment this line and ignore compile errors if you don't use compression

; ##############################################################
; Globals: Server configuration vars (Do not modify!)

Global $__TCPServer_Sockets[1][5] = [[0, "", "", 0, 0]] ; socket, ip, buffer, timeout timer, idle timer
Global $__TCPServer_ClientProperties[1][2] = [[0,0]]

Global $__TCPSrv_Info_IP = -1
Global $__TCPSrv_Info_PORT = 0
Global $__TCPSrv_Info_MAXCLIENTS = 0
Global $__TCPSrv_Info_CLIENTPROP = 0
Global $__TCPSrv_Info_CRYKEY = 0
Global $__TCPSrv_Info_COMPRESSION = 0
Global $__TCPSrv_Info_SOCKET = -1
Global $__TCPSrv_Info_TIMEOUT = 0
Global $__TCPSrv_Info_CB_NEW = ""
Global $__TCPSrv_Info_CB_LOST = ""
Global $__TCPSrv_Info_CB_RECV = ""
Global $__TCPSrv_Info_CB_RECEIVING = ""
Global $__TCPSrv_Info_CB_TIMEDOUT = ""

; ##############################################################
; NameSpace: Creation/Destruction, Start/Stop

#cs
Function: _TCPServer_Create
	Create a TCP server

Syntax:
	>_TCPServer_Create($sIP, $iPort, $iMaxClients = 50, $iClientPropertiesNbr = 0, $sPwd = "", $iTimeOut = 60)

Parameters:
	$sIP - IP address to listen
	$iPort - Port number to listen
	$iMaxClients - Max number of simultaneous connected clients
	$iClientPropertiesNbr - Defines the number of properies that we can assigne for each client
	$sPwd - If specified, then the exchanged data between server and clients will be encrypted (must be the same as the client)
	$iCompressLvl - ZLib compression level, 0 - No compression, 9 - Max compression
	$iTimeOut - Client time-out (Seconds)

Return:
	1

Remark:
	Call this function *ONLY ONE TIME* in a script
#ce
Func _TCPServer_Create($sIP, $iPort, $iMaxClients = 50, $iClientPropertiesNbr = 0, $sPwd = "", $iCompressLvl = 0, $iTimeOut = 60)
	If $sPwd <> "" Then
		_Crypt_Startup()
		$sPwd = _Crypt_DeriveKey($sPwd, $CALG_RC4)
	EndIf
	; ---
	$__TCPSrv_Info_CLIENTPROP = $iClientPropertiesNbr
	$__TCPSrv_Info_COMPRESSION = $iCompressLvl
	; ---
	If $iTimeOut <= 0 Then $iTimeOut = 5
	; ---
	$__TCPSrv_Info_IP = $sIP
	$__TCPSrv_Info_PORT = $iPort
	$__TCPSrv_Info_MAXCLIENTS = $iMaxClients
	$__TCPSrv_Info_CRYKEY = $sPwd
	$__TCPSrv_Info_SOCKET = -1
	$__TCPSrv_Info_TIMEOUT = $iTimeOut * 1000
	; ---
	Return 1
EndFunc

#cs
Function: _TCPServer_Start
	Starts the server

Syntax:
	>_TCPServer_Start()

Parameters:
	None

Return:
	Succes - 1
	Failed - 0 - Check IP (is it valid), and Port (is it free)
#ce
Func _TCPServer_Start()
	Local $hSocket
	; ---
	$hSocket = TCPListen($__TCPSrv_Info_IP, $__TCPSrv_Info_PORT)
	If $hSocket > 0 Then
		__TCPServer_InitPropertiesArray()
		__TCPServer_InitSocketsArray()
		$__TCPSrv_Info_SOCKET = $hSocket
		Return 1
	Else
		Return 0
	EndIf
EndFunc

#cs
Function: _TCPServer_Stop
	Stops the server

Syntax:
	>_TCPServer_Stop()

Parameters:
	None

Return:
	Succes - 1
	Failed - 0
#ce
Func _TCPServer_Stop()
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	_TCPServer_DisconnectAll()
	_TCPServer_Process() ; so that the disconnection callback will be called befor closing the server
	; ---
	Local $ret = TCPCloseSocket($__TCPSrv_Info_SOCKET)
	Local $err = @error
	; ---
	If $ret And Not @error Then
		$__TCPSrv_Info_SOCKET = -1
		Return 1
	Else
		Return 0
	EndIf
EndFunc

#cs
Function: _TCPServer_IsStarted
	Return server status

Syntax:
	>

Parameters:
	None

Return:
	1 - Server is listening (started)
	0 - Server is shutdown
#ce
Func _TCPServer_IsStarted()
	If $__TCPSrv_Info_SOCKET = -1 Then
		Return 0
	Else
		Return 1
	EndIf
EndFunc

#cs
Function: _TCPServer_Destroy
	Destroy the server and free ressources

Syntax:
	>_TCPServer_Destroy()

Parameters:
	None

Return:
	1
#ce
Func _TCPServer_Destroy()
	_TCPServer_Stop()
	; ---
	If $__TCPSrv_Info_CRYKEY Then
		_Crypt_DestroyKey($__TCPSrv_Info_CRYKEY)
		_Crypt_Shutdown()
	EndIf
	; ---
	$__TCPSrv_Info_IP = -1
	$__TCPSrv_Info_PORT = 0
	$__TCPSrv_Info_MAXCLIENTS = 0
	$__TCPSrv_Info_CLIENTPROP = 0
	$__TCPSrv_Info_CRYKEY = 0
	$__TCPSrv_Info_SOCKET = -1
	$__TCPSrv_Info_TIMEOUT = 0
	$__TCPSrv_Info_CB_NEW = ""
	$__TCPSrv_Info_CB_LOST = ""
	$__TCPSrv_Info_CB_RECV = ""
	$__TCPSrv_Info_CB_RECEIVING = ""
	$__TCPSrv_Info_CB_TIMEDOUT = ""
	; ---
	Return 1
EndFunc

; ##############################################################
; NameSpace: Configuration

#cs
Function: _TCPServer_Config
	Set server's parameters

Syntax:
	>_TCPServer_Config($sIP = Default, $iPort = Default, $iTimeOut = Default, $iMaxClients = Default, $iClientPropertiesNbr = Default)

Parameters:
	$sIP (Optional) - IP address to listen
	$iPort (Optional) - Port to listen
	$iTimeOut (Optional) - Client time-out (seconds)
	$iMaxClients (Optional) - Max number of simultaneous connected clients
	$iClientPropertiesNbr (Optional) - Defines the number of properies that we can assigne for each client

Return:
	1

Remarks:
	- Any parameter that is passed the Default keyword will not be modified
	- The new parameters are took in consideration only if the server is stoped (<_TCPServer_Stop>) and restarted (<_TCPServer_Start>)
#ce
Func _TCPServer_Config($sIP = Default, $iPort = Default, $iTimeOut = Default, $iMaxClients = Default, $iClientPropertiesNbr = Default)
	If $sIP <> Default 						Then $__TCPSrv_Info_IP = $sIP
	If $iPort <> Default 					Then $__TCPSrv_Info_PORT = $iPort
	If $iTimeOut <> Default 				Then $__TCPSrv_Info_TIMEOUT = $iTimeOut
	If $iMaxClients <> Default 				Then $__TCPSrv_Info_MAXCLIENTS = $iMaxClients
	If $iClientPropertiesNbr <> Default 	Then $__TCPSrv_Info_CLIENTPROP = $iClientPropertiesNbr
	; ---
	Return 1
EndFunc

#cs
Function: _TCPServer_SetCallbacks
	Set the callback functions that will be called when an event occurs

Syntax:
	>_TCPServer_SetCallbacks($sCB_NewClient = Default, $sCB_LostClient = Default, $sCB_Recv = Default, $sCB_Receiving = Default, $sCB_TimedOut = Default)

Parameters:
	$sCB_NewClient (Optional) - Function called when a client connects to the server
	$sCB_LostClient (Optional) - Function called when a client disconnects from the server
	$sCB_Recv (Optional) - Function called when some data is received from a client
	$sCB_Receiving (Optional) - Function called when a client is sending some data
	$sCB_TimedOut (Optional) - Function called when a client is timed out being sending

Return:
	1

Remark:
	The syntax for each callback function is:
	- *$sCB_NewClient* & *$sCB_LostClient* _Function($iSocket, $sIP)
	- *$sCB_Recv* _Function($iSocket, $sIP, $Data)
	- *$sCB_Receiving* & *$sCB_TimedOut* _Function($iSocket, $sIP, $iBufferLenght)
	
	$iSocket - The socket ID of the client that is concerned by the event
	$sIP - the IP Address of the client
	$Data - The data received, either String or Binary (is it was sent)
	$iBufferLenght - Lenght of the buffer at the moment whet the function is called
	
	When a client is timed out, it's buffer will be flushed, so $iBufferLenght corresponds to the amount of lost data.
	
	*WARNING\:* In Lost Client callback function, if calling <_TCPServer_SocketList> then the disconnected client's Socket ID will
	be in the list! This is due to the internal mechanisms of the Processing function.
	
	But after the Lost Client callback function, everything will become normal, and the disconnected socket will not
	be in the list.
#ce
Func _TCPServer_SetCallbacks($sCB_NewClient = Default, $sCB_LostClient = Default, $sCB_Recv = Default, $sCB_Receiving = Default, $sCB_TimedOut = Default)
	If $sCB_NewClient <> Default 	Then $__TCPSrv_Info_CB_NEW = 		$sCB_NewClient
	If $sCB_LostClient <> Default 	Then $__TCPSrv_Info_CB_LOST = 		$sCB_LostClient
	If $sCB_Recv <> Default 		Then $__TCPSrv_Info_CB_RECV = 		$sCB_Recv
	If $sCB_Receiving <> Default 	Then $__TCPSrv_Info_CB_RECEIVING = 	$sCB_Receiving
	If $sCB_TimedOut <> Default 	Then $__TCPSrv_Info_CB_TIMEDOUT = 	$sCB_TimedOut
	; ---
	Return 1
EndFunc

; ##############################################################
; NameSpace: Clients handling

#cs
Function: _TCPServer_Send
	Send data to a client

Syntax:
	>_TCPServer_Send($iSocket, $Data)

Parameters:
	$iSocket - Socket ID of the client
	$Data - Data we want to send (See remark)

Return:
	Succes - Returns number of bytes sent.
	Failed - 0 and set @error to windows API WSAGetError return value (see <http://msdn.microsoft.com/en-us/library/ms740668.aspx>)

Remark:
	About *$Data* parameter, anything other than Binary data will be sent as string, and received as a string. Binary data
	will be sent as it is, and received as binary too.
#ce
Func _TCPServer_Send($iSocket, $Data)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	Return TCPSend($__TCPServer_Sockets[$iSocket][0], Chr(2) & __TCPServer_Cry($Data) & Chr(3))
EndFunc

#cs
Function: _TCPServer_Broadcast
	Send data to all connected clients

Syntax:
	>_TCPServer_Broadcast($Data)

Parameters:
	$Data - Data we want to send (See remark in <_TCPServer_Send>)

Return:
	1
#ce
Func _TCPServer_Broadcast($Data)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	$Data = __TCPServer_Cry($Data)
	; ---
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] <> -1 Then
			TCPSend($__TCPServer_Sockets[$i][0], Chr(2) & $Data & Chr(3))
		EndIf
	Next
	; ---
	Return 1
EndFunc

#cs
Function: _TCPServer_Disconnect
	Disconnect a client

Syntax:
	>_TCPServer_Disconnect($iSocket)

Parameters:
	$iSocket - Socket ID of a client

Return:
	Succes - 1
	Failed - 0 and set @error to windows API WSAGetError return value (see <http://msdn.microsoft.com/en-us/library/ms740668.aspx>)
#ce
Func _TCPServer_Disconnect($iSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	Return TCPCloseSocket($__TCPServer_Sockets[$iSocket][0])
EndFunc

#cs
Function: _TCPServer_DisconnectAll
	Disconnect all clients

Syntax:
	>_TCPServer_DisconnectAll()

Parameters:
	None

Return:
	1
#ce
Func _TCPServer_DisconnectAll()
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] <> -1 Then
			TCPCloseSocket($__TCPServer_Sockets[$i][0])
		EndIf
	Next
	; ---
	Return 1
EndFunc

#cs
Function: _TCPServer_ClientIdleTime
	Return the idle time of a client (since last data receive from that client)

Syntax:
	>_TCPServer_ClientGetIdle($iSocket)

Parameters:
	$iSocket - Socket ID of a client

Return:
	Succes - Idle time (in ms)
	Failed - -1 and set @error to
	
	- -1 if the server isn't started
	- 1 if the Socket ID isn't valid

Remark:
	If no message has been received from the client, then the time since its connection is returned
#ce
Func _TCPServer_ClientIdleTime($iSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, -1)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, -1)
	; ---
	Return TimerDiff($__TCPServer_Sockets[$iSocket][4])
EndFunc

#cs
Function: _TCPServer_GetBufferLen
	Return the current buffer lenght of a client

Syntax:
	>_TCServer_GetBufferLen($iSocket)

Parameters:
	$iSocket - Socket ID

Return:
	Succes - Current buffer lenght (BinaryLen)
	Failed - -1 and set @error to
	
	- -1 if the server isn't started
	- 1 if the Socket ID isn't valid
#ce
Func _TCPServer_GetBufferLen($iSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, -1)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, -1)
	; ---
	Return BinaryLen($__TCPServer_Sockets[$iSocket][2])
EndFunc

#cs
Function: _TCPServer_SocketList
	Return a list off all connected Socket IDs and their respective IP addresses

Syntax:
	>_TCPServer_SocketList()

Parameters:
	None

Return:
	Succes - 2-D array with: - $array[0][0] = number of elements in the list (number of connected clients)
							 - $array[$i][0] = Socket ID
							 - $array[$i][1] = IP Address
	Failed - 0 and set @error to -1 if the server isn't started
#ce
Func _TCPServer_SocketList()
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	Local $ret[1][2] = [[0,""]]
	; ---
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] <> -1 Then
			ReDim $ret[$ret[0][0] + 2][2]
			$ret[$ret[0][0] + 1][0] = $i ; Corrected in 1.1.1
			$ret[$ret[0][0] + 1][1] = $__TCPServer_Sockets[$i][1]
			$ret[0][0] += 1
		EndIf
	Next
	; ---
	Return $ret
EndFunc

#cs
Function: _TCPServer_ClientCount
	Return the number of currently connected clients

Syntax:
	>_TCPServer_ClientCount()

Parameters:
	None

Return:
	Succes - Number of connected clients
	Failed - 0 and set @error to -1 if the server isn't started
#ce
Func _TCPServer_ClientCount()
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	Local $count = 0
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] <> -1 Then
			$count += 1
		EndIf
	Next
	; ---
	Return $count
EndFunc

; ##############################################################
; NameSpace: Various conversions

#cs
Function: _TCPServer_SocketID2IP
	Convert Socket ID to IP Address

Syntax:
	>_TCPServer_SocketID2IP($iSocket)

Parameters:
	$iSocket - Socket ID

Return:
	Sucess - 
	Failed - 0 and set @error to
	
	- -1 if the server isn't started
	- 1 if the Socket ID isn't valid
#ce
Func _TCPServer_SocketID2IP($iSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	Return $__TCPServer_Sockets[$iSocket][1]
EndFunc

#cs
Function: _TCPServer_IP2SocketID
	Convert an IP Address to Socket ID

Syntax:
	>_TCPServer_IP2SocketID($sIP)

Parameters:
	$sIP - IP Address

Return:
	Sucess - Socket ID
	Failed - 0 and set @error to
	
	- -1 if the server isn't started
	- 1 if the address ip doesn't corresponds to any Socket ID
#ce
Func _TCPServer_IP2SocketID($sIP)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][1] = $sIP Then Return $i
	Next
	; ---
	Return SetError(1, 0, 0)
EndFunc

#cs
Function: _TCPServer_SocketID2SocketHandle
	Get the Socket Handle of the corresponding Socket ID

Syntax:
	>_TCPServer_SocketID2SocketHandle($iSocket)

Parameters:
	$iSocket - Socket ID

Return:
	Sucess - Socket Handle, or -1 if the Socket ID isn't currently connected (attributed to a client)
	Failed - 0 and set @error to
	
	- -1 if the server isn't started
	- 1 if the socket ID isn't valid

Remark:
	A Socket ID is a number between 1 and the maximum number of clients of the server,
	the Socket Handle is the corresponding handle, usable by native AutoIt TCP functions, of the a Socket ID
#ce
Func _TCPServer_SocketID2SocketHandle($iSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	Return $__TCPServer_Sockets[$iSocket][0]
EndFunc

#cs
Function: _TCPServer_SocketHandle2SocketID
	Convert Socket Handle to Socket ID

Syntax:
	>_TCPServer_SocketHandle2SocketID($hSocket)

Parameters:
	$hSocket - Socket Handle

Return:
	Sucess - SocketID of the client
	Failed - 0 and set @error to

Remark:
	See <_TCPServer_SocketID2SocketHandle>
#ce
Func _TCPServer_SocketHandle2SocketID($hSocket)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] = $hSocket Then Return $i
	Next
	; ---
	Return 0
EndFunc

; ##############################################################
; NameSpace: Client's properties

#cs
Function: _TCPServer_ClientPropertyGet
	Return client's property current value

Syntax:
	>_TCPServer_ClientPropertyGet($iSocket, $iProperty)

Parameters:
	$iSocket - Socket ID of a client
	$iProperty - 0-based index of the property

Return:
	Succes - Value of the property
	Failed - 0 and set @error to
	
	- -1 if the server isn't started
	- -2 if client's properties number is 0 (see <_TCPServer_Create>)
	- 1 if the Socket ID is invalid
	- 2 if the Property ID is invalid
#ce
Func _TCPServer_ClientPropertyGet($iSocket, $iProperty)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	If $__TCPSrv_Info_CLIENTPROP = 0 Then Return SetError(-2, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	If Not __TCPServer_IsProperyIDValid($iProperty) Then Return SetError(2, 0, 0)
	; ---
	Return $__TCPServer_ClientProperties[$iSocket][$iProperty]
EndFunc

#cs
Function: _TCPServer_ClientPropertySet
	Set client's propery value

Syntax:
	>_TCPServer_ClientPropertySet($iSocket, $iProperty, $Value)

Parameters:
	$iSocket - Socket ID of a client
	$iProperty - 0-based index of the property
	$Value - Value to assign

Return:
	Succes - 1
	Failed - 0 and set @error to
	
	- -1 if the server isn't started
	- -2 if client's properties number is 0 (see <_TCPServer_Create>)
	- 1 if the Socket ID is invalid
	- 2 if the Property ID is invalid
#ce
Func _TCPServer_ClientPropertySet($iSocket, $iProperty, $Value)
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	If $__TCPSrv_Info_CLIENTPROP = 0 Then Return SetError(-2, 0, 0)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	If Not __TCPServer_IsProperyIDValid($iProperty) Then Return SetError(2, 0, 0)
	; ---
	$__TCPServer_ClientProperties[$iSocket][$iProperty] = $Value
	Return 1
EndFunc

Func __TCPServer_InitPropertiesArray()
	If $__TCPSrv_Info_CLIENTPROP = 0 Then Return
	; ---
	ReDim $__TCPServer_ClientProperties[$__TCPSrv_Info_MAXCLIENTS + 1][$__TCPSrv_Info_CLIENTPROP]
	$__TCPServer_ClientProperties[0][0] = $__TCPSrv_Info_MAXCLIENTS
EndFunc

Func __TCPServer_IsProperyIDValid($id)
	If $id >= 0 And $id <= $__TCPSrv_Info_CLIENTPROP - 1 Then
		Return 1
	Else
		Return 0
	EndIf
EndFunc

; ##############################################################
; NameSpace: Processing

#cs
Function: _TCPServer_Process
	This function makes the server work, all data is processed here, and all callbacks are called from here

Syntax:
	>_TCPServer_Process()

Parameters:
	None

Return:
	Sucess - 1
	Failed - 0 and set @error to -1 if the server isn't started

Remark:
	This function must be called indefinitly in your main loop or with AdLibRegister
#ce
Func _TCPServer_Process()
	If Not _TCPServer_IsStarted() Then Return SetError(-1, 0, 0)
	; ---
	Local $hNewSocket, $recv, $tmp
	; ---
	; Check new connexions
	$hNewSocket = TCPAccept($__TCPSrv_Info_SOCKET)
	If $hNewSocket <> -1 Then
		__TCPServer_StoreNewClient($hNewSocket)
	EndIf
	; ---
	; Process Connected clients
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] = -1 Then ContinueLoop
		; ---
		$recv = TCPRecv($__TCPServer_Sockets[$i][0], 4096)
		; ---
		; Check disconnection
		If @error Then
			If $__TCPSrv_Info_CB_LOST <> "" Then _
				Call($__TCPSrv_Info_CB_LOST, $i, $__TCPServer_Sockets[$i][1])
			; ---
			TCPCloseSocket($__TCPServer_Sockets[$i][0])
			__TCPServer_ResetSocket($i)
		EndIf
		; ---
		; Check Receiving
		If $recv Then
			$__TCPServer_Sockets[$i][3] = TimerInit()
			$__TCPServer_Sockets[$i][4] = TimerInit()
			$__TCPServer_Sockets[$i][2] &= $recv
			; ---
			If $__TCPSrv_Info_CB_RECEIVING <> "" Then _
				Call($__TCPSrv_Info_CB_RECEIVING, $i, $__TCPServer_Sockets[$i][1], BinaryLen($__TCPServer_Sockets[$i][2]))
		EndIf
		; ---
		; Check timeout
		If $__TCPServer_Sockets[$i][2] Then
			If TimerDiff($__TCPServer_Sockets[$i][3]) >= $__TCPSrv_Info_TIMEOUT Then ; Timed-out!
				If $__TCPSrv_Info_CB_TIMEDOUT <> "" Then _
					Call($__TCPSrv_Info_CB_TIMEDOUT, $i, $__TCPServer_Sockets[$i][1], BinaryLen($__TCPServer_Sockets[$i][2]))
				; ---
				$__TCPServer_Sockets[$i][2] = ""
			EndIf
		EndIf
		; ---
		; Check buffer
		$tmp = __TCPServer_SocketCheckBuffer($i)
		If IsArray($tmp) Then
			$__TCPServer_Sockets[$i][4] = TimerInit()
			For $elem In $tmp
				If $__TCPSrv_Info_CB_RECV <> "" Then _
					Call($__TCPSrv_Info_CB_RECV, $i, $__TCPServer_Sockets[$i][1], $elem)
			Next
			; ---
			$__TCPServer_Sockets[$i][2] = ""
		EndIf
	Next
	; ---
	Return 1
EndFunc

Func __TCPServer_StoreNewClient($hSocket)
	Local $index = -1
	For $i = 1 To $__TCPServer_Sockets[0][0]
		If $__TCPServer_Sockets[$i][0] < 0 Then
			$index = $i
			ExitLoop
		EndIf
	Next
	If $index = -1 Then Return 0 ; server full
	; ---
	$__TCPServer_Sockets[$index][0] = $hSocket
	$__TCPServer_Sockets[$index][1] = __TCPServer_Socket2IP($hSocket)
	$__TCPServer_Sockets[$index][4] = TimerInit()
	; ---
	If $__TCPSrv_Info_CB_NEW <> "" Then _
		Call($__TCPSrv_Info_CB_NEW, $index, $__TCPServer_Sockets[$index][1])
	; ---
	Return 1
EndFunc

Func __TCPServer_SocketCheckBuffer($iSocket)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	If Not $__TCPServer_Sockets[$iSocket][2] Then Return 0
	; ---
	Local $bet = _StringBetween($__TCPServer_Sockets[$iSocket][2], Chr(2), Chr(3))
	If IsArray($bet) Then
		For $i = 0 To UBound($bet) - 1
			$bet[$i] = __TCPServer_dCry($bet[$i])
		Next
		Return $bet
	Else
		Return 0
	EndIf
EndFunc

; ##############################################################
; Internals

Func __TCPServer_Cry($Data)
	If Not $__TCPSrv_Info_CRYKEY Then Return $Data
	; ---
	Local $bin = 1
	If Not IsBinary($Data) Then
		$bin = 0
		$Data = StringToBinary($Data, 4)
	EndIf
	; ---
	$Data = _Crypt_EncryptData($Data, $__TCPSrv_Info_CRYKEY, $CALG_USERKEY)
	; ---
	If $__TCPSrv_Info_COMPRESSION Then $Data = _ZLIB_Compress($Data, $__TCPSrv_Info_COMPRESSION)
	; ---
	If Not $bin Then $Data = StringTrimLeft($Data, 2)
	; ---
	Return $Data
EndFunc

Func __TCPServer_dCry($Data)
	If Not $__TCPSrv_Info_CRYKEY Then Return $Data
	; ---
	Local $bin = 0
	If StringLeft($Data, 2) = "0x" Then
		$bin = 1
		$Data = Binary($Data)
	Else
		$Data = Binary("0x" & $Data)
	EndIf
	; ---
	If $__TCPSrv_Info_COMPRESSION Then $Data = _ZLIB_Uncompress($Data)
	; ---
	$Data = _Crypt_DecryptData($Data, $__TCPSrv_Info_CRYKEY, $CALG_USERKEY)
	If Not $bin Then $Data = BinaryToString($Data, 4)
	; ---
	Return $Data
EndFunc

Func __TCPServer_InitSocketsArray()
	ReDim $__TCPServer_Sockets[$__TCPSrv_Info_MAXCLIENTS + 1][5]
	For $i = 1 To $__TCPSrv_Info_MAXCLIENTS
		$__TCPServer_Sockets[$i][0] = -1
		$__TCPServer_Sockets[$i][1] = ""
		$__TCPServer_Sockets[$i][2] = ""
		$__TCPServer_Sockets[$i][3] = 0
		$__TCPServer_Sockets[$i][4] = 0
	Next
	$__TCPServer_Sockets[0][0] = $__TCPSrv_Info_MAXCLIENTS
EndFunc

Func __TCPServer_ResetSocket($iSocket)
	If Not __TCPServer_IsSocketValid($iSocket) Then Return SetError(1, 0, 0)
	; ---
	$__TCPServer_Sockets[$iSocket][0] = -1 ; hSocket
	$__TCPServer_Sockets[$iSocket][1] = "" ; sIP
	$__TCPServer_Sockets[$iSocket][2] = "" ; sBuffer
	$__TCPServer_Sockets[$iSocket][3] = 0 ; Timeout timer
	$__TCPServer_Sockets[$iSocket][4] = 0 ; Idle timer
	; ---
	If $__TCPSrv_Info_CLIENTPROP > 0 Then ; Corrected in 1.1
		For $i = 0 To $__TCPSrv_Info_CLIENTPROP - 1
			$__TCPServer_ClientProperties[$iSocket][$i] = ""
		Next
	EndIf
EndFunc

Func __TCPServer_IsSocketValid($iSocket)
	If $iSocket > 0 And $iSocket <= $__TCPSrv_Info_MAXCLIENTS Then
		Return 1
	Else
		Return 0
	EndIf
EndFunc

Func __TCPServer_Socket2IP($SHOCKET)
	Local $sockaddr, $aRet
	$sockaddr = DllStructCreate("short;ushort;uint;char[8]")
	$aRet = DllCall("Ws2_32.dll", "int", "getpeername", "int", $SHOCKET, _
			"ptr", DllStructGetPtr($sockaddr), "int*", DllStructGetSize($sockaddr))
	If Not @error And $aRet[0] = 0 Then
		$aRet = DllCall("Ws2_32.dll", "str", "inet_ntoa", "int", DllStructGetData($sockaddr, 3))
		If Not @error Then $aRet = $aRet[0]
	Else
		$aRet = 0
	EndIf
	$sockaddr = 0
	Return $aRet
EndFunc   ;==>__Class_TCPClient_SocketToIP
