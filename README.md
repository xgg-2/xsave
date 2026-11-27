# xsave

```lua
local xsave = loadstring(game:HttpGet("https://raw.githubusercontent.com/xgg-2/xsave/main/saveinstance.luau", true), "xsave")()

xsave()                          -- opens the panel
-- xsave({ SafeMode = true })    -- or run directly with an options table
```

The panel scans the game, estimates time and size from your own previous saves, and lets you change every option before pressing Start. Settings are remembered in `workspace/xsave/profile.json`.

`xsave.Stop()` finishes early and keeps what was collected. `xsave.Kill()` aborts and writes nothing. `xsave.Reset()` clears a stuck lock.

## Credits

Based on **UniversalSynSaveInstance** https://discord.gg/wx4ThpAsmw
(the original repository is no longer available).

Also credited in the source: @MaximumADHD (API dump / Roblox-Client-Tracker), @halffalse, @centerepic.

Licensed under [AGPL-3.0](LICENSE) with the original additional terms (Section 7 (b)):
the credit string above must be kept, and the original source may not be claimed as your own.
