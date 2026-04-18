; Mouse emulation: right stick → cursor, triggers → wheel scroll.
; Precision mode slows cursor to precision_factor × base speed.
; Wheel scroll tick rate is (level^2 * max_rate). Every N wheel ticks, call haptics.

class MouseController {
    maxSpeedPx := 1800
    precisionFactor := 0.15
    deadzone := 0.12
    curve := 2.0
    maxScrollRate := 40
    scrollDeadzone := 0.08
    scrollTicksPerHaptic := 5
    scrollHapticFloor := 0.25   ; min multiplier applied to scroll_tick pattern at slow speeds
    lastMove := 0
    scrollAccum := 0.0
    scrollHapticCount := 0
    lastScrollLevel := 0.0      ; post-deadzone deflection 0..1, used to scale haptic intensity
    precision := false
    haptics := ""
    hud := ""
    dispatcher := ""

    __New(preferences, haptics, hud, dispatcher) {
        this.haptics := haptics
        this.hud := hud
        this.dispatcher := dispatcher
        if preferences.Has("mouse_speed")
            this.maxSpeedPx := preferences["mouse_speed"]
        if preferences.Has("mouse_curve")
            this.curve := preferences["mouse_curve"]
        if preferences.Has("precision_factor")
            this.precisionFactor := preferences["precision_factor"]
        if preferences.Has("scroll_ticks_per_haptic")
            this.scrollTicksPerHaptic := preferences["scroll_ticks_per_haptic"]
        if preferences.Has("max_scroll_rate")
            this.maxScrollRate := preferences["max_scroll_rate"]
        if preferences.Has("scroll_haptic_floor")
            this.scrollHapticFloor := preferences["scroll_haptic_floor"]
        this.lastMove := A_TickCount
    }

    UpdateStick(x, y) {
        now := A_TickCount
        dt := (now - this.lastMove) / 1000.0
        this.lastMove := now
        if (dt > 0.1)
            dt := 0.1

        mag := Sqrt(x * x + y * y)
        if (mag < this.deadzone)
            return
        ; rescale post-deadzone magnitude to 0..1
        rescaled := (mag - this.deadzone) / (1.0 - this.deadzone)
        if (rescaled > 1.0)
            rescaled := 1.0
        ; apply power curve for fine control
        scaledMag := rescaled ** this.curve
        speed := this.maxSpeedPx * (this.precision ? this.precisionFactor : 1.0)
        ; direction
        dx := (x / mag) * scaledMag * speed * dt
        dy := -(y / mag) * scaledMag * speed * dt  ; screen Y inverted vs stick

        MouseGetPos(&cx, &cy)
        DllCall("SetCursorPos", "Int", Round(cx + dx), "Int", Round(cy + dy))
    }

    UpdateScrollTriggers(leftLevel, rightLevel) {
        now := A_TickCount
        dt := (now - this.lastMove) / 1000.0
        if (dt <= 0 || dt > 0.1)
            dt := 0.016

        ; Right trigger scrolls up, left scrolls down. Tiny asymmetry is intentional:
        ; same stick hand on both triggers means user scrubs up with index, down with middle.
        level := 0
        dir := 0
        if (rightLevel > this.scrollDeadzone) {
            level := rightLevel
            dir := +1
        } else if (leftLevel > this.scrollDeadzone) {
            level := leftLevel
            dir := -1
        } else {
            this.scrollAccum := 0
            return
        }
        rescaled := (level - this.scrollDeadzone) / (1.0 - this.scrollDeadzone)
        this.lastScrollLevel := rescaled
        rate := (rescaled ** 2) * this.maxScrollRate
        this.scrollAccum += rate * dt
        while (this.scrollAccum >= 1.0) {
            this.scrollAccum -= 1.0
            this._TickScroll(dir)
        }
    }

    _TickScroll(dir) {
        ; Route through dispatcher so it activates PACS window first.
        this.dispatcher.Invoke(dir > 0 ? "scroll_up" : "scroll_down", "continuous")
        this.scrollHapticCount++
        if (this.scrollHapticCount >= this.scrollTicksPerHaptic) {
            this.scrollHapticCount := 0
            ; Intensity scales with trigger deflection; floor keeps slow ticks perceptible.
            hapticScale := this.scrollHapticFloor + (1.0 - this.scrollHapticFloor) * this.lastScrollLevel
            this.haptics.Play("scroll_tick", hapticScale)
        }
    }

    Click(button) {
        switch button {
            case "left":   Click()
            case "right":  Click("Right")
            case "middle": Click("Middle")
        }
    }

    ClickDown(button) {
        switch button {
            case "left":   Click("Down")
            case "right":  Click("Right Down")
            case "middle": Click("Middle Down")
        }
    }

    ClickUp(button) {
        switch button {
            case "left":   Click("Up")
            case "right":  Click("Right Up")
            case "middle": Click("Middle Up")
        }
    }

    TogglePrecision() {
        this.precision := !this.precision
        this.hud.SetFlag("precision", this.precision)
        this.hud.ShowAction(this.precision ? "Precision ON" : "Precision OFF")
    }

    SetPrecision(on) {
        if (this.precision = on)
            return
        this.precision := on
        this.hud.SetFlag("precision", on)
    }
}
