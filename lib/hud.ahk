; HUD - small overlay. Three modes (set via prefs.hud_mode):
;   "fade"   - hidden at rest; fades in on action, holds, fades out
;   "always" - visible at fixed alpha, action line clears after autoHideMs
;   "off"    - never shown (file log still written)
; Hud-toggle binding flips between the configured visible mode and "off".

class Hud {
    gui := ""
    corner := "bottom-right"
    eventLines := []
    maxLines := 8
    autoHideMs := 3000
    lastActionAt := 0
    simulate := false
    flags := Map("precision", false, "dictate", false)

    hudMode := "fade"
    configuredMode := "fade"
    targetAlpha := 225
    fadeInMs := 120
    holdMs := 1500
    fadeOutMs := 700
    currentAlpha := -1
    shown := false

    __New(preferences, simulate := false) {
        this.simulate := simulate
        if preferences.Has("hud_corner")
            this.corner := preferences["hud_corner"]
        if preferences.Has("hud_autohide_ms")
            this.autoHideMs := preferences["hud_autohide_ms"]
        if preferences.Has("hud_mode")
            this.hudMode := preferences["hud_mode"]
        if preferences.Has("hud_alpha")
            this.targetAlpha := preferences["hud_alpha"]
        if preferences.Has("hud_fade_in_ms")
            this.fadeInMs := preferences["hud_fade_in_ms"]
        if preferences.Has("hud_hold_ms")
            this.holdMs := preferences["hud_hold_ms"]
        if preferences.Has("hud_fade_out_ms")
            this.fadeOutMs := preferences["hud_fade_out_ms"]
        this.configuredMode := this.hudMode
        this._Build()
    }

    _Build() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "XBC HUD")
        this.gui.BackColor := "1E1E1E"
        this.gui.MarginX := 10
        this.gui.MarginY := 8
        this.gui.SetFont("s9 cDCDCDC", "Consolas")

        this.gui.AddText("w360 vProfile xm", "profile: (loading)")
        this.gui.SetFont("s11 cFFD166 bold")
        this.gui.AddText("w360 vAction xm", "-")
        this.gui.SetFont("s9 c8AB4F8", "Consolas")
        this.gui.AddText("w360 vFlags xm", "")
        this.gui.SetFont("s8 c808080", "Consolas")
        this.gui.AddText("w360 vLog xm h140 +0x200", "")

        this._Place()

        if (this.hudMode = "always") {
            WinSetTransparent(this.targetAlpha, this.gui)
            this.shown := true
            this.currentAlpha := this.targetAlpha
        } else {
            this.gui.Hide()
            this.shown := false
            this.currentAlpha := 0
        }
        SetTimer(ObjBindMethod(this, "_Tick"), 50)
    }

    _Place() {
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        w := 380, h := 220
        switch this.corner {
            case "top-left":     x := l + 20, y := t + 20
            case "top-right":    x := r - w - 20, y := t + 20
            case "bottom-left":  x := l + 20, y := b - h - 20
            default:             x := r - w - 20, y := b - h - 20
        }
        this.gui.Show("x" x " y" y " w" w " h" h " NoActivate Hide")
    }

    SetProfile(name) {
        this.gui["Profile"].Text := "profile: " name
    }

    SetFlag(name, value) {
        this.flags[name] := value
        parts := []
        if (this.simulate)
            parts.Push("[SIMULATE]")
        if (this.flags["precision"])
            parts.Push("[PRECISION]")
        if (this.flags["dictate"])
            parts.Push("[DICT *]")
        joined := ""
        for i, p in parts
            joined .= (i > 1 ? "  " : "") . p
        this.gui["Flags"].Text := joined
    }

    ShowAction(text) {
        this.gui["Action"].Text := text
        this.lastActionAt := A_TickCount
        this.Log(text)
    }

    Log(text) {
        timeStamp := FormatTime(, "HH:mm:ss")
        this.eventLines.InsertAt(1, timeStamp . "  " . text)
        while (this.eventLines.Length > this.maxLines)
            this.eventLines.Pop()
        joined := ""
        for i, line in this.eventLines
            joined .= (i > 1 ? "`n" : "") . line
        this.gui["Log"].Text := joined
        try FileAppend(timeStamp "  " text "`n", A_ScriptDir "\hud.log")
    }

    ; Toggles between configured visible mode and "off". Bound to LS click+hold.
    Toggle() {
        if (this.hudMode = "off") {
            this.hudMode := (this.configuredMode = "off") ? "fade" : this.configuredMode
            this.lastActionAt := A_TickCount  ; trigger immediate fade-in
        } else {
            this.hudMode := "off"
            this.gui.Hide()
            this.shown := false
            this.currentAlpha := 0
        }
    }

    _Tick() {
        if (this.hudMode = "off")
            return
        if (this.hudMode = "always") {
            if (this.lastActionAt && A_TickCount - this.lastActionAt > this.autoHideMs) {
                this.gui["Action"].Text := "-"
                this.lastActionAt := 0
            }
            return
        }
        this._TickFade()
    }

    _TickFade() {
        if (!this.lastActionAt) {
            this._SetAlpha(0)
            return
        }
        elapsed := A_TickCount - this.lastActionAt
        total := this.fadeInMs + this.holdMs + this.fadeOutMs
        if (elapsed < this.fadeInMs) {
            alpha := Round(this.targetAlpha * elapsed / this.fadeInMs)
        } else if (elapsed < this.fadeInMs + this.holdMs) {
            alpha := this.targetAlpha
        } else if (elapsed < total) {
            remaining := total - elapsed
            alpha := Round(this.targetAlpha * remaining / this.fadeOutMs)
        } else {
            alpha := 0
            this.lastActionAt := 0  ; stop ticking until next action
        }
        this._SetAlpha(alpha)
    }

    _SetAlpha(alpha) {
        if (alpha = this.currentAlpha)
            return
        this.currentAlpha := alpha
        if (alpha > 0) {
            if (!this.shown) {
                this.gui.Show("NoActivate")
                this.shown := true
            }
            WinSetTransparent(alpha, this.gui)
        } else if (this.shown) {
            this.gui.Hide()
            this.shown := false
        }
    }
}
