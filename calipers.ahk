/*  Calipers
	Portable AHKv2 based tool for on-screen measurements.
	COMET - Calipers On-screen MEasurement Tool

	TODO:
	* Scan for 3 sec tick marks
		- use FindText to identify up and down ticks https://www.autohotkey.com/boards/viewtopic.php?f=83&t=116471
		- ImageActions, wrapper class for FindText https://www.autohotkey.com/boards/viewtopic.php?f=83&t=135206
		- Maybe use iseahound's ImagePut https://www.autohotkey.com/boards/viewtopic.php?f=83&t=76633
	* Custom toggle icons
	 	- GpGFX modern replacement for Gdiplus lib? https://www.autohotkey.com/boards/viewtopic.php?f=83&t=136401
*/

#Requires AutoHotkey v2
#SingleInstance Force  ; only allow one running instance per user
#Include %A_ScriptDir%\lib\
CoordMode("Mouse","Screen")

MonitorGetWorkArea(,&X,&Y,&W,&H)
scr:={X: X ,Y: Y, W: W, H: H,															; Screen dimensions
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
calArray := [scr.W//2 -50,scr.W//2 +50]													; Array of X positions
mLast := {X:0,Y:scr.H//2}																; To store mouse X,Y coords
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
	phase.Title := "TC's Cal Meas Tool"

	/*	Main GUI buttons
	*/
	phase.AddCheckbox(,"Calipers")
			.OnEvent("Click",toggleCaliper)
	phase.AddCheckbox("x100 yP Disabled","March out")
			.OnEvent("Click",toggleMarch)
	phase.AddButton("x10 Disabled","Calibrate")
			.OnEvent("Click",btnCalibrate)
	phase.AddButton("x100 yP Disabled","Calculate")
			.OnEvent("Click",btnCalculate)
	
	/*	These elements will be hidden until CALCULATE is toggled 
	*/
	phase.AddText("R2 X10","")
	phase.AddButton("w50 x30","R-R   =")
			.OnEvent("Click",btnValues)
			resRR := phase.AddText("w50 x90 yP+4",valRR)
	phase.AddButton("w50 x30","Q-T   =")
			.OnEvent("Click",btnValues)
			resQT := phase.AddText("w50 x90 yP+4",valQT)
	phase.AddButton("w50 x30","QTc =")
			.OnEvent("Click",btnValues)
			resQTc := phase.AddText("w50 x90 yP+4",valQTc)
	
	phase.Show("x" scr.W * 0.8 " h60")
	phase.OnEvent("Close",phaseClose)
		
	A_IconTip := "COMET"
	tray := A_TrayMenu
	tray.Delete()
	tray.Add("About...",menuAbout)
	tray.Add("Instructions",menuInstr)
	tray.Add("Quit",(*)=>ExitApp())

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
		calState.Active := phase["Calipers"].Value
		calArray := [calArray[1],calArray[2]]											; Whether opening or closing
		Gdip_GraphicsClear(GdipOBJ.G)													; reset calArray and bitmap

		if (calState.Active) {
			mouseCoord()
			; scaleTooltip()
			drawCalipers()																; Redraw calipers
			phase["March"].Enabled := true
			phase["Calibrate"].Enabled := true
			phase["Calculate"].Enabled := true
		} else {
			UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)		; Clear bitmap
			ToolTip()
			phase["March"].Enabled := false
			phase["Calibrate"].Enabled := false
			phase["Calculate"].Enabled := false
		}
	}

	toggleMarch(*) {
		calState.March := phase["March"].Value
		calArray := [calArray[1],calArray[2]]
		drawCalipers()
	}

	btnCalibrate(*) {
		phase.Hide()
		Calibrate()
		phase.Show()
	}

	btnCalculate(*) {
		btnCalc := !btnCalc
		if (btnCalc) {
			phase.Show("AutoSize")														; Extended GUI

		} else {
			phase.Show("h60")															; Minimal GUI
		}

	}
	btnValues(btn,*) {																	; Act on calculate value buttons
		if !(scale) {
			MsgBox("Must calibrate first!","COMET error")
			return
		}
		x := btn.Text
		switch
		{
		case (x~="R-R"): 																; R-R button
			valRR := Round(calDiff()/scale)
			resRR.Text := valRR " ms"
		case (x~="Q-T"): 																; Q-T button
			valQT := Round(calDiff()/scale)
			resQT.Text := valQT " ms"
		case (x~="QTc"): 																; QTc button
			valQTc := Round(valQT/Sqrt(valRR/1000))
			resQTc.Text := valQTc " ms"
		}
	}
}
menuAbout(*) {
	about := Gui()
	about.w := 300
	about.Opt("+AlwaysOnTop -SysMenu -Caption")
	about.pic := about.AddPicture("w64",
		FileExist("comet.exe") ? "comet.exe" : "")
	about.txt1 := about.AddText("",
			"[C]aliper [O]n-screen [ME]asurement [T]ool"
			)
	about.txt2 := about.AddText("Center",
			"Electronic Screen Calipers`n"
			"`"Care enough to measure.`"`n`n"
			)
	about.txt3 := about.AddText("Center","COMET v2.0`n(c)2025 Terrence Chun, MD")
	about.OK := about.AddButton("","OK")
	about.OK.OnEvent("Click", (*)=>about.Destroy())
	about.Show("Hide w" about.w)

	centerCtrl(about.pic)
	centerCtrl(about.txt1)
	centerCtrl(about.txt2)
	centerCtrl(about.txt3)
	centerCtrl(about.OK)
	about.Show()
	return

	centerCtrl(ctl) {
		ControlGetPos(,,&w,,ctl)
		ControlMove((about.w-w)//2,,,,ctl)
	}
}
menuInstr(*) {
	txt := "[ ] Calipers`n"
		. "    Toggles calipers on and off`n"
		. "    You can resize by dragging the L or R caliper`n`n"
		. "[ ] March out`n"
		. "    Toggles the `"march out`" function`n"
		. "    You can drag individual calipers to fine-tune markings`n`n"
		. "[Calibrate]`n"
		. "    Move the calipers to desired position (1000 [5 big boxes],`n"
		. "    2000 [10 big boxes], or 3000 [15 big boxes] ms),`n"
		. "    then click here to set the calibration.`n`n"
		. "[Calculate]`n"
		. "    Drops a calculator for QTc`n"
		. "    Draw a caliper, then click each button to insert values`n"
		. "    and to calculate QTc"
	MsgBox(txt,"Instructions")
}

; Calibration GUI to calculate scale
Calibrate() {
	global calArray, scale, mLast

	asc := [
		"|<tick_B>*150$25.01k000s000Q000C00070003U001k000s000Q07zzzw0001",
		"|<tick_T>*160$16.003zzk200Q01k0700Q01k0700Q01k070082",
		"|<grid1_3>*223$300.JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ000000000000000040000000000000000E0000000000000001000E004001000E004001000E004001000E004001000E004001000000000000000040000000000000000E00000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F000000000000000040000000000000000E0000000000000001000E004001000E004001000E004001000E004001000E004001000000000000000040000000000000000E00000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F000000000000000040000000000000000E0000000000000001000E004001000E004001000E004001000E004001000E004001000000000000000040000000000000000E00000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F000000000000000040000000000000000E0000000000000001000E004001000E004001000E004001000E004001000E004001000000000000000040000000000000000E00000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F000000000000000040000000000000000E0000000000000001000E004001000E004001000E004001000E004001000E004001000000000000000040000000000000000E6",
		"|<grid2_3>*223$300.JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ00000000000000000000000000000000000000000000000000000E004001000E004001000E004001000E004001000E004001000000000000000000000000000000000000000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F00000000000000000000000000000000000000000000000000000E004001000E004001000E004001000E004001000E004001000000000000000000000000000000000000000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F00000000000000000000000000000000000000000000000000000E004001000E004001000E004001000E004001000E004001000000000000000000000000000000000000000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F00000000000000000000000000000000000000000000000000000E004001000E004001000E004001000E004001000E004001000000000000000000000000000000000000000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F00000000000000000000000000000000000000000000000000000E004001000E004001000E004001000E004001000E004001U",
		"|<grid1_2>*223$200.JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJE000000000000000100000000000000004001000E004001000E004001000E004001000000000000000040000000000000000F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F40000000000000000E0000000000000001000E004001000E004001000E004001000E000000000000000100000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F000000000000000040000000000000000E004001000E004001000E004001000E0040000000000000000E00000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4E000000000000000100000000000000004001000E004001000E004001000E004001000000000000000040000000000000000F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F40000000000000000E0000000000000001000E004001000E004001000E004001000E000000000000000100000000000000006",
		"|<grid2_2>*223$200.JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJE000000000000000000000000000000000001000E004001000E004001000E00400100000000000000000000000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4000000000000000000000000000000000000E004001000E004001000E004001000E000000000000000000000000000000000F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F0000000000000000000000000000000000004001000E004001000E004001000E0040000000000000000000000000000000004F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4E000000000000000000000000000000000001000E004001000E004001000E00400100000000000000000000000000000000014F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4000000000000000000000000000000000000E004001000E004001000E004001000E000000000000000000000000000000002",
		"|<grid1_1>*223$100.JJJJJJJJJJJJJJJJI0000000000000000E004001000E00400100000000000000004F4F4F4F4F4F4F4F4E0000000000000001000E004001000E0040000000000000000F4F4F4F4F4F4F4F4F00000000000000004001000E004001000E00000000000000014F4F4F4F4F4F4F4F40000000000000000E004001000E00400100000000000000004F4F4F4F4F4F4F4F4E0000000000000001000E004001000E0040000000000000000M",
		"|<grid2_1>*223$100.JJJJJJJJJJJJJJJJI00000000000000000004001000E00400100000000000000000F4F4F4F4F4F4F4F4E0000000000000000000E004001000E004000000000000000014F4F4F4F4F4F4F4F00000000000000000001000E004001000E00000000000000004F4F4F4F4F4F4F4F400000000000000000004001000E00400100000000000000000F4F4F4F4F4F4F4F4E0000000000000000000E004001000E00400000000000000008"
		]
		
	if (duration:=findTick()) {
		chk:=MsgBox("Is this " duration " sec?","Auto calibration","YesNo")
		if (chk="Yes") {
			ms := duration*1000
			cWinTooltip()
			return
		}
	}

	cWin := Gui()
	cWin.AddText("w200 Center","Select calibration measurement")
	cWin.AddButton("w200","1000 ms (good)").OnEvent("Click",cBtnClicked)
	cWin.AddButton("w200","2000 ms (better)").OnEvent("Click",cBtnClicked)
	cWin.AddButton("w200","3000 ms (best)").OnEvent("Click",cBtnClicked)
	cWin.Title := "Calibrate"
	cWin.OnEvent("Close",cWinClose)
	cWin.Opt("+AlwaysOnTop -MaximizeBox -MinimizeBox")
	cWin.Show("Center Autosize")
	ms := 0

	WinWaitClose("Calibrate")
	cWinTooltip()
	Return
	
	cWinTooltip() {
		if (ms) {
			dx := calDiff()
			scale := dx/ms
			MouseMove(calArray[2],mLast.Y)
			scaleTooltip() 
		}
	}

	cBtnClicked(Button,*) {
		x := Button.Text
		Switch {
			case x~="1000": 
				ms := 1000
			case x~="2000": 
				ms := 2000
			case x~="3000": 
				ms := 3000
		}
		cWin.Destroy()
	}
	
	cWinClose(*) {
		return
	}

	findTick(*) {
		Gdip_GraphicsClear(GdipOBJ.G)
		UpdateLayeredWindow(GdipOBJ.hwnd, GdipOBJ.hdc,scr.X,scr.Y,scr.W,scr.H)
		ToolTip()

		for key,val in asc
		{
			if (duration:=scaleTick(val)) {
				drawCalipers()
				return duration
			}
		}
		drawCalipers()
		return false
	}
	scaleTick(text) {
		loop 4
		{
			scale := 0.1*(A_Index-1)+1
			RegExMatch(text,"^\|\<(.*?)\>",&label)
			ok:=FindText(&X, &Y, 0, 0, scr.W, scr.H, 0.1, 0, text,,,,,,,scale,scale)
			if (ok=0) {
				return false
			}
			if InStr(label[1],"tick") {
				if (ok.Length=1) {
					return false
				}
				calArray[1]:=ok[1].x
				calArray[2]:=ok[2].x
				return 3
			}
			if InStr(label[1],"grid") {
				RegExMatch(label[1],"_(\d)$",&duration)
				calArray[1]:=ok[1].1
				calArray[2]:=ok[1].1 + ok[1].3
				return duration[1]
			}
		}
		return false
	}
}
;#endregion

;#region === CALIPER FUNCTIONS =========================================================

; Drag or move calipers when click on V or H line
clickCaliper() {
	global calState

	mPos := mouseCoord()
	if (calState.Best) {																; Best V value from WM_SETCURSOR
		calState.Drag := true
		SetTimer(dragCaliper,calState.refresh)
	} else {																			; Otherwise grabbed H bar
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

	grip:=FindClosest(mLast.X)															; Recheck each time, as calArray changes during March
	mPos := mouseCoord()

	if (grip>2) {
		dx := calDiff()																	; Store X1-X2
		fullX := Abs(calArray[grip] - calArray[1])										; Full distance from X1-grip
		newX := Abs(mPos.X - calArray[1])												; Distance from X1-newX
		factor := newX/fullX															; Ratio of new/old
		calArray[2] := (dx*factor) + calArray[1]										; Adjust new X1-X2
	} else {
		calArray[grip] := mPos.X														; If X1 or X2, just move it
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
	reorderCalipers()
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
 		calArray[key] += mPos.dx														; Adjust all by mPos.dx
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

	if (calArray[1] > calArray[2]) {
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

	return Abs(calArray[2]-calArray[1])
}
;#endregion

;#region === WINDOWS BUTTON HANDLING =================================================== 

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
	MouseGetPos(,,&ui,&mb)
	if (ui = GdipOBJ.hwnd) {															; LMB down on GUI
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
#Include FindText_v2.ahk
