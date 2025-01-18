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

MainGUI()
GdipOBJ := Layered_Window_SetUp(4,GdipOBJ.X,GdipOBJ.Y,GdipOBJ.W,GdipOBJ.H,2,"-Caption -DPIScale +Parent1")
GdipOBJ.Pen:=New_Pen("FF0000",,1)														; Red pen


;--- FUNCTIONS FOLLOW ------------------------------------------------------------------
MainGUI() {
	global phase
	
	phase := Gui()
	phase.Opt("-MaximizeBox -MinimizeBox +AlwaysOnTop +ToolWindow")
	phase.BackColor := "C2BDBE"
	phase.Title := "TC Calipers"

	btnNew := phase.AddButton(,"New caliper")
			.OnEvent("Click",clickCaliper)
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
			; eventlog("<<<<< Session end.")
			ExitApp
		}

	}

	clickCaliper(*) {

	}
	
	toggleMarch(*) {
		global active_March
		active_March := !active_March
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
	; Gui,% Layered.Name ": +E0x80000 +LastFound " Layered.Options 
	; Gui,% Layered.Name ":Show",% "x" Layered.X " y" Layered.Y " w" Layered.W " h" Layered.H " NA"
}

New_Pen(colour:="000000",Alpha:="FF",Width:= 5) {
	new_colour := "0x" Alpha colour 
	return Gdip_CreatePen(New_Colour,Width)
}


;--- INCLUDES FOLLOW -------------------------------------------------------------------
#Include Gdip_All.ahk
#Include Gdip_Toolbox.ahk
