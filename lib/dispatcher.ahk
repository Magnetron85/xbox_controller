; Action dispatcher — the core routing layer.
; Knows targets (PACS app, PowerScribe app), activates windows, sends keys, plays haptics.
; Script-internal actions (hud_toggle, precision_toggle, etc.) route to local handlers
; instead of sending keystrokes.

class Dispatcher {
    targets := ""       ; Map name -> { win_match: [...], exe: "..." }
    keymaps := ""       ; Map action -> { target: "...", keys: "...", haptic: "..." }
    simulate := false
    hud := ""
    haptics := ""
    mouse := ""
    scriptHandlers := Map()
    cycleIdx := Map()
    lastActivated := ""
    lastActivatedAt := 0

    __New(profile, keymaps, targets, hud, haptics, simulate := false) {
        this.targets := targets
        this.keymaps := keymaps
        this.hud := hud
        this.haptics := haptics
        this.simulate := simulate
    }

    SetMouse(mouse) {
        this.mouse := mouse
    }

    RegisterScript(action, fn) {
        this.scriptHandlers[action] := fn
    }

    Invoke(action, source := "tap") {
        if (!this.keymaps.Has(action)) {
            this.hud.Log("no mapping: " action)
            return
        }
        mapping := this.keymaps[action]
        target := mapping.Has("target") ? mapping["target"] : "none"
        keys := mapping.Has("keys") ? mapping["keys"] : ""
        haptic := mapping.Has("haptic") ? mapping["haptic"] : ""
        if (mapping.Has("cycle")) {
            cycle := mapping["cycle"]
            idx := this.cycleIdx.Get(action, 0)
            keys := cycle[Mod(idx, cycle.Length) + 1]
            this.cycleIdx[action] := idx + 1
        }

        ; Script-internal target: run a local handler.
        if (target = "script") {
            if (this.scriptHandlers.Has(action)) {
                (this.scriptHandlers[action]).Call()
                this.hud.ShowAction(action)
                if (haptic != "")
                    this.haptics.Play(haptic)
            } else {
                this.hud.Log("no script handler: " action)
            }
            return
        }

        if (target = "mouse") {
            this._DoMouse(action, source)
            return
        }

        if (target = "none" || keys = "") {
            this.hud.Log("noop: " action)
            return
        }

        ; App-routed: activate target and send.
        if (!this._ActivateTarget(target)) {
            this.hud.ShowAction(action " (target " target " not found)")
            return
        }
        this._SendKeys(target, keys)
        label := mapping.Has("label") ? mapping["label"] : action
        if (source = "continuous") {
            ; don't spam HUD action on every scroll tick
        } else {
            this.hud.ShowAction(label)
        }
        if (haptic != "" && source != "continuous")
            this.haptics.Play(haptic)
    }

    _DoMouse(action, source) {
        if (!this.mouse) {
            this.hud.Log("mouse not ready for " action)
            return
        }
        switch action {
            case "mouse_lclick":     this.mouse.Click("left")
            case "mouse_rclick":     this.mouse.Click("right")
            case "mouse_mclick":     this.mouse.Click("middle")
            case "mouse_ldown":      this.mouse.ClickDown("left")
            case "mouse_lup":        this.mouse.ClickUp("left")
            case "precision_toggle": this.mouse.TogglePrecision()
            default:                 this.hud.Log("unknown mouse action: " action)
        }
    }

    _ActivateTarget(targetName) {
        if (!this.targets.Has(targetName))
            return false
        t := this.targets[targetName]
        matchers := t["win_match"]
        for wintitle in matchers {
            if WinExist(wintitle) {
                ; Only switch if it's not already the active window.
                if (WinActive(wintitle)) {
                    return true
                }
                WinActivate(wintitle)
                ; brief pause for focus to take hold; but avoid on scroll-continuous bursts
                now := A_TickCount
                if (targetName != this.lastActivated || now - this.lastActivatedAt > 200) {
                    Sleep(40)
                }
                this.lastActivated := targetName
                this.lastActivatedAt := now
                return true
            }
        }
        return false
    }

    _SendKeys(targetName, keys) {
        if (this.simulate) {
            this.hud.Log("[SIM → " targetName "] " keys)
            return
        }
        ; Wheel events are not reliably sent via SendInput; route them through Click.
        if (keys = "{WheelUp}") {
            Click("WheelUp")
            return
        }
        if (keys = "{WheelDown}") {
            Click("WheelDown")
            return
        }
        SendInput(keys)
    }
}
