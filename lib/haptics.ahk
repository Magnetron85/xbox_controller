; Haptics — named vibration patterns.
; A pattern is an array of frames; each frame: [durationMs, left 0..1, right 0..1].
; Playing a new pattern cancels the previous one.

class Haptics {
    patterns := Map()
    pending := []
    idx := 0
    scale := 1.0
    humL := 0.0           ; sustained vibration target (survives across pattern plays)
    humR := 0.0
    isHumming := false

    __New(patternMap) {
        this.patterns := patternMap
    }

    ; scale is a multiplier (0..1+) applied to L and R motor values of every frame.
    ; Clamped to [0, 1] per frame. Use 1.0 (default) for baseline patterns.
    Play(name, scale := 1.0) {
        if (!this.patterns.Has(name))
            return
        this._StopPattern()
        this.pending := this.patterns[name]
        this.scale := scale
        this.idx := 1
        this._Next()
    }

    ; Set a sustained vibration that persists until StopHum() or another Hum() call.
    ; Patterns played via Play() briefly override the hum; the hum resumes when the
    ; pattern ends. Safe to call every poll - won't restart an in-progress pattern.
    Hum(l, r) {
        if (l > 1.0)
            l := 1.0
        if (r > 1.0)
            r := 1.0
        this.humL := l
        this.humR := r
        this.isHumming := true
        if (!this._PatternInProgress())
            XInput.SetVibration(0, l, r)
    }

    StopHum() {
        this.isHumming := false
        this.humL := 0.0
        this.humR := 0.0
        if (!this._PatternInProgress())
            XInput.SetVibration(0, 0, 0)
    }

    Stop() {
        this._StopPattern()
        this.StopHum()
    }

    _PatternInProgress() {
        return this.idx > 0 && this.idx <= this.pending.Length
    }

    _StopPattern() {
        SetTimer(ObjBindMethod(this, "_Next"), 0)
        this.pending := []
        this.idx := 0
        this.scale := 1.0
    }

    _Next() {
        if (this.idx > this.pending.Length) {
            ; Pattern complete. Resume hum if active, else silent.
            if (this.isHumming)
                XInput.SetVibration(0, this.humL, this.humR)
            else
                XInput.SetVibration(0, 0, 0)
            this.pending := []
            this.idx := 0
            this.scale := 1.0
            return
        }
        frame := this.pending[this.idx]
        l := frame[2] * this.scale
        r := frame[3] * this.scale
        if (l > 1.0)
            l := 1.0
        if (r > 1.0)
            r := 1.0
        XInput.SetVibration(0, l, r)
        this.idx++
        SetTimer(ObjBindMethod(this, "_Next"), -frame[1])
    }
}

; Build a Haptics from a JSON pattern Map (loaded from haptics.json).
; Expected JSON shape:
;   { "pattern_name": [ {"ms":60,"l":0.4,"r":0.4}, ... ], ... }
LoadHapticsFromJson(jsonObj) {
    patterns := Map()
    for name, frames in jsonObj {
        converted := []
        for f in frames
            converted.Push([f["ms"], f["l"], f["r"]])
        patterns[name] := converted
    }
    return Haptics(patterns)
}
