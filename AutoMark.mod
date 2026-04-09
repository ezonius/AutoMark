return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoMark` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoMark", {
			mod_script       = "AutoMark/scripts/mods/AutoMark/AutoMark",
			mod_data         = "AutoMark/scripts/mods/AutoMark/AutoMark_data",
			mod_localization = "AutoMark/scripts/mods/AutoMark/AutoMark_localization",
		})
	end,
	packages = {},
}
