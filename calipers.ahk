/*  Calipers
	Portable AHK2 based tool for on-screen measurements.
	mCOSM - mCaliper On-Screen Measurement
	COMET - Calipers On-screen Measurement Electronic Tool
	ESCARGOT - Electronic Screen Caliper for Arrhythmia Reading of Graphic Online Types
*/

#Requires AutoHotkey v2
#SingleInstance Force  ; only allow one running instance per user
#Include %A_ScriptDir%\lib\
CoordMode("Mouse","Screen")

scr:={X: 0 ,Y: 0,
		W: A_ScreenWidth, H: A_ScreenHeight,											; Screen dimensions
		sizeCursor: LoadCursor(IDC_SIZEWE := 32644),									; and cursor ptrs
		compassCursor: LoadCursor(IDC_SIZEALL := 32646)
	}

calState:={
		Active:0,																		; Calipers ACTIVE
		Drag:0,																			; DRAG mode
		Move:0,																			; MOVE mode
		March:0,																		; MARCH mode
		refresh:30																		; Refresh rate for timers
		}
calArray := []																			; Array of X positions
mLast := {X:0,Y:0}																		; To store mouse X,Y coords
scale := ""																				; Multiplier for calibration

createLayeredWindow()
MainGUI()

OnMessage(0x201, WM_LBUTTONDOWN)														; LMB press
OnMessage(0x202, WM_LBUTTONUP)															; LMB release
OnMessage(0x020, WM_SETCURSOR)

OnExit ExitFunc

;#region === GUI FUNCTIONS =============================================================

MainGUI() {
	global GdipOBJ, calArray, calState
	static btnCalc:=false, 
			valRR:="", 
			valQT:="", 
			valQTc:=""

	phase := Gui()
	phase.Opt("-MaximizeBox -MinimizeBox +AlwaysOnTop -ToolWindow")
	phase.BackColor := "C2BDBE"
	phase.Title := "TC Cal Meas Tool"

	phase.AddCheckbox(,"Calipers")
			.OnEvent("Click",toggleCaliper)
	phase.AddCheckbox("x100 yP Disabled","March out")
			.OnEvent("Click",toggleMarch)
	phase.AddButton("x10 Disabled","Calibrate")
			.OnEvent("Click",btnCalibrate)
	phase.AddButton("x100 yP Disabled","Calculate")
			.OnEvent("Click",btnCalculate)
	
	phase.AddText("R2 X10","")
	phase.AddButton("w50 x30","R-R   =")
			.OnEvent("Click",btnRR)
			resRR := phase.AddText("w50 x90 yP+4",valRR)
	phase.AddButton("w50 x30","Q-T   =")
			.OnEvent("Click",btnQT)
			resQT := phase.AddText("w50 x90 yP+4",valQT)
	phase.AddButton("w50 x30","QTc =")
			.OnEvent("Click",btnQTc)
			resQTc := phase.AddText("w50 x90 yP+4",valQTc)
	
	phase.Show("x" scr.W * 0.8 " h60")
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
		calArray := []																	; Whether opening or closing
		Gdip_GraphicsClear(GdipOBJ.G)													; clear calArray and bitmap

		if (calState.Active) {
			newCalipers()
			phase["March"].Enabled := true
			phase["Calibrate"].Enabled := true
			phase["Calculate"].Enabled := true
		} else {
			UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)
			ToolTip()
			phase["March"].Enabled := false
			phase["Calibrate"].Enabled := false
			phase["Calculate"].Enabled := false
		}
	}

	toggleMarch(*) {
		calState.March := !calState.March
		if (calArray.Length>2) {
			calArray.RemoveAt(3, calArray.Length - 2)
		}
		drawCalipers()
	}

	btnCalibrate(*) {
		Calibrate()
	}

	btnCalculate(*) {
		btnCalc := !btnCalc
		if (btnCalc) {
			phase.Show("AutoSize")

		} else {
			phase.Show("h60")
		}

	}
	btnRR(*) {
		dx := calDiff()

	}
	btnQT(*) {

	}
	btnQTc(*) {

	}
}

; Calibration GUI to calculate scale
Calibrate() {
	global calArray, scale, mLast

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
		dx := Abs(calArray[1] - calArray[2])
		scale := dx/ms
		MouseMove(calArray[2],mLast.Y)
		scaleTooltip() 
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
		}
		cWin.Destroy()
	}
	
	cWinClose(*) {
		return
	}
}
;#endregion

;#region === CALIPER FUNCTIONS =========================================================

; Create new set of calipers
newCalipers() {
	global scr, calArray, mLast

	midX := scr.W//2
	midY := scr.H//2
	calArray.InsertAt(1,midX-50,midX+50)
	mLast.Y := midY

	drawCalipers()

	return
}

