---@meta _
---@diagnostic disable

local mods = rom.mods

---@module 'SGG_Modding-ENVY-auto'
mods["SGG_Modding-ENVY"].auto()

rom = rom
_PLUGIN = PLUGIN

---@module 'SGG_Modding-Hades2GameDef-Globals'
game = rom.game

---@module 'SGG_Modding-SJSON'
sjson = mods["SGG_Modding-SJSON"]

---@module 'SGG_Modding-ModUtil'
modutil = mods["SGG_Modding-ModUtil"]

---@module 'SGG_Modding-Chalk'
chalk = mods["SGG_Modding-Chalk"]

---@module 'SGG_Modding-ReLoad'
reload = mods["SGG_Modding-ReLoad"]

---@module 'erumi321-UILibrary-auto'
UILib = mods["erumi321-UILibrary"].auto()

---@module 'KeepsakeExtender-zannc-config'
config = chalk.auto("config.lua")
public.config = config

import_as_fallback(rom.game)

local function on_ready()
	if config.enabled == false then
		return
	end

	game.ScreenData.KeepsakeRack.MaxVisibleKeepsakes = 33
	game.ScreenData.KeepsakeRack.ScrollOffset = 0

	-- Scroll button data
	game.ScreenData.KeepsakeRack.ComponentData.ScrollUp = {
		Graphic = "ButtonCodexUp",
		GroupName = "Combat_Menu_Overlay",
		X = 750,
		Y = 120,
		Alpha = 0.0,
		Scale = 1,
		InputBlockDuration = 0.02,
		Data = {
			OnPressedFunctionName = "KeepsakeScrollUp",
			ControlHotkey = "MenuUp",
		},
	}

	game.ScreenData.KeepsakeRack.ComponentData.ScrollDown = {
		Graphic = "ButtonCodexDown",
		GroupName = "Combat_Menu_Overlay",
		X = 750,
		Y = 700,
		Alpha = 0.0,
		Scale = 1,
		InputBlockDuration = 0.02,
		Data = {
			OnPressedFunctionName = "KeepsakeScrollDown",
			ControlHotkey = "MenuDown",
		},
	}

	import("ready.lua")
end

local function on_reload()
	import("reload.lua")
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
	loader.load(on_ready, on_reload)
end)
