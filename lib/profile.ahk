; Profile loader.
; Reads profiles/_defaults/{targets,keymaps,haptics}.json and a user profile JSON.
; User profile overrides defaults by key-level merge.

LoadJsonFile(path) {
    if (!FileExist(path))
        throw Error("JSON file not found: " path)
    text := FileRead(path, "UTF-8")
    return JSON.Parse(text)
}

MergeMaps(base, override) {
    for k, v in override
        base[k] := v
    return base
}

LoadProfileBundle(profileName) {
    base := A_ScriptDir
    targets := LoadJsonFile(base "\profiles\_defaults\targets.json")
    keymaps := LoadJsonFile(base "\profiles\_defaults\keymaps.json")
    haptics := LoadJsonFile(base "\profiles\_defaults\haptics.json")
    profilePath := base "\profiles\" profileName ".json"
    if (!FileExist(profilePath))
        throw Error("Profile not found: " profilePath)
    profile := LoadJsonFile(profilePath)

    ; profile may include override maps; merge them in.
    if (profile.Has("targets_override"))
        MergeMaps(targets, profile["targets_override"])
    if (profile.Has("keymaps_override"))
        MergeMaps(keymaps, profile["keymaps_override"])
    if (profile.Has("haptics_override"))
        MergeMaps(haptics, profile["haptics_override"])

    return Map(
        "profile", profile,
        "targets", targets,
        "keymaps", keymaps,
        "haptics", haptics
    )
}
