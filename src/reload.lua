---@diagnostic disable: lowercase-global, undefined-global

local keyMaxVisibleKeepsakes = "zannc-KeepsakeExtender-MaxVisibleKeepsakes"
local keyScrollOffset = "zannc-KeepsakeExtender-ScrollOffset"
local keyActiveEntries = "zannc-KeepsakeExtender-ActiveEntries"
local keyNumItems = "zannc-KeepsakeExtender-NumItems"
local keyScrollUp = "zannc-KeepsakeExtender-ScrollUp"
local keyScrollDown = "zannc-KeepsakeExtender-ScrollDown"

local activeKeepsakeIDs, disabledKeepsakeIDs = {}, {}
local scrollArrowXPositions = { 158, 275, 390, 510, 620, 733, 850, 970, 1085, 1195, 1314 }

function createScrollArrowData(x, isUpArrow)
	return {
		Graphic = isUpArrow and "ButtonCodexUp" or "ButtonCodexDown",
		GroupName = "Combat_Menu_Overlay",
		X = x,
		Y = isUpArrow and 120 or 700,
		Alpha = 0.0,
		Scale = 1.0,
		InputBlockDuration = 0.02,
		Data = {
			OnPressedFunctionName = isUpArrow and function(...)
				return KeepsakeScrollUp(...)
			end or function(...)
				return KeepsakeScrollDown(...)
			end,
			ControlHotkeys = isUpArrow and { "MenuUp", "MenuLeft" } or { "MenuDown", "MenuRight" },
			MouseControlHotkeys = isUpArrow and { "MenuUp" } or { "MenuDown" },
		},
	}
end

