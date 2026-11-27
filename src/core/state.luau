local GLOBAL_ENV = getgenv and getgenv() or _G or shared

local Control = {
	Running = false,
	Stop = false, -- finish early, keep what was collected so far (valid file)
	Kill = false, -- abort immediately, nothing is written
	Processed = 0,
	StatusText = nil,
	LockedPlace = nil,
	Size = 0,
	Decompiled = 0,
	DecompileTime = 0,
}

