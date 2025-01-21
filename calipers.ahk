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
calState:={Draw:0,Move:0,March:0,Last:0}												; 
calArray := []																			; Array of X positions
mLast := {X:0,Y:0}																		; To store mouse X,Y coords
scale := ""																				; Multiplier for calibration

createLayeredWindow()
MainGUI()

OnExit ExitFunc

;--- FUNCTIONS FOLLOW ------------------------------------------------------------------

createLayeredWindow() {
	global GdipOBJ

	GdipOBJ := Layered_Window_SetUp(4,scr.X,scr.Y,scr.W,scr.H)
	GdipOBJ.Pen := New_Pen("FF0000",,1)
	GdipOBJ.PenMarch := New_Pen("ff4000",,1)
	return
}

MainGUI() {
	global GdipOBJ, calArray, calState

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
		calArray := []
		Gdip_GraphicsClear(GdipOBJ.G)
		clickCaliper()
		return	
	}
	
	toggleMarch(*) {
		calState.March := !calState.March
	}
	
}

; Start drawing caliper line based on lines present
; 	0: Start first line (X1)
; 	1: Start second line
; 	2+: Both lines present, grab something
clickCaliper() {
	global GdipOBJ, calState, calArray

	if (calArray.Length >= 2) {															; Both calipers present, grab something
		mPos := mouseCoord()

	}

	calState.Draw := true
	SetTimer(drawCaliper,50)
	return
}

mouseCoord() {
	global mLast

	MouseGetPos(&mx,&my)
	lastX := mLast.X
	lastY := mLast.Y
	dx := mx-lastX
	dy := my-lastY
	mLast := {X:mx,Y:my}

	return {X:mx,Y:my, 
			lastX:lastX,lastY:lastY, 
			dx:dx,dy:dy}
}

; Plunk new caliper line at last mouse position
dropCaliper() {
	global calArray, mLast
	calArray.push(mLast)
	Return
}
	
; Create caliper lines based on prev lines and new position
; Add Hline if more than one line on the field
drawCaliper() {
	global GdipOBJ, calState, calArray, mLast, scr

	mPos := mouseCoord()

	if (calState.March=true) {

	}

	buildCalipers()

	num := calArray.Length
	if (num) {																			; Draw Hline when first line dropped
		dx := Abs(calArray[1].X - mPos.x)
		drawHline(calArray[1].x,mPos.x,mPos.y)
		scaleTooltip(dx)
	}
	if (num=2) {																		; Done when second line drops
		active_Draw := 0
		SetTimer(drawCaliper)
		; reorderCalipers()
	}


	drawVline(mPos.x)																	; Draw live caliper
	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)				; Refresh viewport
}


; Draw all calipers lines from calArray
buildCalipers() {
	global GdipOBJ, calArray

	Gdip_GraphicsClear(GdipOBJ.G)
	Loop calArray.Length																; Draw saved calipers
	{
		drawVline(calArray[A_Index].X)
	}
	Return
}

; Draw vertical line at X
drawVline(X) {
	global GdipOBJ

	Gdip_DrawLine(GdipOBJ.G, GdipOBJ.Pen, X, GdipOBJ.Y, X, GdipOBJ.H)
	Return
}

; Draw horizontal line from X1-X2, at YI
drawHline(x1,x2,y) {
	global GdipOBJ
	
	Gdip_DrawLine(GdipOBJ.G, GdipOBJ.Pen, x1, y, x2, y)
	Return
}

; Display tooltip measurements
scaleTooltip(dx) {
	global scale

	ms := (scale) ? Round(dx/scale) : ""
	bpm := (ms) ? Round(60000/ms,1) : ""
	ToolTip((scale="") 
			? dx " px" 
			: ms " ms`n" bpm " bpm") 
	Return
}
	
#HotIf (calState.Draw=false) 
^LButton::
{
	clickCaliper()
	Return
}

#HotIf (calState.Move=true)
LButton Up::
^LButton Up::
{
	; moveRelease()
	Return
}

#HotIf (calState.Draw=true)
LButton Up::
^LButton Up::
{
	dropCaliper()
	Return
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