function checkForCurrentKeepsake(screen)
	if not screen.LastTrait then
		return
	end

	local foundSelected = false

	for _, buttonKey in ipairs(screen[keyActiveEntries]) do
		local component = screen.Components[buttonKey]
		local isVisible = false
		for _, id in ipairs(activeKeepsakeIDs) do
			if component.Id == id then
				isVisible = true
				break
			end
		end

		if component and component.Data and component.Data.Gift == (GameState.LastAwardTrait or screen.LastTrait) and isVisible then
			TeleportCursor({ OffsetX = component.OffsetX, OffsetY = component.OffsetY, ForceUseCheck = true })
			SetSelectedFrame(screen, component, { RestartAnimation = true })
			KeepsakeScreenShowInfo(screen, screen.Components[buttonKey])
			foundSelected = true
			break
		else
			SetAlpha({ Id = screen.Components.EquippedFrame.Id, Fraction = 0.0, Duration = 0.1 })
		end
	end

	if not foundSelected then
		local firstVisibleIndex = math.min(screen[keyScrollOffset] + 1, #screen[keyActiveEntries])
		local firstButtonKey = screen[keyActiveEntries][firstVisibleIndex]
		local firstComponent = screen.Components[firstButtonKey]
		if firstComponent then
			TeleportCursor({ OffsetX = firstComponent.OffsetX, OffsetY = firstComponent.OffsetY, ForceUseCheck = true })
			KeepsakeScreenShowInfo(screen, firstComponent)
		end
	end
	return foundSelected
end

function KeepsakeUpdateVisibility(screen, args)
	args = args or {}
	activeKeepsakeIDs, disabledKeepsakeIDs = {}, {}
	local components = screen.Components

	local rowMin = math.ceil(screen.RowMax / 2)

	local startIndex = screen[keyScrollOffset] + 1
	local endIndex = math.min(screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes], #screen[keyActiveEntries])

	local componentOffsetList = {
		Frame = { offsetx = 0, offsety = 10 },
		Bar = { offsetx = 0, offsety = 80 },
		BarFill = { offsetx = 0, offsety = 80 },
		Rank = { offsetx = 0, offsety = screen.RankOffsetY },
		Sticker = { offsetx = 30, offsety = -40 },
		Lock = { offsetx = 0, offsety = 0 },
	}

	local favouriteKeepsakeVisible = false
	local favouriteButtonKey = nil

	for index, buttonKey in ipairs(screen[keyActiveEntries]) do
		local item = components[buttonKey]
		if item ~= nil and GameState.SaveFirstKeepsakeName == item.Data.Gift then
			if index >= startIndex and index <= endIndex then
				favouriteKeepsakeVisible = true
				favouriteButtonKey = buttonKey
				break
			end
		end
	end

	for index, buttonKey in ipairs(screen[keyActiveEntries]) do
		local item = components[buttonKey]

		if item ~= nil then
			if index >= startIndex and index <= endIndex then
				local x = screen.StartX - screen.SpacerX * rowMin / 2 + ((index - 1) % screen.RowMax + 0.5) * screen.SpacerX
				local y = screen.StartY + math.floor((index - startIndex) / screen.RowMax) * 2 * (screen.SpacerY / 2)

				item.OffsetX = x
				item.OffsetY = y

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
				table.insert(activeKeepsakeIDs, item.Id)

				for k, v in pairs(componentOffsetList) do
					if components[buttonKey .. k] then
						if k ~= "Bar" and k ~= "BarFill" then
							table.insert(activeKeepsakeIDs, components[buttonKey .. k].Id)
						end
					end
				end

				if item.NewIcon then
					table.insert(activeKeepsakeIDs, item.NewIcon.Id)
				end
			else
				table.insert(disabledKeepsakeIDs, item.Id)
				for k, v in pairs(componentOffsetList) do
					if components[buttonKey .. k] then
						table.insert(disabledKeepsakeIDs, components[buttonKey .. k].Id)
					end
				end
				if item.NewIcon then
					table.insert(disabledKeepsakeIDs, item.NewIcon.Id)
				end
			end

			if GameState.SaveFirstKeepsakeName == item.Data.Gift then
				if favouriteKeepsakeVisible and buttonKey == favouriteButtonKey then
					SetSaveFirstIcon(screen, components[buttonKey])
				else
					ClearSaveFirstIcon(screen, components[buttonKey])
				end
			end
		end
	end

	SetAlpha({ Ids = activeKeepsakeIDs, Fraction = 1, Duration = 0.1 })
	UseableOn({ Ids = activeKeepsakeIDs })

	SetAlpha({ Ids = disabledKeepsakeIDs, Fraction = 0, Duration = 0.1 })
	UseableOff({ Ids = disabledKeepsakeIDs, ForceHighlightOff = true })

	if not args.IgnoreArrows then
		local canScrollUp = screen[keyScrollOffset] > 0
		local canScrollDown = screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes] < screen[keyNumItems]

		for i, x in ipairs(scrollArrowXPositions) do
			local upKey = keyScrollUp .. i
			local downKey = keyScrollDown .. i

			if x == 733 then
				if components[upKey] then
					if canScrollUp then
						SetAlpha({ Id = components[upKey].Id, Fraction = 1.0, Duration = 0.1 })
						UseableOn({ Id = components[upKey].Id })
					else
						SetAlpha({ Id = components[upKey].Id, Fraction = 0.3, Duration = 0.1 })
						UseableOff({ Id = components[upKey].Id, ForceHighlightOff = true })
					end
				end

				if components[downKey] then
					if canScrollDown then
						SetAlpha({ Id = components[downKey].Id, Fraction = 1.0, Duration = 0.1 })
						UseableOn({ Id = components[downKey].Id })
					else
						SetAlpha({ Id = components[downKey].Id, Fraction = 0.3, Duration = 0.1 })
						UseableOff({ Id = components[downKey].Id, ForceHighlightOff = true })
					end
				end
			else
				if components[upKey] then
					if canScrollUp then
						UseableOn({ Id = components[upKey].Id })
					else
						UseableOff({ Id = components[upKey].Id, ForceHighlightOff = true })
					end
				end

				if components[downKey] then
					if canScrollDown then
						UseableOn({ Id = components[downKey].Id })
					else
						UseableOff({ Id = components[downKey].Id, ForceHighlightOff = true })
					end
				end
			end
		end
	end
end

function KeepsakeScrollUp(screen, button)
	if screen[keyScrollOffset] <= 0 then
		return false
	end
	screen[keyScrollOffset] = screen[keyScrollOffset] - screen[keyMaxVisibleKeepsakes]
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledUp = true })

	wait(0.02)

	checkForCurrentKeepsake(screen)
	return true
end

function KeepsakeScrollDown(screen, button)
	if screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes] >= screen[keyNumItems] then
		return false
	end
	screen[keyScrollOffset] = screen[keyScrollOffset] + screen[keyMaxVisibleKeepsakes]
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledDown = true })
	wait(0.02)
	checkForCurrentKeepsake(screen)
	return true
end
