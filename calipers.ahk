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
CoordMode("Mouse","Screen")

GdipOBJ:={X: 0 ,Y: 0 ,W: A_ScreenWidth, H: A_ScreenHeight }								; Screen overlay object
active_Draw:=0																			; <= These need to remain simple vars
active_Move:=0																			; <= so they can be used in GUI 
active_March:=0																			; <= commands.
calArray := {}																			; Array of X positions
mLast := {}																				; To store mouse X,Y coords
scale := ""																				; Multiplier for calibration

main:=MainGUI()
GdipOBJ := Layered_Window_SetUp(4,GdipOBJ.X,GdipOBJ.Y,GdipOBJ.W,GdipOBJ.H,2,"-Caption -DPIScale +Parent1")
GdipOBJ.Pen:=New_Pen("FF0000",,1)														; Red pen




;--- INCLUDES FOLLOW -------------------------------------------------------------------
#Include Gdip_All.ahk
#Include Gdip_Toolbox.ahk
