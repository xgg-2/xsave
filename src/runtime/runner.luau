local function xsave_run(CustomOptions, CustomOptions2)
	if Control.Running then
		warn("[xsave] Already running")
		return
	end

	Control.Running = true
	Control.Stop = false
	Control.Kill = false
	Control.Processed = 0
	Control.Size = 0
	Control.Decompiled = 0
	Control.DecompileTime = 0
	Control.Succeeded = nil
	Control.Error = nil
	Control.FileName = nil
	Control.Options = nil
	Control.StatusText = nil
	Control.FinishedAt = nil
	Control.StartedAt = os.clock()

	local ok, err = pcall(run_save, CustomOptions, CustomOptions2)

	Control.FinishedAt = os.clock()
	Control.Running = false

	if not ok then
		Control.Succeeded = false
		Control.Error = tostring(err)
		-- Release locks so a failed run never blocks the next one
		GLOBAL_ENV.XSAVE_RUNNING = nil
		if Control.LockedPlace then
			GLOBAL_ENV[Control.LockedPlace] = nil
			Control.LockedPlace = nil
		end
		warn("[xsave] Failed: " .. tostring(err))
		return
	end

	local used = Control.Options
	if
		Control.Succeeded
		and not Control.Stop
		and used
		and Control.Processed > 0
		and (used.mode == "optimized" or used.mode == "full" or used.mode == "scripts")
	then
		Estimator.record({
			t = os.time(),
			place = game.PlaceId,
			mode = used.mode,
			decompile = used.Decompile and true or false,
			ignoreDefaults = used.IgnoreDefaultProperties and true or false,
			bytecode = used.SaveBytecode and true or false,
			instances = Control.Processed,
			seconds = Control.FinishedAt - Control.StartedAt,
			decompileSeconds = Control.DecompileTime,
			decompiled = Control.Decompiled,
			bytes = Control.Size,
		})
	end
end

