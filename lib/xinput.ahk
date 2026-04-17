; XInput 1.4 wrapper — Xbox Series/One controllers over USB.
; Polls via XInputGetState; drives vibration via XInputSetState (2 main motors).
; Trigger-impulse motors would require a HID output report path; deferred.

global XI_DPAD_UP    := 0x0001
global XI_DPAD_DOWN  := 0x0002
global XI_DPAD_LEFT  := 0x0004
global XI_DPAD_RIGHT := 0x0008
global XI_START      := 0x0010  ; "Menu"  (right of Guide)
global XI_BACK       := 0x0020  ; "View"  (left of Guide)
global XI_LTHUMB     := 0x0040  ; left stick click
global XI_RTHUMB     := 0x0080  ; right stick click
global XI_LSHOULDER  := 0x0100  ; LB
global XI_RSHOULDER  := 0x0200  ; RB
global XI_A          := 0x1000
global XI_B          := 0x2000
global XI_X          := 0x4000
global XI_Y          := 0x8000

global XI_BUTTON_NAMES := Map(
    XI_DPAD_UP,    "dpad_up",
    XI_DPAD_DOWN,  "dpad_down",
    XI_DPAD_LEFT,  "dpad_left",
    XI_DPAD_RIGHT, "dpad_right",
    XI_START,      "menu",
    XI_BACK,       "view",
    XI_LTHUMB,     "ls_click",
    XI_RTHUMB,     "rs_click",
    XI_LSHOULDER,  "lb",
    XI_RSHOULDER,  "rb",
    XI_A,          "a",
    XI_B,          "b",
    XI_X,          "x",
    XI_Y,          "y"
)

; All buttons we emit events for, in bitfield order.
global XI_ALL_BUTTONS := [
    XI_DPAD_UP, XI_DPAD_DOWN, XI_DPAD_LEFT, XI_DPAD_RIGHT,
    XI_START, XI_BACK, XI_LTHUMB, XI_RTHUMB,
    XI_LSHOULDER, XI_RSHOULDER,
    XI_A, XI_B, XI_X, XI_Y
]

class XInput {
    static stateBuf := Buffer(16, 0)
    static vibBuf := Buffer(4, 0)
    static dll := ""

    static Init() {
        if (XInput.dll != "")
            return true
        for name in ["xinput1_4", "xinput1_3", "xinput9_1_0"] {
            h := DllCall("LoadLibrary", "Str", name ".dll", "Ptr")
            if (h) {
                XInput.dll := name
                return true
            }
        }
        return false
    }

    static GetState(idx := 0) {
        if (XInput.dll = "")
            return 0
        result := DllCall(XInput.dll "\XInputGetState", "UInt", idx, "Ptr", XInput.stateBuf, "UInt")
        if (result != 0)
            return 0
        state := Map()
        state["packet"]  := NumGet(XInput.stateBuf, 0, "UInt")
        state["buttons"] := NumGet(XInput.stateBuf, 4, "UShort")
        state["ltrig"]   := NumGet(XInput.stateBuf, 6, "UChar") / 255.0
        state["rtrig"]   := NumGet(XInput.stateBuf, 7, "UChar") / 255.0
        state["lx"]      := NumGet(XInput.stateBuf, 8,  "Short") / 32767.0
        state["ly"]      := NumGet(XInput.stateBuf, 10, "Short") / 32767.0
        state["rx"]      := NumGet(XInput.stateBuf, 12, "Short") / 32767.0
        state["ry"]      := NumGet(XInput.stateBuf, 14, "Short") / 32767.0
        return state
    }

    static SetVibration(idx, left, right) {
        if (XInput.dll = "")
            return
        left  := Max(0.0, Min(1.0, left))
        right := Max(0.0, Min(1.0, right))
        NumPut("UShort", Integer(left * 65535),  XInput.vibBuf, 0)
        NumPut("UShort", Integer(right * 65535), XInput.vibBuf, 2)
        DllCall(XInput.dll "\XInputSetState", "UInt", idx, "Ptr", XInput.vibBuf, "UInt")
    }
}
