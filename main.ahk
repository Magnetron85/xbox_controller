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
global g_chords
global g_chord_press_time := Map()      ; button name -> tickcount when pressed (cleared on release)
global g_chord_consumed := Map()        ; button name -> true when chord just fired; suppresses next tap/hold/double
global g_chord_window_ms := 200
global g_chord_hold_ms := 500           ; how long both buttons must be held for chord "hold"
global g_chord_hold_warn_ms := 150      ; delay before warn haptic plays (quick taps stay silent)
global g_active_chord_str := ""         ; "ls_click+rs_click" while a hold-capable chord is in flight
global g_active_chord_start := 0
global g_active_chord_hold_fired := false
global g_active_chord_warn_played := false
global g_stick_chord_state := "idle"    ; "idle" | "up" | "down"
global g_stick_chord_engage := 0.6
global g_stick_chord_release := 0.3
global g_zoom_active := false
global g_zoom_direction := ""           ; "in" or "out"
global g_zoom_drag_speed := 500         ; px/sec at full deflection
global g_zoom_restore_cursor := true
global g_zoom_start_x := 0
global g_zoom_start_y := 0

; --- load profile + defaults ---
bundle := LoadProfileBundle(PROFILE_NAME)
g_profile := bundle["profile"]
g_targets := bundle["targets"]
g_keymaps := bundle["keymaps"]
hapticPatterns := bundle["haptics"]

g_prefs := g_profile.Has("preferences") ? g_profile["preferences"] : Map()
g_bindings := g_profile.Has("bindings") ? g_profile["bindings"] : Map()
g_axis_bindings := g_profile.Has("axis_bindings") ? g_profile["axis_bindings"] : Map()
g_chords := g_profile.Has("chords") ? g_profile["chords"] : Map()
if g_prefs.Has("chord_window_ms")
    g_chord_window_ms := g_prefs["chord_window_ms"]
if g_prefs.Has("chord_hold_ms")
    g_chord_hold_ms := g_prefs["chord_hold_ms"]
if g_prefs.Has("chord_hold_warn_ms")
    g_chord_hold_warn_ms := g_prefs["chord_hold_warn_ms"]
if g_prefs.Has("stick_chord_engage")
    g_stick_chord_engage := g_prefs["stick_chord_engage"]
if g_prefs.Has("stick_chord_release")
    g_stick_chord_release := g_prefs["stick_chord_release"]
if g_prefs.Has("zoom_drag_speed_px_per_sec")
    g_zoom_drag_speed := g_prefs["zoom_drag_speed_px_per_sec"]
if g_prefs.Has("zoom_drag_restore_cursor")
    g_zoom_restore_cursor := g_prefs["zoom_drag_restore_cursor"]

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
g_dispatcher.RegisterScript("hud_toggle",            HudToggle)
g_dispatcher.RegisterScript("wl_drag_begin",         WlDragBegin)
g_dispatcher.RegisterScript("wl_drag_end",           WlDragEnd)
g_dispatcher.RegisterScript("ps_visibility_toggle",  PsVisibilityToggle)

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

; Minimize PowerScribe if visible, else restore + activate. Mirrors v1 PS360 ^m hotkey.
PsVisibilityToggle() {
    global g_targets, g_hud
    if (!g_targets.Has("powerscribe")) {
        g_hud.Log("ps_visibility_toggle (no powerscribe target)")
        return
    }
    for wintitle in g_targets["powerscribe"]["win_match"] {
        if WinExist(wintitle) {
            state := WinGetMinMax(wintitle)
            if (state = -1) {
                WinRestore(wintitle)
                WinActivate(wintitle)
                g_hud.ShowAction("PS shown")
            } else {
                WinMinimize(wintitle)
                g_hud.ShowAction("PS hidden")
            }
            return
        }
    }
    g_hud.Log("ps_visibility_toggle (powerscribe not found)")
}

; --- event wiring ---
g_emitter := EventEmitter()

; Chord config may be a plain action string (tap-only, fires immediately)
; or a Map with any of: "tap", "hold", "hold_warn_haptic".
; Returns the normalized Map form.
NormalizeChordConfig(cfg) {
    if (Type(cfg) = "Map")
        return cfg
    m := Map()
    m["tap"] := cfg
    return m
}

IsChordMember(btn, chord_str) {
    for m in StrSplit(chord_str, "+")
        if (m = btn)
            return true
    return false
}

