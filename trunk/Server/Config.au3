#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         Matwachich

 Script Function:
	

#ce ----------------------------------------------------------------------------

#include "lib\AutoConfig.au3"

_AutoCfg_Init($ACFG_INI, $__AppData & "\config.ini")
	_AutoCfg_AddEntry("port", 13587)
	; ---
	_AutoCfg_AddEntry("sv_Users_Max", 1000)
	_AutoCfg_AddEntry("sv_Connected_Max", 1000)
	; ---
	_AutoCfg_AddEntry("sv_Pseudo_Max", 10)
	_AutoCfg_AddEntry("sv_Nom_Max", 30)
	_AutoCfg_AddEntry("sv_Localisation_Max", 30)
	_AutoCfg_AddEntry("sv_Presentation_Max", 160)
	_AutoCfg_AddEntry("sv_Password_Max", 6)
	; ---
	_AutoCfg_AddEntry("sv_Clean", 0)
	_AutoCfg_AddEntry("sv_Clean_Delay", 30)
	; ---
	_AutoCfg_AddEntry("sv_mail_smtp", "")
	_AutoCfg_AddEntry("sv_mail_user", "")
	_AutoCfg_AddEntry("sv_mail_pwd", "")
	_AutoCfg_AddEntry("sv_mail_port", "21")
	_AutoCfg_AddEntry("sv_mail_ssl", "0")
_AutoCfg_Update()
