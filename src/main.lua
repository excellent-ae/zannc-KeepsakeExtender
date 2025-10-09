---@meta _
---@diagnostic disable

local mods = rom.mods

---@module 'SGG_Modding-ENVY-auto'
mods["SGG_Modding-ENVY"].auto()

rom = rom
_PLUGIN = PLUGIN

---@module 'SGG_Modding-Hades2GameDef-Globals'
game = rom.game

---@module 'SGG_Modding-ModUtil'
modutil = mods["SGG_Modding-ModUtil"]

---@module 'SGG_Modding-Chalk'
chalk = mods["SGG_Modding-Chalk"]

---@module 'SGG_Modding-ReLoad'
reload = mods["SGG_Modding-ReLoad"]

---@module 'KeepsakeExtender-zannc-config'
config = chalk.auto("config.lua")
public.config = config

import_as_fallback(rom.game)

local function on_ready()
	if config.enabled == false then
		return
	end

	import("ready.lua")
end

local function on_reload()
	if config.enabled == false then
		return
	end

	import("reload.lua")
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
	loader.load(on_ready, on_reload)
end)
