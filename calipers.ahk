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

scr:={X: 0 ,Y: 0 ,W: A_ScreenWidth, H: A_ScreenHeight }									; Screen dimensions
calState:={Draw:0,Move:0,March:0}														; <= These need to remain simple vars
calArray := {}																			; Array of X positions
mLast := {}																				; To store mouse X,Y coords
scale := ""																				; Multiplier for calibration

createLayeredWindow()
MainGUI()

OnExit ExitFunc

;--- FUNCTIONS FOLLOW ------------------------------------------------------------------

createLayeredWindow() {
	global GdipOBJ

	GdipOBJ := Layered_Window_SetUp(4,scr.X,scr.Y,scr.W,scr.H)
	GdipOBJ.Pen := New_Pen("FF0000",,2)
	GdipOBJ.PenMarch := New_Pen("ff4000",,1)
	return
}

MainGUI() {
	phase := Gui()
	phase.Opt("-MaximizeBox -MinimizeBox +AlwaysOnTop +ToolWindow")
	phase.BackColor := "C2BDBE"
	phase.Title := "TC Calipers"

	btnNew := phase.AddButton(,"New caliper")
			.OnEvent("Click",newCaliper)
	phase.AddButton(,"Clear caliper")
	phase.AddButton(,"Calibrate")
	chkMarch := phase.AddCheckbox(,"March off")
			.OnEvent("Click",toggleMarch)
	
	phase.Show("x1600 w120")
	phase.OnEvent("Close",phaseClose)
	return

	/*	Internal phaseGUI methods
	*/
	phaseClose(*) {
		ask := MsgBox("Really quit Calipers?","Exit",262161)
		If (ask="OK")
		{
			ExitApp
		}

	}

	newCaliper(*) {
		global GdipOBJ, calArray
	
		calArray := {}
		Gdip_GraphicsClear(GdipOBJ.G)
		clickCaliper()
		return	
	}
	
	toggleMarch(*) {
		global calState
		calState.March := !calState.March
	}
	
}

Layered_Window_SetUp(Smoothing,Window_X,Window_Y,Window_W,Window_H,Window_Name:=1,Window_Options:="") {
	Layered:={}
	Layered.W:=Window_W
	Layered.H:=Window_H
	Layered.X:=Window_X
	Layered.Y:=Window_Y
	Layered.Name:=Window_Name
	Layered.Options:=Window_Options
	Layered.Token:=Gdip_Startup()
	Create_Layered_GUI(Layered)
	Layered.hwnd:=winExist()
	Layered.hbm := CreateDIBSection(Window_W,Window_H)
	Layered.hdc := CreateCompatibleDC()
	Layered.obm := SelectObject(Layered.hdc,Layered.hbm)
	Layered.G := Gdip_GraphicsFromHDC(Layered.hdc)
	Gdip_SetSmoothingMode(Layered.G,Smoothing)
	return Layered
}

Create_Layered_GUI(Layered)
{
    baseWin := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
    baseWin.Show("NA")
}

New_Pen(colour:="000000",Alpha:="FF",Width:= 5) {
	new_colour := "0x" Alpha colour 
	return Gdip_CreatePen(New_Colour,Width)
}

ExitFunc(ExitReason, ExitCode)
{
   global
   ; gdi+ may now be shutdown on exiting the program
   Gdip_Shutdown(GdipOBJ.Token)
}

;--- INCLUDES FOLLOW -------------------------------------------------------------------
#Include Gdip_All.ahk
