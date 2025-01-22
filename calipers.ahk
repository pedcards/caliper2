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
calState:={
		Active:0,																		; Calipers ACTIVE
		Draw:0,																			; DRAW mode
		Move:0,																			; MOVE mode
		March:0}																		; MARCH mode
calArray := []																			; Array of X positions
mLast := {X:0,Y:0}																		; To store mouse X,Y coords
scale := ""																				; Multiplier for calibration

createLayeredWindow()
MainGUI()

OnMessage(0x201, WM_LBUTTONDOWN)														; LMB press
OnMessage(0x202, WM_LBUTTONUP)															; LMB release

OnExit ExitFunc

;#region === GUI FUNCTIONS =============================================================

MainGUI() {
	global GdipOBJ, calArray, calState, phase

	phase := Gui()
	phase.Opt("-MaximizeBox -MinimizeBox +AlwaysOnTop +ToolWindow")
	phase.BackColor := "C2BDBE"
	phase.Title := "TC Calipers"

	phase.chkNew := phase.AddCheckbox(,"Calipers")
			.OnEvent("Click",toggleCaliper)
	phase.chkMarch := phase.AddCheckbox("Disabled","March out")
			.OnEvent("Click",toggleMarch)
	phase.btnCal := phase.AddButton("","Calibrate")
			.OnEvent("Click",btnCalibrate)
	
	phase.Show("x" scr.W * 0.8 " w120")
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

	toggleCaliper(*) {
		calState.Active := !calState.Active
		calArray := []
		Gdip_GraphicsClear(GdipOBJ.G)

		if (calState.Active) {
			clickCaliper()
		} else {
			UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)
			ToolTip()
		}
	}

	toggleMarch(*) {
		calState.March := !calState.March
	}

	btnCalibrate(*) {
		if (calArray.Length < 2) {
			MsgBox("Need to draw out calipers first!")
			return
		}
		Calibrate()
	}
}
;#region === CALIPER FUNCTIONS =========================================================

; Start drawing caliper line based on lines present
; 	0: Start first line (X1)
; 	1: Start second line
; 	2+: Both lines present, grab something
clickCaliper() {
	global GdipOBJ, calState, calArray

	if (calArray.Length >= 2) {															; Both calipers present, grab something
		mPos := mouseCoord()
		best:=FindClosest(mPos.x,mPos.y)
		Switch best
		{
			Case 1:
				calState.Move := true
				SetTimer(moveCaliper, 50)
				Return
			Case 2:
				calArray.RemoveAt(best)													; Release this position, makes live

			Default:
				Return																	; Not close, ignore
		}
	}

	calState.Draw := true
	SetTimer(drawCaliper,50)
	return
}

; Get mouse coords, last coords, and dx/dy
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
		calState.Draw := false
		SetTimer(drawCaliper,0)
		reorderCalipers()
	}

	drawVline(mPos.x)																	; Draw live caliper
	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)				; Refresh viewport

	return
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

moveCaliper() {
; /*	Have grabbed X1 from dropped caliper
; */
; 	global GdipOBJ, calArray, mLast

; 	MouseGetPos,mx,my
; 	dx := mx-mLast.X
; 	dy := my-mLast.Y
; 	mLast := {X:mx,Y:my}

; 	for key in calArray
; 	{
; 		calArray[key].X += dx
; 		calArray[key].Y += dy
; 	}

; 	scaleTooltip(calArray[2].X-calArray[1].X)
; 	drawCalipers()
; 	drawHline(calArray[1].x,calArray[2].x,my)
; 	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc)

; 	Return
}
	
moveRelease() {
; /*	Drop the set of calipers being moved
; */
; 	global active_Move
; 	active_Move=0
; 	SetTimer, moveCaliper, Off
; 	ToolTip
; 	Return
}

; Make sure that X1 always smaller than X2
reorderCalipers() {
	global calArray

	if (calArray[1].X > calArray[2].X) {
		t := calArray[1]
		calArray[1] := calArray[2]
		calArray[2] := t
	}
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

; Calibration GUI to calculate scale
Calibrate() {
	global calArray, scale

	cWin := Gui()
	cWin.AddText("w200 Center","Select calibration measurement")
	cWin.AddButton("w200","1000 ms (good)").OnEvent("Click",cBtnClicked)
	cWin.AddButton("w200","2000 ms (better)").OnEvent("Click",cBtnClicked)
	cWin.AddButton("w200","3000 ms (best)").OnEvent("Click",cBtnClicked)
	cWin.AddButton("w200","Other").OnEvent("Click",cBtnClicked)
	cWin.Title := "Calibrate"
	cWin.OnEvent("Close",cWinClose)
	cWin.Opt("+AlwaysOnTop -MaximizeBox -MinimizeBox")
	cWin.Show("Center Autosize")
	ms := 0

	WinWaitClose("Calibrate")
	if (ms) {
		dx := Abs(calArray[1].X - calArray[2].X)
		scale := dx/ms
		MouseMove(mLast.X,mLast.Y)
		scaleTooltip(dx) 
	}
	Return

	cBtnClicked(Button,*) {
		x := Button.Text
		Switch {
			case x~="1000": 
				ms := 1000
			case x~="2000": 
				ms := 2000
			case x~="3000": 
				ms := 3000
			case x~="Other":
				ms := InputBox("Enter time (ms)","Other duration").Value
			Default:   
		}
		cWin.Destroy()
	}
	
	cWinClose(*) {
		return
	}
}

; Check if any caliper lines within threshold distance, return calArray keynum
FindClosest(mx,my) {
	global calArray
	threshold := 3
	
	for key,val in calArray {
		if Abs(val.X-mx) < threshold {
			Return key																	; Return early if hit
		}
	}
	Return
}

;#region === WINDOWS BUTTON HANDLING =================================================== 

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
	if (calArray.Length < 2) {															; No stamped caliper exists
		return
	} 
	if (calState.Draw=false) {															; Not drawing? Let's draw/drag!
		clickCaliper()
	}
	return
}

WM_LBUTTONUP(wParam, lParam, msg, hwnd)
{
	if (calState.Move=true) {															; Moving calipers release
		; moveRelease()
		return
	}
	if (calState.Draw=true) {															; Dragging caliper release
		dropCaliper()
		return
	}
	return
}

;#region === GDI+ FUNCTIONS ============================================================

createLayeredWindow() {
	global GdipOBJ

	GdipOBJ := Layered_Window_SetUp(4,scr.X,scr.Y,scr.W,scr.H)
	GdipOBJ.Pen := New_Pen("FF0000",,2)
	GdipOBJ.PenMarch := New_Pen("ff4000",,1)
	return
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

;#region === INCLUDES FOLLOW ===========================================================
#Include Gdip_All.ahk
