/*  Calipers
	Portable AHK2 based tool for on-screen measurements.
	"Auto calibration" scans for vertical lines.
	"Auto level" scans for horizontal lines.
	Calculations
	March-out with drag of any line
*/

#Requires AutoHotkey v2
#SingleInstance Force  ; only allow one running instance per user
#Include %A_ScriptDir%\lib\



;--- INCLUDES FOLLOW -------------------------------------------------------------------
#Include Gdip_All.ahk
#Include Gdip_Toolbox.ahk
