-- Scroll button data
local keyMaxVisibleKeepsakes = _PLUGIN.guid .. "-MaxVisibleKeepsakes"
local keyScrollOffset = _PLUGIN.guid .. "-ScrollOffset"
local keyScrollUp = _PLUGIN.guid .. "-ScrollUp"
local keyScrollDown = _PLUGIN.guid .. "-ScrollDown"

-- Using this outside a function to access it in Scroll
local onIds = {}
local offIds = {}

local dataScrollUp = {
	Graphic = "ButtonCodexUp",
	GroupName = "Combat_Menu_Overlay",
	X = 750,
	Y = 120,
	Alpha = 0.0,
	Scale = 1,
	InputBlockDuration = 0.02,
	Data = {
		OnPressedFunctionName = function(...)
			return KeepsakeScrollUp(...)
		end,
		ControlHotkey = "MenuUp",
	},
}

local dataScrollDown = {
	Graphic = "ButtonCodexDown",
	GroupName = "Combat_Menu_Overlay",
	X = 750,
	Y = 700,
	Alpha = 0.0,
	Scale = 1,
	InputBlockDuration = 0.02,
	Data = {
		OnPressedFunctionName = function(...)
			return KeepsakeScrollDown(...)
		end,
		ControlHotkey = "MenuDown",
	},
}

local function initKeepsakeRackScreen(screen)
	screen[keyMaxVisibleKeepsakes] = 33
	screen[keyScrollOffset] = 0
	screen.ComponentData[keyScrollUp] = DeepCopyTable(dataScrollUp)
	screen.ComponentData[keyScrollDown] = DeepCopyTable(dataScrollDown)
end

local function checkForEquippedKeepsake(screen)
	if screen.LastTrait then
		for _, buttonKey in ipairs(screen.ActiveEntries) do
			local component = screen.Components[buttonKey]

			local isVisible = false
			for _, id in ipairs(onIds) do
				if component.Id == id then
					isVisible = true
					break
				end
			end

			if component and component.Data and component.Data.Gift == screen.LastTrait and isVisible then
				SetSelectedFrame(screen, component, { Duration = 0.2 })
				break
			else
				SetAlpha({ Id = screen.Components.EquippedFrame.Id, Fraction = 0.0, Duration = 0.1 })
			end
		end
	end
end

function OpenKeepsakeRackScreen_override(base, source)
	local screen = DeepCopyTable(ScreenData.KeepsakeRack)
	screen.Source = source

	initKeepsakeRackScreen(screen)

	if IsScreenOpen(screen.Name) then
		return
	end
	HideCombatUI(screen.Name)
	OnScreenOpened(screen)
	CreateScreenFromData(screen, screen.ComponentData)
	screen.LastTrait = GameState.LastAwardTrait
	screen.StartingHasLastStand = HasLastStand(CurrentRun.Hero)
	screen.StartingHealth = CurrentRun.Hero.MaxHealth
	screen.StartingMana = CurrentRun.Hero.MaxMana

	local components = screen.Components

	if GameState.LastAwardTrait ~= nil then
		thread(MarkObjectiveComplete, "GiftRackPrompt")
	end

	screen.StartX = screen.StartX + ScreenCenterNativeOffsetX
	screen.StartY = screen.StartY + ScreenCenterNativeOffsetY

	screen.HasUnlocked = false
	screen.HasNew = false
	screen.FirstUsable = false

	screen.ActiveEntries = {}
	screen.NumItems = 0
	screen[keyScrollOffset] = 0
	local numEntries = #screen.ItemOrder
	wait(0.2)

	for i = 1, numEntries do
		local entryName = screen.ItemOrder[i]
		local keepsakeData = GetKeepsakeData(entryName)

		if keepsakeData ~= nil then
			local itemData = {
				New = GameState.NewKeepsakeItem[keepsakeData.GiftLevelData.Gift],
				Gift = entryName,
				Level = 1,
				NPC = keepsakeData.NPCName,
				Unlocked = SessionState.AllKeepsakeUnlocked or IsGameStateEligible(keepsakeData.GiftLevelData, keepsakeData.GiftLevelData.GameStateRequirements),
			}

			local buttonKey = "UpgradeToggle" .. i
			CreateKeepsakeIcon(screen, components, { Index = i, UpgradeData = itemData, X = screen.StartX, Y = screen.StartY, Alpha = 0.0 })

			screen.NumItems = screen.NumItems + 1
			table.insert(screen.ActiveEntries, buttonKey)
		end
	end

	KeepsakeUpdateVisibility(screen)

	checkForEquippedKeepsake(screen)

	if not screen.HasUnlocked then
		TeleportCursor({ OffsetX = screen.StartX, OffsetY = screen.StartY, ForceUseCheck = true })
		thread(PlayVoiceLines, GlobalVoiceLines.AwardMenuEmptyVoiceLines, false)
	elseif screen.HasNew then
		thread(PlayVoiceLines, GlobalVoiceLines.AwardMenuNewAvailableVoiceLines, false)
	else
		thread(PlayVoiceLines, GlobalVoiceLines.OpenedAwardMenuVoiceLines, false)
	end

	SetAnimation({ DestinationId = CurrentRun.Hero.ObjectId, Name = "MelinoeEquip" })

	screen.KeepOpen = true
	HandleScreenInput(screen)
