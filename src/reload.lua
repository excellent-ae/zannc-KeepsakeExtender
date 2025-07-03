function OpenKeepsakeRackScreen_override(base, source)
	local screen = DeepCopyTable(ScreenData.KeepsakeRack)
	screen.Source = source
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
	screen.ScrollOffset = 0
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
	if screen.ScrollOffset <= 0 then
		return
	end
	screen.ScrollOffset = screen.ScrollOffset - screen.MaxVisibleKeepsakes
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledUp = true })
	wait(0.02)
	TeleportCursor({ OffsetX = screen.StartX, OffsetY = screen.StartY + ((screen.MaxVisibleKeepsakes - 1) * screen.SpacerY), ForceUseCheck = true })
end

function KeepsakeScrollDown(screen, button)
	if screen.ScrollOffset + screen.MaxVisibleKeepsakes >= screen.NumItems then
		return
	end
	screen.ScrollOffset = screen.ScrollOffset + screen.MaxVisibleKeepsakes
	GenericScrollPresentation(screen, button)
	KeepsakeUpdateVisibility(screen, { ScrolledDown = true })
	wait(0.02)
	TeleportCursor({ OffsetX = screen.StartX, OffsetY = screen.StartY, ForceUseCheck = true })
end

function KeepsakeUpdateVisibility(screen, args)
	args = args or {}
	local components = screen.Components

	local onIds = {}
	local offIds = {}
	local rowMin = math.ceil(screen.RowMax / 2)

	local startIndex = screen.ScrollOffset + 1
	local endIndex = math.min(screen.ScrollOffset + screen.MaxVisibleKeepsakes, #screen.ActiveEntries)

	for index, buttonKey in ipairs(screen.ActiveEntries) do
		local item = components[buttonKey]

		if item ~= nil then
			if index >= startIndex and index <= endIndex then
				local x = screen.StartX - screen.SpacerX * rowMin / 2 + ((index - 1) % screen.RowMax + 0.5) * screen.SpacerX
				local y = screen.StartY + math.floor((index - startIndex) / screen.RowMax) * 2 * (screen.SpacerY / 2)

				-- TP the Keepsake Textures like selected texture
				Teleport({ Id = item.Id, OffsetX = x, OffsetY = y })
				if components[buttonKey .. "Frame"] then
					Teleport({ Id = components[buttonKey .. "Frame"].Id, OffsetX = x, OffsetY = y + 10 })
				end
				if components[buttonKey .. "Bar"] then
					Teleport({ Id = components[buttonKey .. "Bar"].Id, OffsetX = x, OffsetY = y + 80 })
				end
				if components[buttonKey .. "BarFill"] then
					Teleport({ Id = components[buttonKey .. "BarFill"].Id, OffsetX = x, OffsetY = y + 80 })
				end
				if components[buttonKey .. "Rank"] then
					Teleport({ Id = components[buttonKey .. "Rank"].Id, OffsetX = x, OffsetY = y + screen.RankOffsetY })
				end
				if components[buttonKey .. "Sticker"] then
					Teleport({ Id = components[buttonKey .. "Sticker"].Id, OffsetX = x + 30, OffsetY = y - 40 })
				end
				if item.NewIcon then
					Teleport({ Id = item.NewIcon.Id, OffsetX = x, OffsetY = y - 30 })
				end
				if components[buttonKey .. "Lock"] then
					Teleport({ Id = components[buttonKey .. "Lock"].Id, OffsetX = x, OffsetY = y })
				end

				-- Show all
				table.insert(onIds, item.Id)
				if components[buttonKey .. "Frame"] then
					table.insert(onIds, components[buttonKey .. "Frame"].Id)
				end
				if components[buttonKey .. "Bar"] then
					table.insert(onIds, components[buttonKey .. "Bar"].Id)
				end
				if components[buttonKey .. "BarFill"] then
					table.insert(onIds, components[buttonKey .. "BarFill"].Id)
				end
				if components[buttonKey .. "Rank"] then
					table.insert(onIds, components[buttonKey .. "Rank"].Id)
				end
				if components[buttonKey .. "Sticker"] then
					table.insert(onIds, components[buttonKey .. "Sticker"].Id)
				end
				if item.NewIcon then
					table.insert(onIds, item.NewIcon.Id)
				end
				if components[buttonKey .. "Lock"] then
					table.insert(onIds, components[buttonKey .. "Lock"].Id)
				end
			else
				-- Hide keepsakes not on current page
				table.insert(offIds, item.Id)
				if components[buttonKey .. "Frame"] then
					table.insert(offIds, components[buttonKey .. "Frame"].Id)
				end
				if components[buttonKey .. "Bar"] then
					table.insert(offIds, components[buttonKey .. "Bar"].Id)
				end
				if components[buttonKey .. "BarFill"] then
					table.insert(offIds, components[buttonKey .. "BarFill"].Id)
				end
				if components[buttonKey .. "Rank"] then
					table.insert(offIds, components[buttonKey .. "Rank"].Id)
				end
				if components[buttonKey .. "Sticker"] then
					table.insert(offIds, components[buttonKey .. "Sticker"].Id)
				end
				if item.NewIcon then
					table.insert(offIds, item.NewIcon.Id)
				end
				if components[buttonKey .. "Lock"] then
					table.insert(offIds, components[buttonKey .. "Lock"].Id)
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
		if screen.ScrollOffset <= 0 then
			SetAlpha({ Id = components.ScrollUp.Id, Fraction = 0, Duration = 0.1 })
			UseableOff({ Id = components.ScrollUp.Id, ForceHighlightOff = true })
		else
			SetAlpha({ Id = components.ScrollUp.Id, Fraction = 1, Duration = 0.1 })
			UseableOn({ Id = components.ScrollUp.Id })
		end

		if screen.ScrollOffset + screen.MaxVisibleKeepsakes >= screen.NumItems then
			SetAlpha({ Id = components.ScrollDown.Id, Fraction = 0, Duration = 0.1 })
			UseableOff({ Id = components.ScrollDown.Id, ForceHighlightOff = true })
		else
			SetAlpha({ Id = components.ScrollDown.Id, Fraction = 1, Duration = 0.1 })
			UseableOn({ Id = components.ScrollDown.Id })
		end
	end
end
