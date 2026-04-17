; Haptics — named vibration patterns.
; A pattern is an array of frames; each frame: [durationMs, left 0..1, right 0..1].
; Playing a new pattern cancels the previous one.

class Haptics {
    patterns := Map()
    pending := []
    idx := 0

    __New(patternMap) {
        this.patterns := patternMap
    }

    Play(name) {
        if (!this.patterns.Has(name))
            return
        this.Stop()
        this.pending := this.patterns[name]
        this.idx := 1
        this._Next()
    }

    Stop() {
        SetTimer(ObjBindMethod(this, "_Next"), 0)
        XInput.SetVibration(0, 0, 0)
        this.pending := []
        this.idx := 0
    }

    _Next() {
        if (this.idx > this.pending.Length) {
            XInput.SetVibration(0, 0, 0)
            return
        }
        frame := this.pending[this.idx]
        XInput.SetVibration(0, frame[2], frame[3])
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