; Called from button_down. If a chord is now satisfied (this button + other members
; all pressed within the chord window), fire it or start its hold state machine.
; Marks all chord members as "consumed" so their individual tap/hold/double/on_down/
; on_up bindings stay silent until the next clean press of each button.
CheckChords(triggerBtn) {
    global g_chords, g_chord_press_time, g_chord_consumed, g_chord_window_ms, g_dispatcher
    global g_active_chord_str, g_active_chord_start, g_active_chord_hold_fired, g_active_chord_warn_played
    now := A_TickCount
    for chord_str, raw in g_chords {
        members := StrSplit(chord_str, "+")
        if (members.Length < 2)
            continue
        if (!IsChordMember(triggerBtn, chord_str))
            continue
        all_in := true
        for m in members {
            if (!g_chord_press_time.Has(m) || now - g_chord_press_time[m] > g_chord_window_ms) {
                all_in := false
                break
            }
        }
        if (!all_in)
            continue

        config := NormalizeChordConfig(raw)
        for m in members
            g_chord_consumed[m] := true

        if (config.Has("hold")) {
            ; Hold-capable chord: wait. Poll() fires the hold action once held past
            ; g_chord_hold_ms; button_up of any member fires the tap action if the
            ; hold hasn't fired yet.
            g_active_chord_str := chord_str
            g_active_chord_start := now
            g_active_chord_hold_fired := false
            g_active_chord_warn_played := false
        } else if (config.Has("tap")) {
            ; Simple tap-only chord: fire immediately, no hold tracking.
            g_dispatcher.Invoke(config["tap"], "chord")
        }
        return true
    }
    return false
}

; Called every Poll. While a hold-capable chord is latched, time it out: play the
; warn haptic at g_chord_hold_warn_ms, fire the hold action at g_chord_hold_ms.
TickChordHold() {
    global g_active_chord_str, g_active_chord_start, g_active_chord_hold_fired, g_active_chord_warn_played
    global g_chords, g_chord_hold_ms, g_chord_hold_warn_ms, g_haptics, g_dispatcher
    if (g_active_chord_str = "" || g_active_chord_hold_fired)
        return
    config := NormalizeChordConfig(g_chords[g_active_chord_str])
    elapsed := A_TickCount - g_active_chord_start
    if (config.Has("hold_warn_haptic") && !g_active_chord_warn_played && elapsed >= g_chord_hold_warn_ms) {
        g_haptics.Play(config["hold_warn_haptic"])
        g_active_chord_warn_played := true
    }
    if (config.Has("hold") && elapsed >= g_chord_hold_ms) {
        g_dispatcher.Invoke(config["hold"], "chord_hold")
        g_active_chord_hold_fired := true
    }
}

HandleEvent(eventName, data) {
    global g_bindings, g_axis_bindings, g_dispatcher, g_haptics
    global g_chord_press_time, g_chord_consumed
    switch eventName {
        case "stick_r", "stick_l", "trigger_l", "trigger_r":
            return
        case "stick_l_dir":
            key := "stick_l_" data["dir"]
            if g_axis_bindings.Has(key)
                g_dispatcher.Invoke(g_axis_bindings[key], "tap")
        case "button_down":
            btn := data["button"]
            ; Fresh press: clear any stale consumed flag from a prior chord cycle.
            if (g_chord_consumed.Has(btn))
                g_chord_consumed.Delete(btn)
            g_chord_press_time[btn] := A_TickCount
            chord_fired := CheckChords(btn)
            if (chord_fired)
                return  ; chord owns this press; skip on_down + haptic warn
            if g_bindings.Has(btn) {
                bind := g_bindings[btn]
                if bind.Has("hold_warn_haptic")
                    g_haptics.Play(bind["hold_warn_haptic"])
                if bind.Has("on_down")
                    g_dispatcher.Invoke(bind["on_down"], "press")
            }
        case "button_up":
            btn := data["button"]
            if (g_chord_press_time.Has(btn))
                g_chord_press_time.Delete(btn)
            ; If this is a hold-capable chord in flight and we release before the
            ; hold fired, fire the chord's tap action.
            if (g_active_chord_str != "" && IsChordMember(btn, g_active_chord_str)) {
                if (!g_active_chord_hold_fired) {
                    config := NormalizeChordConfig(g_chords[g_active_chord_str])
                    if (config.Has("tap"))
                        g_dispatcher.Invoke(config["tap"], "chord")
                }
                g_active_chord_str := ""
                g_active_chord_hold_fired := false
                g_active_chord_warn_played := false
            }
            if (g_chord_consumed.Has(btn))
                return  ; chord ate this; tap/hold/double will also be suppressed below
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
            if (g_chord_consumed.Has(btn)) {
                g_chord_consumed.Delete(btn)
                return
            }
            if g_bindings.Has(btn) && g_bindings[btn].Has("tap")
                g_dispatcher.Invoke(g_bindings[btn]["tap"], "tap")
        case "hold":
            btn := data["button"]
            if (g_chord_consumed.Has(btn))
                return  ; keep flag set; button still down, button_up will see it
            if g_bindings.Has(btn) && g_bindings[btn].Has("hold")
                g_dispatcher.Invoke(g_bindings[btn]["hold"], "hold")
        case "double_tap":
            btn := data["button"]
            if (g_chord_consumed.Has(btn)) {
                g_chord_consumed.Delete(btn)
                return
            }
            if g_bindings.Has(btn) && g_bindings[btn].Has("double")
                g_dispatcher.Invoke(g_bindings[btn]["double"], "double")
    }
}

