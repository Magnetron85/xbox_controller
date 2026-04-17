; State-diff to semantic events.
; Emits: button_down, button_up, tap, hold, double_tap,
;        stick_vector (continuous), trigger_level (continuous).
;
; Tap/hold discrimination:
;   - on down: remember time; start 500 ms hold window
;   - if up before window: emit "tap"
;   - if held past window: emit "hold" exactly once; subsequent up is "button_up" only
; Double-tap:
;   - if a tap occurs within double_window_ms (default 300) of a prior tap
;     on the same button, emit "double_tap" instead of second "tap"

class EventEmitter {
    prev := ""             ; previous XInput state Map
    downTime := Map()      ; bitflag -> tick count when pressed
    holdFired := Map()     ; bitflag -> true if "hold" already emitted
    lastTapTime := Map()   ; bitflag -> tick of last "tap" (for double detection)
    holdMs := 500
    doubleMs := 300
    stickLDir := ""        ; "up"|"down"|"left"|"right" latched direction
    stickLThreshold := 0.5
    stickLRelease := 0.2
    subscribers := []

    Subscribe(fn) {
        this.subscribers.Push(fn)
    }

    _Emit(eventName, data) {
        for fn in this.subscribers
            fn.Call(eventName, data)
    }

    Update(state) {
        if (!this.prev) {
            this.prev := state
            return
        }
        now := A_TickCount

        prevBtns := this.prev["buttons"]
        curBtns  := state["buttons"]
        for flag in XI_ALL_BUTTONS {
            wasDown := prevBtns & flag
            isDown  := curBtns & flag
            name := XI_BUTTON_NAMES[flag]

            if (isDown && !wasDown) {
                this.downTime[flag] := now
                this.holdFired[flag] := false
                this._Emit("button_down", Map("button", name))
            } else if (!isDown && wasDown) {
                held := now - (this.downTime.Has(flag) ? this.downTime[flag] : now)
                this._Emit("button_up", Map("button", name, "held_ms", held))
                if (!this.holdFired.Get(flag, false)) {
                    ; it's a tap — maybe a double tap
                    last := this.lastTapTime.Get(flag, 0)
                    if (last && (now - last) <= this.doubleMs) {
                        this._Emit("double_tap", Map("button", name))
                        this.lastTapTime[flag] := 0
                    } else {
                        this._Emit("tap", Map("button", name))
                        this.lastTapTime[flag] := now
                    }
                }
            } else if (isDown && wasDown) {
                if (!this.holdFired.Get(flag, false)) {
                    heldFor := now - this.downTime.Get(flag, now)
                    if (heldFor >= this.holdMs) {
                        this.holdFired[flag] := true
                        this._Emit("hold", Map("button", name))
                    }
                }
            }
        }

        ; Continuous emits for sticks and triggers.
        this._Emit("stick_l", Map("x", state["lx"], "y", state["ly"]))
        this._Emit("stick_r", Map("x", state["rx"], "y", state["ry"]))
        this._Emit("trigger_l", Map("level", state["ltrig"]))
        this._Emit("trigger_r", Map("level", state["rtrig"]))

        ; Discrete cardinal events for left stick — fires once per engagement.
        this._UpdateStickLDirection(state["lx"], state["ly"])

        this.prev := state
    }

    _UpdateStickLDirection(x, y) {
        mag := Sqrt(x * x + y * y)
        if (mag < this.stickLRelease) {
            this.stickLDir := ""
            return
        }
        if (mag < this.stickLThreshold)
            return
        ; Determine direction from angle — use x/y dominance.
        dir := Abs(x) > Abs(y)
            ? (x > 0 ? "right" : "left")
            : (y > 0 ? "up"    : "down")
        if (dir = this.stickLDir)
            return
        this.stickLDir := dir
        this._Emit("stick_l_dir", Map("dir", dir))
    }
}
