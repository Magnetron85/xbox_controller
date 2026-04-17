#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")

; Be DPI-aware so monitor bounds, Gui placement, and SetCursorPos all agree
; on physical pixels even on scaled displays.
DllCall("SetProcessDPIAware")

#Include lib\json.ahk
#Include lib\xinput.ahk
#Include lib\events.ahk
#Include lib\hud.ahk
#Include lib\haptics.ahk
#Include lib\mouse.ahk
#Include lib\dispatcher.ahk
#Include lib\profile.ahk

; Command line: --simulate to log keystrokes instead of sending;
;               --profile <name> to load profiles/<name>.json (default: "mike")
global SIMULATE := false
global PROFILE_NAME := "mike"
parseArgs() {
    global SIMULATE, PROFILE_NAME
    i := 1
    while (i <= A_Args.Length) {
        arg := A_Args[i]
        if (arg = "--simulate")
            SIMULATE := true
        else if (arg = "--profile" && i < A_Args.Length) {
            i++
            PROFILE_NAME := A_Args[i]
        }
        i++
    }
}
parseArgs()

; AHK v2 is case-insensitive, so class names (Hud, Dispatcher, Haptics, MouseController,
; EventEmitter) would collide with same-named variables. Globals here get a g_ prefix.
global g_bindings, g_axis_bindings, g_targets, g_keymaps, g_profile, g_prefs
global g_hud, g_dispatcher, g_haptics, g_mouse, g_emitter, g_wl_active

; --- load profile + defaults ---
bundle := LoadProfileBundle(PROFILE_NAME)
g_profile := bundle["profile"]
g_targets := bundle["targets"]
g_keymaps := bundle["keymaps"]
hapticPatterns := bundle["haptics"]

g_prefs := g_profile.Has("preferences") ? g_profile["preferences"] : Map()
g_bindings := g_profile.Has("bindings") ? g_profile["bindings"] : Map()
g_axis_bindings := g_profile.Has("axis_bindings") ? g_profile["axis_bindings"] : Map()

; --- init subsystems ---
if (!XInput.Init()) {
    MsgBox("Could not load XInput DLL. Aborting.", "xbox_controller", "Icon!")
    ExitApp()
}

g_hud := Hud(g_prefs, SIMULATE)
g_hud.SetProfile(g_profile.Has("name") ? g_profile["name"] : PROFILE_NAME)
g_hud.SetFlag("precision", false)

g_haptics := LoadHapticsFromJson(hapticPatterns)

g_dispatcher := Dispatcher(g_profile, g_keymaps, g_targets, g_hud, g_haptics, SIMULATE)

g_mouse := MouseController(g_prefs, g_haptics, g_hud, g_dispatcher)
g_dispatcher.SetMouse(g_mouse)

; --- script-internal actions ---
g_wl_active := false
g_dispatcher.RegisterScript("hud_toggle",     HudToggle)
g_dispatcher.RegisterScript("wl_drag_begin",  WlDragBegin)
g_dispatcher.RegisterScript("wl_drag_end",    WlDragEnd)

HudToggle() {
    global g_hud
    g_hud.Toggle()
}

WlDragBegin() {
    global g_wl_active, g_targets, SIMULATE, g_hud
    if (g_wl_active)
        return
    for wintitle in g_targets["pacs"]["win_match"] {
        if WinExist(wintitle) {
            WinActivate(wintitle)
            Sleep(40)
            break
        }
    }
    if (!SIMULATE) {
        SendInput("+r")
        Click("Down")
    }
    g_wl_active := true
    g_hud.ShowAction("W/L drag (release LB to exit)")
}

WlDragEnd() {
    global g_wl_active, SIMULATE, g_hud
    if (!g_wl_active)
        return
    if (!SIMULATE) {
        Click("Up")
        SendInput("{Esc}")
    }
    g_wl_active := false
    g_hud.ShowAction("W/L drag ended")
}

; --- event wiring ---
g_emitter := EventEmitter()

HandleEvent(eventName, data) {
    global g_bindings, g_axis_bindings, g_dispatcher, g_haptics
    switch eventName {
        case "stick_r", "stick_l", "trigger_l", "trigger_r":
            ; Continuous axes are polled directly in Poll() — ignore these here.
            return
        case "stick_l_dir":
            key := "stick_l_" data["dir"]
            if g_axis_bindings.Has(key)
                g_dispatcher.Invoke(g_axis_bindings[key], "tap")
        case "button_down":
            btn := data["button"]
            if g_bindings.Has(btn) {
                bind := g_bindings[btn]
                if bind.Has("hold_warn_haptic")
                    g_haptics.Play(bind["hold_warn_haptic"])
                if bind.Has("on_down")
                    g_dispatcher.Invoke(bind["on_down"], "press")
            }
        case "button_up":
            btn := data["button"]
            if g_bindings.Has(btn) {
                bind := g_bindings[btn]
                if (bind.Has("on_up_if_held") && data["held_ms"] >= 500) {
                    g_dispatcher.Invoke(bind["on_up_if_held"], "release")
                }
                if bind.Has("on_up")
                    g_dispatcher.Invoke(bind["on_up"], "release")
            }
        case "tap":
            btn := data["button"]
            if g_bindings.Has(btn) && g_bindings[btn].Has("tap")
                g_dispatcher.Invoke(g_bindings[btn]["tap"], "tap")
        case "hold":
            btn := data["button"]
            if g_bindings.Has(btn) && g_bindings[btn].Has("hold")
                g_dispatcher.Invoke(g_bindings[btn]["hold"], "hold")
        case "double_tap":
            btn := data["button"]
            if g_bindings.Has(btn) && g_bindings[btn].Has("double")
                g_dispatcher.Invoke(g_bindings[btn]["double"], "double")
    }
}

g_emitter.Subscribe(HandleEvent)

; --- polling loop ---
global POLL_MS := 8  ; ~125 Hz
Poll() {
    global g_emitter, g_mouse
    state := XInput.GetState(0)
    if (!state)
        return
    g_mouse.UpdateStick(state["rx"], state["ry"])
    g_mouse.UpdateScrollTriggers(state["ltrig"], state["rtrig"])
    g_emitter.Update(state)
}
SetTimer(Poll, POLL_MS)

g_hud.Log(SIMULATE ? "started in SIMULATE mode" : "started")
g_hud.Log("press Ctrl+Shift+Esc to exit")

; Global exit hotkey (works even when focus is elsewhere)
^+Esc::ExitApp()
