/*  Calipers
	Portable AHK2 based tool for on-screen measurements.
	"Auto calibration" scans for vertical lines.
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
		Drag:0,																			; DRAG L mode
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
	global GdipOBJ, calArray, calState, phase

	phase := Gui()
	phase.Opt("-MaximizeBox -MinimizeBox +AlwaysOnTop +ToolWindow")
	phase.BackColor := "C2BDBE"
	phase.Title := "TC Calipers"

	phase.AddCheckbox(,"Calipers")
			.OnEvent("Click",toggleCaliper)
	phase.AddCheckbox("Disabled","March out")
			.OnEvent("Click",toggleMarch)
	phase.AddButton("Disabled","Calibrate")
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
		calArray := []																	; Whether opening or closing
		Gdip_GraphicsClear(GdipOBJ.G)													; clear calArray and bitmap

		if (calState.Active) {
			newCalipers()
		} else {
			UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)
			ToolTip()
			phase["March"].Enabled := false
			phase["Calibrate"].Enabled := false
		}
	}

	toggleMarch(*) {
		calState.March := !calState.March
	}

	btnCalibrate(*) {
		Calibrate()
	}
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
		MouseMove(calArray[2].X,calArray[2].Y)
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
	global scr, mLast, calArray

	midX := scr.W//2
	midY := scr.H//2
	calArray.InsertAt(1,midX-50,midX+50)
	mLast.Y := midY

	drawCalipers()

	return
}

; Drag or move calipers when click on V or H line
clickCaliper() {
	global GdipOBJ, calState, calArray

	if (calArray.Length >= 2) {															; Both calipers present, grab something
		mPos := mouseCoord()
		best:=FindClosest(mPos.x,mPos.y)
		Switch best
		{
			Case 1:
				calState.Drag := true
				SetTimer(moveLcaliper,calState.refresh)
				Return
			Case 2:
				calArray.RemoveAt(best)													; Release this position, makes live

			Default:																	; Clicked on H bar
				calState.Move := true
				SetTimer(moveCalipers,calState.refresh)
		}
	}

	calState.Draw := true
	SetTimer(drawCaliper,calState.refresh)
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
dropCaliper(c1:=0) {
	global calArray, mLast, calState
	if (c1=1) {
		calArray[1]:=mLast
		calState.Drag:=false
		SetTimer(moveLcaliper,0)
		scaleTooltip(calArray[2].X-calArray[1].X)
	} else {
		calArray.push(mLast)
	}
	Return
}

; Create caliper lines based on prev lines and new position
drawCalipers() {
	global GdipOBJ, calState, calArray, mLast, scr

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

; Move the Left caliper
moveLcaliper() {
	global GdipOBJ, calArray, mLast, scr

	mPos := mouseCoord()

	calArray[1].X := mPos.X
	calArray[1].Y := mPos.Y

	drawCaliper()
	drawHline(calArray[1].x,calArray[2].x,mPos.Y)
	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)

	return
}

; Have grabbed H bar, move calipers together
moveCalipers() {
	global GdipOBJ, calArray, mLast

	mPos := mouseCoord()

	for key,val in calArray
	{
 		calArray[key].X += mPos.dx
		calArray[key].Y += mPos.dy
	}

	scaleTooltip(calArray[2].X-calArray[1].X)
	buildCalipers()
	drawHline(calArray[1].x,calArray[2].x,mPos.y)
	UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc)

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
scaleTooltip(dx) {
	global scale

	ms := (scale) ? Round(dx/scale) : ""
	bpm := (ms) ? Round(60000/ms,1) : ""
	ToolTip((scale="") 
			? dx " px" 
			: ms " ms`n" bpm " bpm") 
	Return
}

; March out caliper lines relative to X1-X2
calMarch(grip:=2) {
	global calArray, GdipOBJ, calState, mLast

	if (calArray.Length < 2) {
		Return
	}
	lastX := mLast.X																	; last known position
	fullX := lastX-calArray[1].X														; distance from X1
	steps := grip-1																		; divisor
	dx := fullX/steps																	; dx between each caliper

	calArray.RemoveAt(2, calArray.Length - 1)											; clear everything above X1

	while (lastX < GdipOBJ.W) {															; add calipers to the right
		lastX += dx
		calArray.Push({X:lastX})
	}
	lastX := calArray[1].X																; add calipers to the left
	while (lastX > GdipOBJ.X) {
		lastX -= dx
		calArray.Push({X:lastX})
	}

	Return
}

; Check if any caliper lines within threshold distance, return calArray keynum
FindClosest(mx,my) {
	global calArray
	threshold := 2
	
	for key,val in calArray {
		if Abs(val.X-mx) < threshold {
			Return key																	; Return early if hit
		}
	}
	Return
}
;#endregion

;#region === WINDOWS BUTTON HANDLING =================================================== 

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
	MouseGetPos(,,&ui,&mb)
	if (ui=phase.hwnd) {
		return
	}
	if (mb~="Button") {
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
		moveRelease()
	}
	if (calState.Draw=true) {															; Dragging caliper release
		dropCaliper()
	}
	if (calState.Drag=true) {
		dropCaliper(1)
	}
	return
}

WM_SETCURSOR(wp, *) {
    if (wp != GdipOBJ.hwnd) {
		return
	}

    return DllCall('SetCursor', 'Ptr', GdipOBJ.compassCursor)
    
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
	GdipOBJ.sizeCursor := LoadCursor(IDC_SIZEWE := 32644)
	GdipOBJ.compassCursor := LoadCursor(IDC_SIZEWE := 32646)

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
