#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

#Include lib\json.ahk
#Include lib\xinput.ahk

; Raw XInput diagnostic — polls the controller and writes any state change
; to diagnose.log so we can see whether XInput is seeing the device at all.

logPath := A_ScriptDir "\diagnose.log"
if FileExist(logPath)
    FileDelete(logPath)

FileAppend("starting at " FormatTime(, "HH:mm:ss.") A_MSec "`n", logPath)

if (!XInput.Init()) {
    FileAppend("XInput.Init FAILED`n", logPath)
    ExitApp()
}
FileAppend("XInput.Init ok, dll=" XInput.dll "`n", logPath)

global prevButtons := -1
global prevPacket := -1
global polls := 0
global hits := 0

Poll() {
    global prevButtons, prevPacket, polls, hits
    polls++
    ; Probe all 4 XInput slots so we don't assume slot 0.
    state := 0
    slot := -1
    loop 4 {
        s := XInput.GetState(A_Index - 1)
        if (s) {
            state := s
            slot := A_Index - 1
            break
        }
    }
    if (!state) {
        if (Mod(polls, 250) = 0)
            FileAppend(FormatTime(, "HH:mm:ss") " poll#" polls " no controller on any slot`n", A_ScriptDir "\diagnose.log")
        return
    }
    if (hits = 0)
        FileAppend("FIRST HIT on slot " slot "`n", A_ScriptDir "\diagnose.log")
    hits++
    b := state["buttons"]
    p := state["packet"]
    if (b != prevButtons || p != prevPacket) {
        prevButtons := b
        prevPacket := p
        line := FormatTime(, "HH:mm:ss.") A_MSec " packet=" p
               . " buttons=0x" Format("{:04X}", b)
               . " LT=" Round(state["ltrig"] * 100) "%"
               . " RT=" Round(state["rtrig"] * 100) "%"
               . " LS=" Round(state["lx"] * 100) "," Round(state["ly"] * 100)
               . " RS=" Round(state["rx"] * 100) "," Round(state["ry"] * 100)
               . "`n"
        FileAppend(line, A_ScriptDir "\diagnose.log")
    }
}
SetTimer(Poll, 16)
FileAppend("polling at 16ms`n", logPath)

; Also show a tiny always-on-top tooltip so we can confirm the script is alive.
SetTimer(ShowTip, 500)
ShowTip() {
    global polls, hits
    ToolTip("xbc diag: polls=" polls " hits=" hits, 20, 20)
}

^+Esc::ExitApp()