; Drag or move calipers when click on V or H line
clickCaliper() {
	global calState

	mPos := mouseCoord()
	if (calState.Best) {
		calState.Drag := true
		SetTimer(dragCaliper,calState.refresh)
	} else {
		calstate.Move := true
		SetTimer(moveCalipers,calState.refresh)
	}

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

	return {X:mx,Y:my, dx:dx,dy:dy}
}

; Drag a caliper V line
dragCaliper() {
	global calArray, calState, mLast

	grip:=FindClosest(mLast.X)
	mPos := mouseCoord()

	if (grip>2) {
		dx := calDiff()
		fullX := Abs(calArray[grip] - calArray[1])
		newX := Abs(mPos.X - calArray[1])
		factor := newX/fullX
		calArray[2] := (dx*factor) + calArray[1]
	} else {
		calArray[grip] := mPos.X
	}

	scaleTooltip()
	drawCalipers()

	return	
}

; Plunk new caliper line at last mouse position
dropCaliper() {
	global calState

	calState.Drag:=false
	SetTimer(dragCaliper,0)
	Return
}

; Create caliper lines based on prev lines and new position
drawCalipers() {
	global GdipOBJ, calArray, calstate, mLast, scr

	if (calState.March=true) {
		calMarch()
	}

	Gdip_GraphicsClear(GdipOBJ.G)														; Clear bitmap
	Loop calArray.Length																; Draw saved V calipers
	{
		drawVline(calArray[A_Index])
	}
	drawHline(mLast.Y)
	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)				; Refresh viewport

	Return
}

; Draw vertical line at X
drawVline(X) {
	global GdipOBJ

	Gdip_DrawLine(GdipOBJ.G, GdipOBJ.Pen, X, GdipOBJ.Y, X, GdipOBJ.H)
	Return
}

; Draw horizontal line from X1-X2, at Y
drawHline(y) {
	global GdipOBJ, calArray
	
	Gdip_DrawLine(GdipOBJ.G, GdipOBJ.Pen, calArray[1], y, calArray[2], y)
	Return
}

; Have grabbed H bar, move calipers together
moveCalipers() {
	global calArray

	mPos := mouseCoord()

	for key,val in calArray
	{
 		calArray[key] += mPos.dx
	}

	scaleTooltip()
	drawCalipers()

	Return
}

; Drop the set of calipers being moved
moveRelease() {
	global calState
	
	calState.Move := false
	SetTimer(moveCalipers,0)
	Return
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
scaleTooltip() {
	global scale, calArray

	dx := calDiff()
	ms := (scale) ? Round(dx/scale) : ""
	bpm := (ms) ? Round(60000/ms,1) : ""
	ToolTip((scale="") 
			? dx " px" 
			: ms " ms`n" bpm " bpm") 
	Return
}

; March out caliper lines relative to X1-X2
calMarch() {
	global calArray, scr

	dx := calDiff()
	calArray.RemoveAt(2, calArray.Length - 1)											; clear everything above X1

	lastX := calArray[1]
	while (lastX < scr.W) {																; add calipers to the right
		lastX += dx
		calArray.Push(lastX)
	}
	lastX := calArray[1]																; add calipers to the left
	while (lastX > scr.X) {
		lastX -= dx
		calArray.Push(lastX)
	}

	Return
}

; Check if any caliper lines within threshold distance, return calArray keynum
FindClosest(mx) {
	global calArray
	threshold := 2
	
	for key,val in calArray {
		if Abs(val-mx) < threshold {
			Return key																	; Return early if hit
		}
	}
	Return
}

calDiff() {
	global calArray

	return calArray[2]-calArray[1]
}
;#endregion

;#region === WINDOWS BUTTON HANDLING =================================================== 

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
	MouseGetPos(,,&ui,&mb)
	if (ui = GdipOBJ.hwnd) {
		clickCaliper()
	}
}

WM_LBUTTONUP(wParam, lParam, msg, hwnd)
{
	if (calState.Move=true) {															; Moving calipers release
		moveRelease()
	}
	if (calState.Drag=true) {															; Dragging caliper release
		dropCaliper()
	}
}

WM_SETCURSOR(wp, *) {
    if (wp != GdipOBJ.hwnd) {
		calState.Best := ""
		return
	}
	MouseGetPos(&mx)
	if (best:=FindClosest(mx)) {
		calState.Best := best															; Matches V caliper
		return DllCall('SetCursor', 'Ptr', scr.sizeCursor)
	} else {																			; Otherwise H bar
		calState.Best := 0
		return DllCall('SetCursor', 'Ptr', scr.compassCursor)
	}
}

LoadCursor(cursorId) {
    static IMAGE_CURSOR := 2, flags := (LR_DEFAULTSIZE := 0x40) | (LR_SHARED := 0x8000)
    return DllCall('LoadImage', 'Ptr', 0, 'UInt', cursorId, 'UInt', IMAGE_CURSOR,
                                'Int', 0, 'Int', 0, 'UInt', flags, 'Ptr')
}
;#endregion

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
;#endregion

;#region === INCLUDES FOLLOW ===========================================================
#Include Gdip_All.ahk