g_emitter.Subscribe(HandleEvent)

; --- InteleViewer-style zoom: middle-mouse-button drag.
; Press both sticks up = MMB down + drag cursor up (zoom in).
; Press both sticks down = MMB down + drag cursor down (zoom out).
; Drag rate is proportional to stick deflection. Cursor restored on release if pref set.

ZoomDragBegin(direction) {
    global g_zoom_active, g_zoom_direction, g_zoom_start_x, g_zoom_start_y, g_targets, SIMULATE, g_hud
    if (g_zoom_active)
        return
    g_zoom_direction := direction
    g_zoom_active := true
    if (!SIMULATE && g_targets.Has("pacs")) {
        for wintitle in g_targets["pacs"]["win_match"] {
            if WinExist(wintitle) {
                if (!WinActive(wintitle)) {
                    WinActivate(wintitle)
                    Sleep(20)
                }
                break
            }
        }
    }
    MouseGetPos(&x, &y)
    g_zoom_start_x := x
    g_zoom_start_y := y
    if (!SIMULATE)
        Click("Middle Down")
    g_hud.ShowAction(direction = "in" ? "zoom in" : "zoom out")
}

ZoomDragTick(magY) {
    global g_zoom_active, g_zoom_direction, g_zoom_drag_speed, POLL_MS, SIMULATE
    if (!g_zoom_active || SIMULATE)
        return
    delta := g_zoom_drag_speed * magY * (POLL_MS / 1000.0)
    MouseGetPos(&x, &y)
    new_y := (g_zoom_direction = "in") ? y - delta : y + delta
    DllCall("SetCursorPos", "Int", x, "Int", Round(new_y))
}

ZoomDragEnd() {
    global g_zoom_active, g_zoom_start_x, g_zoom_start_y, g_zoom_restore_cursor, SIMULATE, g_hud
    if (!g_zoom_active)
        return
    g_zoom_active := false
    if (!SIMULATE) {
        Click("Middle Up")
        if (g_zoom_restore_cursor)
            DllCall("SetCursorPos", "Int", g_zoom_start_x, "Int", g_zoom_start_y)
    }
    g_hud.ShowAction("zoom done")
}

; --- stick chord: both sticks tilted same direction past threshold.
; Returns true while latched so the caller can suppress cursor and left-stick-dir.
DetectStickChord(state) {
    global g_stick_chord_state, g_stick_chord_engage, g_stick_chord_release
    ly := state["ly"]
    ry := state["ry"]
    mag_l := Sqrt(state["lx"]**2 + ly**2)
    mag_r := Sqrt(state["rx"]**2 + ry**2)

    if (g_stick_chord_state = "idle") {
        if (ly > g_stick_chord_engage && ry > g_stick_chord_engage) {
            g_stick_chord_state := "up"
            ZoomDragBegin("in")
            return true
        }
        if (ly < -g_stick_chord_engage && ry < -g_stick_chord_engage) {
            g_stick_chord_state := "down"
            ZoomDragBegin("out")
            return true
        }
        return false
    }

    if (mag_l < g_stick_chord_release && mag_r < g_stick_chord_release) {
        g_stick_chord_state := "idle"
        ZoomDragEnd()
        return false
    }
    return true
}

; --- polling loop ---
global POLL_MS := 8  ; ~125 Hz
Poll() {
    global g_emitter, g_mouse
    state := XInput.GetState(0)
    if (!state)
        return
    inStickChord := DetectStickChord(state)
    if (inStickChord) {
        magY := (Abs(state["ly"]) + Abs(state["ry"])) / 2.0
        ZoomDragTick(magY)
    } else {
        g_mouse.UpdateStick(state["rx"], state["ry"])
    }
    g_mouse.UpdateScrollTriggers(state["ltrig"], state["rtrig"])
    g_emitter.Update(state, inStickChord)
    TickChordHold()
}
SetTimer(Poll, POLL_MS)

g_hud.Log(SIMULATE ? "started in SIMULATE mode" : "started")
g_hud.Log("press Ctrl+Shift+Esc to exit")

; Global exit hotkey (works even when focus is elsewhere)
^+Esc::ExitApp()