end

function KeepsakeScrollUp(screen, button)
	if screen[keyScrollOffset] <= 0 then
		return
	end
	screen[keyScrollOffset] = screen[keyScrollOffset] - screen[keyMaxVisibleKeepsakes]
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledUp = true })

	wait(0.02)
	-- TeleportCursor({ OffsetX = screen.StartX, OffsetY = screen.StartY + ((screen[keyMaxVisibleKeepsakes] - 1) * screen.SpacerY), ForceUseCheck = true })

	checkForEquippedKeepsake(screen)
end

function KeepsakeScrollDown(screen, button)
	if screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes] >= screen.NumItems then
		return
	end
	screen[keyScrollOffset] = screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes]
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledDown = true })

	wait(0.02)
	-- TeleportCursor({ OffsetX = screen.StartX, OffsetY = screen.StartY, ForceUseCheck = true })

	checkForEquippedKeepsake(screen)
end

function KeepsakeUpdateVisibility(screen, args)
	args = args or {}
	local components = screen.Components

	local rowMin = math.ceil(screen.RowMax / 2)
	onIds = {}
	offIds = {}

	local startIndex = screen[keyScrollOffset] + 1
	local endIndex = math.min(screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes], #screen.ActiveEntries)

	local componentOffsetList = {
		Frame = { offsetx = 0, offsety = 10 },
		Bar = { offsetx = 0, offsety = 80 },
		BarFill = { offsetx = 0, offsety = 80 },
		Rank = { offsetx = 0, offsety = screen.RankOffsetY },
		Sticker = { offsetx = 30, offsety = -40 },
		Lock = { offsetx = 0, offsety = 0 },
	}

	for index, buttonKey in ipairs(screen.ActiveEntries) do
		local item = components[buttonKey]

		if item ~= nil then
			if index >= startIndex and index <= endIndex then
				local x = screen.StartX - screen.SpacerX * rowMin / 2 + ((index - 1) % screen.RowMax + 0.5) * screen.SpacerX
				local y = screen.StartY + math.floor((index - startIndex) / screen.RowMax) * 2 * (screen.SpacerY / 2)

				-- TP the Keepsake Textures like selected texture
				Teleport({ Id = item.Id, OffsetX = x, OffsetY = y })

				for k, v in pairs(componentOffsetList) do
					if components[buttonKey .. k] then
						Teleport({ Id = components[buttonKey .. k].Id, OffsetX = x + v.offsetx, OffsetY = y + v.offsety })
					end
				end

				if item.NewIcon then
					Teleport({ Id = item.NewIcon.Id, OffsetX = x, OffsetY = y - 30 })
				end

				-- Add Keepsakes to list to be shown later
				table.insert(onIds, item.Id)

				for k, v in pairs(componentOffsetList) do
					if components[buttonKey .. k] then
						table.insert(onIds, components[buttonKey .. k].Id)
					end
				end

				if item.NewIcon then
					table.insert(onIds, item.NewIcon.Id)
				end
			else
				-- Hide keepsakes by adding to list
				table.insert(offIds, item.Id)
				for k, v in pairs(componentOffsetList) do
					if components[buttonKey .. k] then
						table.insert(offIds, components[buttonKey .. k].Id)
					end
				end
				if item.NewIcon then
					table.insert(offIds, item.NewIcon.Id)
				end
			end
		end
	end

	SetAlpha({ Ids = onIds, Fraction = 1, Duration = 0.1 })
	UseableOn({ Ids = onIds })

	SetAlpha({ Ids = offIds, Fraction = 0, Duration = 0.1 })
	UseableOff({ Ids = offIds, ForceHighlightOff = true })

	-- Update scroll arrows
	if not args.IgnoreArrows then
		if screen[keyScrollOffset] <= 0 then
			SetAlpha({ Id = components[keyScrollUp].Id, Fraction = 0, Duration = 0.1 })
			UseableOff({ Id = components[keyScrollUp].Id, ForceHighlightOff = true })
		else
			SetAlpha({ Id = components[keyScrollUp].Id, Fraction = 1, Duration = 0.1 })
			UseableOn({ Id = components[keyScrollUp].Id })
		end

		if screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes] >= screen.NumItems then
			SetAlpha({ Id = components[keyScrollDown].Id, Fraction = 0, Duration = 0.1 })
			UseableOff({ Id = components[keyScrollDown].Id, ForceHighlightOff = true })
		else
			SetAlpha({ Id = components[keyScrollDown].Id, Fraction = 1, Duration = 0.1 })
			UseableOn({ Id = components[keyScrollDown].Id })
		end
	end
end
