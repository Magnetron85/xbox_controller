; Minimal pure-AHK v2 JSON parser/stringifier.
; Handles Map (object), Array, String, Number, true, false, null.
; null decodes to the empty string "" (v0 config files never use null).

class JSON {
    static Parse(text) {
        pos := 1
        len := StrLen(text)
        result := JSON._ParseValue(&text, &pos, len)
        return result
    }

    static _ParseValue(&text, &pos, len) {
        JSON._SkipWs(&text, &pos, len)
        ch := SubStr(text, pos, 1)
        if (ch = "{")
            return JSON._ParseObject(&text, &pos, len)
        if (ch = "[")
            return JSON._ParseArray(&text, &pos, len)
        if (ch = '"')
            return JSON._ParseString(&text, &pos, len)
        if (ch = "t" || ch = "f")
            return JSON._ParseBool(&text, &pos)
        if (ch = "n") {
            pos += 4
            return ""
        }
        return JSON._ParseNumber(&text, &pos, len)
    }

    static _SkipWs(&text, &pos, len) {
        while (pos <= len) {
            c := Ord(SubStr(text, pos, 1))
            if (c = 32 || c = 9 || c = 10 || c = 13)
                pos++
            else
                return
        }
    }

    static _ParseObject(&text, &pos, len) {
        obj := Map()
        pos++
        JSON._SkipWs(&text, &pos, len)
        if (SubStr(text, pos, 1) = "}") {
            pos++
            return obj
        }
        loop {
            JSON._SkipWs(&text, &pos, len)
            key := JSON._ParseString(&text, &pos, len)
            JSON._SkipWs(&text, &pos, len)
            pos++  ; skip :
            value := JSON._ParseValue(&text, &pos, len)
            obj[key] := value
            JSON._SkipWs(&text, &pos, len)
            ch := SubStr(text, pos, 1)
            pos++
            if (ch = "}")
                return obj
        }
    }

    static _ParseArray(&text, &pos, len) {
        arr := []
        pos++
        JSON._SkipWs(&text, &pos, len)
        if (SubStr(text, pos, 1) = "]") {
            pos++
            return arr
        }
        loop {
            arr.Push(JSON._ParseValue(&text, &pos, len))
            JSON._SkipWs(&text, &pos, len)
            ch := SubStr(text, pos, 1)
            pos++
            if (ch = "]")
                return arr
        }
    }

    static _ParseString(&text, &pos, len) {
        pos++
        out := ""
        while (pos <= len) {
            ch := SubStr(text, pos, 1)
            if (ch = '"') {
                pos++
                return out
            }
            if (ch = "\") {
                pos++
                esc := SubStr(text, pos, 1)
                switch esc {
                    case '"': out .= '"'
                    case "\": out .= "\"
                    case "/": out .= "/"
                    case "n": out .= "`n"
                    case "r": out .= "`r"
                    case "t": out .= "`t"
                    case "b": out .= Chr(8)
                    case "f": out .= Chr(12)
                    case "u":
                        out .= Chr("0x" . SubStr(text, pos+1, 4))
                        pos += 4
                }
                pos++
            } else {
                out .= ch
                pos++
            }
        }
        throw Error("Unterminated string in JSON")
    }

    static _ParseNumber(&text, &pos, len) {
        start := pos
        while (pos <= len) {
            ch := SubStr(text, pos, 1)
            if InStr("-+0123456789.eE", ch)
                pos++
            else
                break
        }
        return SubStr(text, start, pos - start) + 0
    }

    static _ParseBool(&text, &pos) {
        if (SubStr(text, pos, 4) = "true") {
            pos += 4
            return true
        }
        pos += 5
        return false
    }

    static Stringify(value, indent := 2, depth := 0) {
        pad := JSON._Pad(indent, depth + 1)
        prePad := JSON._Pad(indent, depth)
        if (value is Map) {
            if (value.Count = 0)
                return "{}"
            items := []
            for k, v in value
                items.Push(pad . JSON._EncStr(k) . ": " . JSON.Stringify(v, indent, depth + 1))
            return "{`n" . JSON._Join(items, ",`n") . "`n" . prePad . "}"
        }
        if (value is Array) {
            if (value.Length = 0)
                return "[]"
            items := []
            for v in value
                items.Push(pad . JSON.Stringify(v, indent, depth + 1))
            return "[`n" . JSON._Join(items, ",`n") . "`n" . prePad . "]"
        }
        if (value = "")
            return '""'
        if IsNumber(value)
            return value ""
        if (value == true)
            return "true"
        if (value == false)
            return "false"
        return JSON._EncStr(value)
    }

    static _Pad(indent, depth) {
        pad := ""
        loop indent * depth
            pad .= " "
        return pad
    }

    static _EncStr(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return '"' . s . '"'
    }

    static _Join(arr, sep) {
        out := ""
        for i, v in arr
            out .= (i > 1 ? sep : "") . v
        return out
    }
}
