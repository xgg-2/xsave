local xsave = setmetatable({
	Version = "1.1.0",
	Run = xsave_run,
	Gui = xsave_gui,
	Control = Control,
	Stop = function()
		if Control.Running then
			Control.Stop = true
		end
	end,
	Kill = function()
		if Control.Running then
			Control.Kill = true
		end
	end,
	Reset = function()
		Control.Running, Control.Stop, Control.Kill = false, false, false
		GLOBAL_ENV.XSAVE_RUNNING = nil
		if Control.LockedPlace then
			GLOBAL_ENV[Control.LockedPlace] = nil
			Control.LockedPlace = nil
		end
	end,
}, {
	__call = function(_, options, options2)
		if options == nil then
			return xsave_gui()
		end
		return xsave_run(options, options2)
	end,
})

return xsave
