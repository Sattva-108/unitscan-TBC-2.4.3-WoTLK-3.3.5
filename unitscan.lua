--------------------------------------------------------------------------------------
--	Backport and modifications by Sattva
--	Credit to simon_hirsig & tablegrapes
--	Credit to Macumba for checking all rares in list and then adding frFR database!
--	Code from unitscan & unitscan-rares
--------------------------------------------------------------------------------------

	LibCompat = LibStub:GetLibrary("LibCompat-1.0")
	
	-- Create global table
	_G.unitscanDB = _G.unitscanDB or {}

	-- Get locale table
	local void, unitscan = ...
	local L = unitscan.L



	-- Create locals
	local unitscan = CreateFrame'Frame'
	local forbidden
	local is_resting
	local deadscan = false
	local unitscanLC, unitscanCB, usDropList, usConfigList, usLockList = {}, {}, {}, {}, {}
	local void

	-- Version
	unitscanLC["AddonVer"] = "3.3.5"	

	--===== Check the current locale of the WoW client =====--
	local currentLocale = GetLocale()
	local ClientVersion = GetBuildInfo()
	local GameLocale = GetLocale()

	--===== Check for game version =====--
	local isTBC = select(4, GetBuildInfo()) == 20400 -- true if TBC 2.4.3
	local isWOTLK = select(4, GetBuildInfo()) == 30300 -- true if WOTLK 3.3.5

----------------------------------------------------------------------
--	L00: unitscan
----------------------------------------------------------------------
	-- inititialize vairables
	unitscanLC["NumberOfPages"] = 9

	-- Create event frame
	local usEvt = CreateFrame("FRAME")
	usEvt:RegisterEvent("ADDON_LOADED")
	usEvt:RegisterEvent("PLAYER_LOGIN")
	usEvt:RegisterEvent("PLAYER_ENTERING_WORLD")


--------------------------------------------------------------------------------
-- More Events
--------------------------------------------------------------------------------

	unitscan:RegisterEvent'ADDON_LOADED'
	unitscan:RegisterEvent'ADDON_ACTION_FORBIDDEN'
	unitscan:RegisterEvent'PLAYER_TARGET_CHANGED'
	unitscan:RegisterEvent'ZONE_CHANGED_NEW_AREA'
	unitscan:RegisterEvent'PLAYER_LOGIN'
	unitscan:RegisterEvent'PLAYER_UPDATE_RESTING'


--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------

	--===== Some Colors for borders of button =====--
	local BROWN = {.7, .15, .05}
	local YELLOW = {1, 1, .15}


--------------------------------------------------------------------------------
-- Creating SavedVariables DB tables here. 
--------------------------------------------------------------------------------

	--===== DB Table for user-added targets via /unitscan "name" or /unitscan target =====--
	unitscan_targets = {}

	--===== DB Table for user-added rare spawns to ignore from scanning =====--
	unitscan_ignored = {}

	--===== DB Table for Default Settings =====--
	unitscan_defaults = {
		CHECK_INTERVAL = .3,
	}

	unitscan_removed = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

	--===== Local table to prevent spamming the alert. =====--
	local found = {}

	rare_spawns = {}

----------------------------------------------------------------------
--	L01: Functions
----------------------------------------------------------------------

	-- Print text
	function unitscanLC:Print(text)
		DEFAULT_CHAT_FRAME:AddMessage(L[text], 1.0, 0.85, 0.0)
	end

	-- Lock and unlock an item
	function unitscanLC:LockItem(item, lock)
		if lock then
			item:Disable()
			item:SetAlpha(0.3)
		else
			item:Enable()
			item:SetAlpha(1.0)
		end
	end

	-- Hide configuration panels
	function unitscanLC:HideConfigPanels()
		for k, v in pairs(usConfigList) do
			v:Hide()
		end
	end

	-- Show a single line prefilled editbox with copy functionality
	function unitscanLC:ShowSystemEditBox(word, focuschat)
		if not unitscanLC.FactoryEditBox then
			-- Create frame for first time
			local eFrame = CreateFrame("FRAME", nil, unitscanLC["Page1"])
			unitscanLC.FactoryEditBox = eFrame
			eFrame:SetSize(712, 110)
			eFrame:SetScale(0.8)
			eFrame:SetPoint("BOTTOM", unitscanLC["Page1"], "TOP", 0, 5)
			eFrame:SetClampedToScreen(true)
			eFrame:SetFrameStrata("FULLSCREEN_DIALOG")
			-- eFrame:SetFrameLevel(5000)
			eFrame:EnableMouse(true)
			eFrame:EnableKeyboard()
			eFrame:SetScript("OnMouseDown", function(self, btn)
				if btn == "RightButton" then
					eFrame:Hide()
				end
			end)
			-- Add background color
			eFrame.t = eFrame:CreateTexture(nil, "BACKGROUND")
			eFrame.t:SetAllPoints()
			eFrame.t:SetTexture(0.05, 0.05, 0.05, 0.9)
			-- Add copy title
			eFrame.f = eFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
			eFrame.f:SetPoint("TOPLEFT", x, y)
			eFrame.f:SetPoint("TOPLEFT", eFrame, "TOPLEFT", 12, -52)
			eFrame.f:SetWidth(676)
			eFrame.f:SetJustifyH("LEFT")
			eFrame.f:SetWordWrap(false)
			-- Add copy label
			eFrame.c = eFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
			eFrame.c:SetPoint("TOPLEFT", x, y)
			eFrame.c:SetText(L["Press CTRL/C to copy"])
			eFrame.c:SetPoint("TOPLEFT", eFrame, "TOPLEFT", 12, -82)
			-- Add feedback label
			eFrame.x = eFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
			eFrame.x:SetPoint("TOPRIGHT", x, y)
			eFrame.x:SetText("\124cff00ff00" .. "Feedback Discord:" .. "\124cffffff00" .. " sattva108")

			eFrame.x:SetPoint("TOPRIGHT", eFrame, "TOPRIGHT", -12, -52)
			hooksecurefunc(eFrame.f, "SetText", function()
				eFrame.f:SetWidth(676 - eFrame.x:GetStringWidth() - 26)
			end)
			-- Add cancel label
			eFrame.x = eFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
			eFrame.x:SetPoint("TOPRIGHT", x, y)
			eFrame.x:SetText(L["Right-click to close"])
			eFrame.x:SetPoint("TOPRIGHT", eFrame, "TOPRIGHT", -12, -82)
			-- Create editbox
			eFrame.b = CreateFrame("EditBox", nil, eFrame, "InputBoxTemplate")
			eFrame.b:ClearAllPoints()
			eFrame.b:SetPoint("TOPLEFT", eFrame, "TOPLEFT", 16, -12)
			eFrame.b:SetSize(672, 24)
			eFrame.b:SetFontObject("GameFontNormalLarge")
			eFrame.b:SetTextColor(1.0, 1.0, 1.0, 1)
			eFrame.b:DisableDrawLayer("BACKGROUND")
			-- eFrame.b:SetBlinkSpeed(0)
			eFrame.b:SetHitRectInsets(99, 99, 99, 99)
			eFrame.b:SetAutoFocus(true)
			eFrame.b:SetAltArrowKeyMode(true)
			eFrame.b:EnableMouse(true)
			eFrame.b:EnableKeyboard(true)
			-- Editbox texture
			eFrame.t = CreateFrame("FRAME", nil, eFrame.b)
			eFrame.t:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }})
			eFrame.t:SetPoint("LEFT", -6, 0)
			eFrame.t:SetWidth(eFrame.b:GetWidth() + 6)
			eFrame.t:SetHeight(eFrame.b:GetHeight())
			eFrame.t:SetBackdropColor(1.0, 1.0, 1.0, 0.3)
			-- Handler
			-- it doesnt work in 3.3.5
			eFrame.b:SetScript("OnKeyDown", function(void, key)
				if key == "c" and IsControlKeyDown() then
					LibCompat.After(0.1, function()
						eFrame:Hide()
						ActionStatus_DisplayMessage(L["Copied to clipboard."], true)
						if unitscanLC.FactoryEditBoxFocusChat then
							local eBox = ChatEdit_ChooseBoxForSend()
							ChatEdit_ActivateChat(eBox)
						end
					end)
				end
			end)
			-- Prevent changes
			-- eFrame.b:SetScript("OnEscapePressed", function() eFrame:Hide() end)
			-- eFrame.b:SetScript("OnEnterPressed", eFrame.b.HighlightText)
			-- eFrame.b:SetScript("OnMouseDown", eFrame.b.ClearFocus)
			-- eFrame.b:SetScript("OnMouseUp", eFrame.b.HighlightText)
			eFrame.b:SetScript("OnChar", function(_, char) 
				if char ~= 'W' and char ~= 'A' and char ~= 'S' and char ~= 'D' then 
					eFrame.b:Hide()
					eFrame.b:SetFocus(false)
				end 
				eFrame.b:SetText(word); 
				eFrame.b:HighlightText(); 
			end);

			eFrame.b:SetScript("OnMouseUp", function() eFrame.b:HighlightText(); end);
			eFrame.b:SetScript("OnEscapePressed", function() eFrame:Hide() end)
			eFrame.b:SetFocus(true)
			eFrame.b:HighlightText()
			eFrame:Show()
		end
		if focuschat then unitscanLC.FactoryEditBoxFocusChat = true else unitscanLC.FactoryEditBoxFocusChat = nil end
		unitscanLC.FactoryEditBox:Show()
		unitscanLC.FactoryEditBox.b:SetText(word)
		unitscanLC.FactoryEditBox.b:HighlightText()
		unitscanLC.FactoryEditBox.b:SetScript("OnChar", function(_, char) 
			if char ~= 'W' and char ~= 'A' and char ~= 'S' and char ~= 'D' then 
				unitscanLC.FactoryEditBox:Hide()
				unitscanLC.FactoryEditBox.b:SetFocus(false)
			end 
			unitscanLC.FactoryEditBox.b:SetFocus(true) 
			unitscanLC.FactoryEditBox.b:SetText(word) 
			unitscanLC.FactoryEditBox.b:HighlightText() 
		end);

		unitscanLC.FactoryEditBox.b:SetScript("OnKeyUp", function() unitscanLC.FactoryEditBox.b:SetFocus(true) unitscanLC.FactoryEditBox.b:SetText(word) unitscanLC.FactoryEditBox.b:HighlightText() end)
	end

	-- Load a string variable or set it to default if it's not set to "On" or "Off"
	function unitscanLC:LoadVarChk(var, def)
		if unitscanDB[var] and type(unitscanDB[var]) == "string" and unitscanDB[var] == "On" or unitscanDB[var] == "Off" then
			unitscanLC[var] = unitscanDB[var]
		else
			unitscanLC[var] = def
			unitscanDB[var] = def
		end
	end

	-- Load a numeric variable and set it to default if it's not within a given range
	function unitscanLC:LoadVarNum(var, def, valmin, valmax)
		if unitscanDB[var] and type(unitscanDB[var]) == "number" and unitscanDB[var] >= valmin and unitscanDB[var] <= valmax then
			unitscanLC[var] = unitscanDB[var]
		else
			unitscanLC[var] = def
			unitscanDB[var] = def
		end
	end

	-- Load an anchor point variable and set it to default if the anchor point is invalid
	function unitscanLC:LoadVarAnc(var, def)
		if unitscanDB[var] and type(unitscanDB[var]) == "string" and unitscanDB[var] == "CENTER" or unitscanDB[var] == "TOP" or unitscanDB[var] == "BOTTOM" or unitscanDB[var] == "LEFT" or unitscanDB[var] == "RIGHT" or unitscanDB[var] == "TOPLEFT" or unitscanDB[var] == "TOPRIGHT" or unitscanDB[var] == "BOTTOMLEFT" or unitscanDB[var] == "BOTTOMRIGHT" then
			unitscanLC[var] = unitscanDB[var]
		else
			unitscanLC[var] = def
			unitscanDB[var] = def
		end
	end

	-- Load a string variable and set it to default if it is not a string (used with minimap exclude list)
	function unitscanLC:LoadVarStr(var, def)
		if unitscanDB[var] and type(unitscanDB[var]) == "string" then
			unitscanLC[var] = unitscanDB[var]
		else
			unitscanLC[var] = def
			unitscanDB[var] = def
		end
	end

	-- Show tooltips for checkboxes
	function unitscanLC:TipSee()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		local parent = self:GetParent()
		local pscale = parent:GetEffectiveScale()
		local gscale = UIParent:GetEffectiveScale()
		local tscale = GameTooltip:GetEffectiveScale()
		local gap = ((UIParent:GetRight() * gscale) - (parent:GetRight() * pscale))
		if gap < (250 * tscale) then
			GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
		end
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end

	-- Show tooltips for dropdown menu tooltips
	function unitscanLC:ShowDropTip()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		local parent = self:GetParent():GetParent():GetParent()
		local pscale = parent:GetEffectiveScale()
		local gscale = UIParent:GetEffectiveScale()
		local tscale = GameTooltip:GetEffectiveScale()
		local gap = ((UIParent:GetRight() * gscale) - (parent:GetRight() * pscale))
		if gap < (250 * tscale) then
			GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
		end
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end

	-- Show tooltips for configuration buttons and dropdown menus
	function unitscanLC:ShowTooltip()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		local parent = unitscanLC["PageF"]
		local pscale = parent:GetEffectiveScale()
		local gscale = UIParent:GetEffectiveScale()
		local tscale = GameTooltip:GetEffectiveScale()
		local gap = ((UIParent:GetRight() * gscale) - (unitscanLC["PageF"]:GetRight() * pscale))
		if gap < (250 * tscale) then
			GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
		end
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end

	-- Create configuration button
	function unitscanLC:CfgBtn(name, parent)
		local CfgBtn = CreateFrame("BUTTON", nil, parent)
		unitscanCB[name] = CfgBtn
		CfgBtn:SetWidth(20)
		CfgBtn:SetHeight(20)
		CfgBtn:SetPoint("LEFT", parent.f, "RIGHT", 0, 0)

		CfgBtn.t = CfgBtn:CreateTexture(nil, "BORDER")
		CfgBtn.t:SetAllPoints()
		CfgBtn.t:SetTexture("Interface\\WorldMap\\Gear_64.png")
		CfgBtn.t:SetTexCoord(0, 0.50, 0, 0.50);
		CfgBtn.t:SetVertexColor(1.0, 0.82, 0, 1.0)

		CfgBtn:SetHighlightTexture("Interface\\WorldMap\\Gear_64.png")
		CfgBtn:GetHighlightTexture():SetTexCoord(0, 0.50, 0, 0.50);

		CfgBtn.tiptext = L["Click to configure the settings for this option."]
		CfgBtn:SetScript("OnEnter", unitscanLC.ShowTooltip)
		CfgBtn:SetScript("OnLeave", GameTooltip_Hide)
	end

	-- Create a help button to the right of a fontstring
	function unitscanLC:CreateHelpButton(frame, panel, parent, tip)
		unitscanLC:CfgBtn(frame, panel)
		unitscanCB[frame]:ClearAllPoints()
		unitscanCB[frame]:SetPoint("LEFT", parent, "RIGHT", -parent:GetWidth() + parent:GetStringWidth(), 0)
		unitscanCB[frame]:SetSize(25, 25)
		unitscanCB[frame].t:SetTexture("Interface\\COMMON\\help-i.blp")
		unitscanCB[frame].t:SetTexCoord(0, 1, 0, 1)
		unitscanCB[frame].t:SetVertexColor(0.9, 0.8, 0.0)
		unitscanCB[frame]:SetHighlightTexture("Interface\\COMMON\\help-i.blp")
		unitscanCB[frame]:GetHighlightTexture():SetTexCoord(0, 1, 0, 1)
		unitscanCB[frame].tiptext = L[tip]
		unitscanCB[frame]:SetScript("OnEnter", unitscanLC.TipSee)
	end

	-- Show a footer
	function unitscanLC:MakeFT(frame, text, left, width)
		local footer = unitscanLC:MakeTx(frame, text, left, 96)
		footer:SetWidth(width); footer:SetJustifyH("LEFT"); footer:SetWordWrap(true); footer:ClearAllPoints()
		footer:SetPoint("BOTTOMLEFT", left, 96)
	end

	-- Capitalise first character in a string
	function unitscanLC:CapFirst(str)
		return gsub(string.lower(str), "^%l", strupper)
	end

	-- Show memory usage stat
	function unitscanLC:ShowMemoryUsage(frame, anchor, x, y)

		-- Create frame
		local memframe = CreateFrame("FRAME", nil, frame)
		memframe:ClearAllPoints()
		memframe:SetPoint(anchor, x, y)
		memframe:SetWidth(100)
		memframe:SetHeight(20)

		-- Create labels
		local pretext = memframe:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		pretext:SetPoint("TOPLEFT", 0, 0)
		pretext:SetText(L["Memory Usage"])

		local memtext = memframe:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		memtext:SetPoint("TOPLEFT", 0, 0 - 30)

		-- Create stat
		local memstat = memframe:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		memstat:SetPoint("BOTTOMLEFT", memtext, "BOTTOMRIGHT")
		memstat:SetText("(calculating...)")

		-- Create update script
		local memtime = -1
		memframe:SetScript("OnUpdate", function(self, elapsed)
			if memtime > 2 or memtime == -1 then
				UpdateAddOnMemoryUsage();
				memtext = GetAddOnMemoryUsage("unitscan")
				memtext = math.floor(memtext + .5) .. " KB"
				memstat:SetText(memtext);
				memtime = 0;
			end
			memtime = memtime + elapsed;
		end)

		-- Release memory
		unitscanLC.ShowMemoryUsage = nil

	end

	-- Check if player is in LFG queue
	function unitscanLC:IsInLFGQueue()
		if unitscanLC["GameVer"] == "5" then
			if GetLFGQueueStats(LE_LFG_CATEGORY_LFD) or GetLFGQueueStats(LE_LFG_CATEGORY_LFR) or GetLFGQueueStats(LE_LFG_CATEGORY_RF) then
				return true
			end
		else
			if MiniMapLFGFrame:IsShown() then return true end
		end
	end

	-- Check if player is in combat
	function unitscanLC:PlayerInCombat()
		if (UnitAffectingCombat("player")) then
			unitscanLC:Print("You cannot do that in combat.")
			return true
		end
	end

	--  Hide panel and pages
	function unitscanLC:HideFrames()

		-- Hide option pages
		for i = 0, unitscanLC["NumberOfPages"] do
			if unitscanLC["Page"..i] then
				unitscanLC["Page"..i]:Hide();
			end;
		end

		-- Hide options panel
		unitscanLC["PageF"]:Hide();

	end

	-- Find out if Leatrix Plus is showing (main panel or config panel)
	function unitscanLC:IsUnitscanShowing()
		if unitscanLC["PageF"]:IsShown() then return true end
		for k, v in pairs(usConfigList) do
			if v:IsShown() then
				return true
			end
		end
	end

	-- Check if a name is in your friends list or guild (does not check realm as realm is unknown for some checks)
	function unitscanLC:FriendCheck(name)

		-- Do nothing if name is empty (such as whispering from the Battle.net app)
		if not name then return end

		-- Update friends list
		ShowFriends()

		-- Remove realm if it exists
		if name ~= nil then
			name = strsplit("-", name, 2)
		end

		-- Check character friends
		for i = 1, GetNumFriends() do
			local friendName, _, _, _, friendConnected = GetFriendInfo(i)
			if friendName ~= nil then -- Check if name is not nil
				friendName = strsplit("-", friendName, 2)
			end

			if (name == friendName) and friendConnected then -- Check if name matches and friend is connected
				return true
			end
		end

		-- Check guild members if guild is enabled (new members may need to press J to refresh roster)
		if unitscanLC["FriendlyGuild"] == "On" then
			local gCount = GetNumGuildMembers()
			for i = 1, gCount do
				local gName, void, void, void, void, void, void, void, gOnline = GetGuildRosterInfo(i)
				if gOnline then
					gName = strsplit("-", gName, 2)
					-- Return true if character name matches
					if (name == gName) then
						return true
					end
				end
			end
		end
	end	


---------------------------------------------------------------------------------------------------
-- Functions mainly for restrictions and conditions for unit scanning, RAID mark setup conditions.
---------------------------------------------------------------------------------------------------


	unitscan:SetScript('OnUpdate', function() unitscan.UPDATE() end)
	unitscan:SetScript('OnEvent', function(_, event, arg1)
		if event == 'ADDON_LOADED' and arg1 == 'unitscan' then
			unitscan.LOAD()
		elseif event == 'ADDON_ACTION_FORBIDDEN' and arg1 == 'unitscan' then
			forbidden = true
		elseif event == 'PLAYER_TARGET_CHANGED' then
			if UnitName'target' and strupper(UnitName'target') == unitscan.button:GetText() and not GetRaidTargetIndex'target' and (not UnitInRaid'player' or IsRaidOfficer() or IsRaidLeader()) then
				SetRaidTarget('target', 2)
			end
		elseif event == 'ZONE_CHANGED_NEW_AREA' or 'PLAYER_LOGIN' or 'PLAYER_UPDATE_RESTING' then
			unitscan_LoadRareSpawns()
			local loc = GetRealZoneText()
			local _, instance_type = IsInInstance()
			is_resting = IsResting()
			nearby_targets = {}

			if instance_type == "raid" or instance_type == "pvp" then return end
			if loc == nil then return end

			for expansion, spawns in pairs(rare_spawns) do
				for name, zone in pairs(spawns) do
					if not unitscan_ignored[name] then
						local reaction = UnitReaction("player", name)
						if not reaction or reaction < 4 then
							reaction = true
						else
							reaction = false
						end

						if reaction and (loc == zone or string.match(loc, zone) or zone == "A H") then
							table.insert(nearby_targets, {name, expansion})
						end
					end
				end
			end
			-- print("nearby_targets:", table.concat(nearby_targets, ", ")) -- Don't delete, it's a useful debug code to print what was added to the rare list scanning.
		end
	end)


-------------------------------------------------------------------------------------
-- Function to refresh current rare mob list, after doing /unitscan ignore #unitname
-------------------------------------------------------------------------------------


	function unitscan.refresh_nearby_targets()
		unitscan_LoadRareSpawns()
		-- print("Refreshed nearby rare list.")
		local loc = GetRealZoneText()
		local _, instance_type = IsInInstance()
		is_resting = IsResting()
		nearby_targets = {}

		if instance_type == "raid" or instance_type == "pvp" then return end
		if loc == nil then return end

		for expansion, spawns in pairs(rare_spawns) do
			for name, zone in pairs(spawns) do
				if not unitscan_ignored[name] then
					local reaction = UnitReaction("player", name)
					if not reaction or reaction < 4 then
						reaction = true
					else
						reaction = false
					end

					if reaction and (loc == zone or string.match(loc, zone) or zone == "A H") then
						table.insert(nearby_targets, {name, expansion})
					end
				end
			end
		end

		-- print("nearby_targets:", table.concat(nearby_targets, ", "))
	end



----------------------------------------------------------------------
--	L02: Locks
----------------------------------------------------------------------

	-- Function to set lock state for configuration buttons
	function unitscanLC:LockOption(option, item, reloadreq)
		if reloadreq then
			-- Option change requires UI reload
			if unitscanLC[option] ~= unitscanDB[option] or unitscanLC[option] == "Off" then
				unitscanLC:LockItem(unitscanCB[item], true)
			else
				unitscanLC:LockItem(unitscanCB[item], false)
			end
		else
			-- Option change does not require UI reload
			if unitscanLC[option] == "Off" then
				unitscanLC:LockItem(unitscanCB[item], true)
			else
				unitscanLC:LockItem(unitscanCB[item], false)
			end
		end
	end

--	Set lock state for configuration buttons
	function unitscanLC:SetDim()
		--unitscanLC:LockOption("AutomateQuests", "AutomateQuestsBtn", false)			-- Automate quests
		--unitscanLC:LockOption("AutoAcceptRes", "AutoAcceptResBtn", false)			-- Accept resurrection
	end


----------------------------------------------------------------------
--	L03: Restarts
----------------------------------------------------------------------

	-- Set the reload button state
	function unitscanLC:ReloadCheck()

		---- Chat
		--if	(unitscanLC["UseEasyChatResizing"]	~= unitscanDB["UseEasyChatResizing"])	-- Use easy resizing
		--or	(unitscanLC["NoCombatLogTab"]		~= unitscanDB["NoCombatLogTab"])			-- Hide the combat log
		--or	(unitscanLC["NoChatButtons"]			~= unitscanDB["NoChatButtons"])			-- Hide chat buttons

		--then
		--	-- Enable the reload button
		--	unitscanLC:LockItem(unitscanCB["ReloadUIButton"], false)
		--	unitscanCB["ReloadUIButton"].f:Show()
		--else
		--	-- Disable the reload button
		--	unitscanLC:LockItem(unitscanCB["ReloadUIButton"], true)
		--	unitscanCB["ReloadUIButton"].f:Hide()
		--end

	end

----------------------------------------------------------------------
--	L40: Player
----------------------------------------------------------------------

	function unitscanLC:Player()

		----------------------------------------------------------------------
		-- Minimap button (no reload required)
		----------------------------------------------------------------------

		do

			-- Minimap button click function
			local function MiniBtnClickFunc(arg1)

				if unitscanLC["LeaPlusFrameMove"] and unitscanLC["LeaPlusFrameMove"]:IsShown() then return end
                if unitscanCB["TooltipDragFrame"] and unitscanCB["TooltipDragFrame"]:IsShown() then return end
                if InterfaceOptionsFrame:IsShown() or VideoOptionsFrame:IsShown() then return end

                if arg1 == "LeftButton" then
					-- No modifier key toggles the options panel
					if unitscanLC:IsUnitscanShowing() then
						unitscanLC:HideFrames()
						unitscanLC:HideConfigPanels()
					else
						unitscanLC:HideFrames()
						unitscanLC["PageF"]:Show()
					end
					unitscanLC["Page" .. unitscanLC["LeaStartPage"]]:Show()
                end
                if arg1 == "RightButton" then
                        ReloadUI();
                    end

			end

			-- Create minimap button using LibDBIcon
			local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("unitscan", {
				type = "data source",
				text = "unitscan",
			    icon = "Interface\\Icons\\Inv_qirajidol_life",
				OnClick = function(self, btn)
					MiniBtnClickFunc(btn)
				end,
				OnTooltipShow = function(tooltip)
					if not tooltip or not tooltip.AddLine then return end
					tooltip:AddLine("unitscan")	
					tooltip:AddLine("\124cffeda55fClick \124cff99ff00to open unitscan options.")
                    tooltip:AddLine("\124cffeda55fRight-Click \124cff99ff00to reload the user interface.")
				end,
			})

			local icon = LibStub("LibDBIcon-1.0", true)
			icon:Register("unitscan", miniButton, unitscanDB)
			--icon:Show("unitscan")

			-- Function to toggle LibDBIcon
			local function SetLibDBIconFunc()
				if unitscanLC["ShowMinimapIcon"] == "On" then
					unitscanDB["hide"] = false
					icon:Show("unitscan")
				else
					unitscanDB["hide"] = true
					icon:Hide("unitscan")
				end
			end

			-- Set LibDBIcon when option is clicked and on startup
			unitscanCB["ShowMinimapIcon"]:HookScript("OnClick", SetLibDBIconFunc)
			SetLibDBIconFunc()
		end



		------------------------------------------------------------------------
		----	Move chat editbox to top
		------------------------------------------------------------------------

		--if unitscanLC["MoveChatEditBoxToTop"] == "On" and not LeaLockList["MoveChatEditBoxToTop"] then

		--	-- Set options for normal chat frames
		--	for i = 1, 50 do
		--		if _G["ChatFrame" .. i] then
		--			-- Position the editbox
		--			_G["ChatFrame" .. i .. "EditBox"]:ClearAllPoints();
		--			_G["ChatFrame" .. i .. "EditBox"]:SetPoint("TOPLEFT", _G["ChatFrame" .. i], 0, 0);
		--			_G["ChatFrame" .. i .. "EditBox"]:SetWidth(_G["ChatFrame" .. i]:GetWidth());
		--			-- Ensure editbox width matches chatframe width
		--			_G["ChatFrame" .. i]:HookScript("OnSizeChanged", function()
		--				_G["ChatFrame" .. i .. "EditBox"]:SetWidth(_G["ChatFrame" .. i]:GetWidth())
		--			end)
		--		end
		--	end

		--	-- Do the functions above for other chat frames (pet battles, whispers, etc)
		--	hooksecurefunc("FCF_OpenTemporaryWindow", function()

		--		local cf = FCF_GetCurrentChatFrame():GetName() or nil
		--		if cf then

		--			-- Position the editbox
		--			_G[cf .. "EditBox"]:ClearAllPoints();
		--			_G[cf .. "EditBox"]:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, 0);
		--			_G[cf .. "EditBox"]:SetWidth(_G[cf]:GetWidth());

		--			-- Ensure editbox width matches chatframe width
		--			_G[cf]:HookScript("OnSizeChanged", function()
		--				_G[cf .. "EditBox"]:SetWidth(_G[cf]:GetWidth())
		--			end)

		--		end
		--	end)

		--end

		----------------------------------------------------------------------
		-- Create panel in game options panel
		----------------------------------------------------------------------

		do

			local interPanel = CreateFrame("FRAME")
			interPanel.name = "unitscan"

			local maintitle = unitscanLC:MakeTx(interPanel, "unitscan", 0, 0)
			maintitle:SetFont(maintitle:GetFont(), 72)
			maintitle:ClearAllPoints()
			maintitle:SetPoint("TOP", 0, -72)

			local expTitle = unitscanLC:MakeTx(interPanel, "Wrath of the Lich King Classic", 0, 0)
			expTitle:SetFont(expTitle:GetFont(), 32)
			expTitle:ClearAllPoints()
			expTitle:SetPoint("TOP", 0, -152)

			local subTitle = unitscanLC:MakeTx(interPanel, "Feedback Discord: sattva108", 0, 0)
			subTitle:SetFont(subTitle:GetFont(), 20)
			subTitle:ClearAllPoints()
			subTitle:SetPoint("BOTTOM", 0, 72)

			local slashTitle = unitscanLC:MakeTx(interPanel, "/unitscan help", 0, 0)
			slashTitle:SetFont(slashTitle:GetFont(), 72)
			slashTitle:ClearAllPoints()
			slashTitle:SetPoint("BOTTOM", subTitle, "TOP", 0, 40)

			local pTex = interPanel:CreateTexture(nil, "BACKGROUND")
			pTex:SetAllPoints()
			pTex:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordgradient2")
			pTex:SetAlpha(0.2)
			pTex:SetTexCoord(0, 1, 1, 0)

			InterfaceOptions_AddCategory(interPanel)

		end


		----------------------------------------------------------------------
		-- Final code for Player
		----------------------------------------------------------------------

		-- Show first run message
		if not unitscanDB["FirstRunMessageSeen"] then
			LibCompat.After(1, function()
				unitscanLC:Print(L["Enter"] .. " \124cff00ff00" .. "/unitscan" .. " \124cffffffff" .. L["or click the minimap button to open unitscan."])
				unitscanDB["FirstRunMessageSeen"] = true
			end)
		end

		-- Register logout event to save settings
		usEvt:RegisterEvent("PLAYER_LOGOUT")

		-- Release memory
		unitscanLC.Player = nil

	end


----------------------------------------------------------------------
--	L45: World
----------------------------------------------------------------------

	function unitscanLC:World()

		----------------------------------------------------------------------
		--	Max camera zoom (no reload required)
		----------------------------------------------------------------------

		do

			---- Function to set camera zoom
			--local function SetZoom()
			--	if unitscanLC["MaxCameraZoom"] == "On" then
			--		SetCVar("cameraDistanceMaxZoomFactor", 4.0)
			--	else
			--		SetCVar("cameraDistanceMaxZoomFactor", 1.9)
			--	end
			--end

			---- Set camera zoom when option is clicked and on startup (if enabled)
			--unitscanCB["MaxCameraZoom"]:HookScript("OnClick", SetZoom)
			--if unitscanLC["MaxCameraZoom"] == "On" then SetZoom() end

		end

	end


----------------------------------------------------------------------
-- 	L50: RunOnce
----------------------------------------------------------------------

	function unitscanLC:RunOnce()

		----------------------------------------------------------------------
		-- Frame alignment grid
		----------------------------------------------------------------------

		do

			-- Create frame alignment grid
			local grid = CreateFrame('FRAME')
			unitscanLC.grid = grid
			grid:Hide()
			grid:SetAllPoints(UIParent)
			local w, h = GetScreenWidth() * UIParent:GetEffectiveScale(), GetScreenHeight() * UIParent:GetEffectiveScale()
			local ratio = w / h
			local sqsize = w / 20
			local wline = floor(sqsize - (sqsize % 2))
			local hline = floor(sqsize / ratio - ((sqsize / ratio) % 2))
			-- Plot vertical lines
			for i = 0, wline do
				local t = unitscanLC.grid:CreateTexture(nil, 'BACKGROUND')
				if i == wline / 2 then t:SetVertexColor(1, 0, 0, 0.5) else t:SetVertexColor(0, 0, 0, 0.5) end
				t:SetPoint('TOPLEFT', grid, 'TOPLEFT', i * w / wline - 1, 0)
				t:SetPoint('BOTTOMRIGHT', grid, 'BOTTOMLEFT', i * w / wline + 1, 0)
			end
			-- Plot horizontal lines
			for i = 0, hline do
				local t = unitscanLC.grid:CreateTexture(nil, 'BACKGROUND')
				if i == hline / 2 then	t:SetVertexColor(1, 0, 0, 0.5) else t:SetVertexColor(0, 0, 0, 0.5) end
				t:SetPoint('TOPLEFT', grid, 'TOPLEFT', 0, -i * h / hline + 1)
				t:SetPoint('BOTTOMRIGHT', grid, 'TOPRIGHT', 0, -i * h / hline - 1)
			end

		end


		--------------------------------------------------------------------------------
		-- End of Grid function
		--------------------------------------------------------------------------------

		----------------------------------------------------------------------
		-- Rare Spawns List
		----------------------------------------------------------------------
		
		local selectedZone = nil

		local zoneButtons = {}

		function unitscanLC:rare_spawns_list()

			do

				-- First - Load the Database of Rare Mobs.
				unitscan_LoadRareSpawns()


				--------------------------------------------------------------------------------
				-- Check for the existence of required tables, stop and create frame if not.
				--------------------------------------------------------------------------------

				if not rare_spawns["CLASSIC"] or not rare_spawns["TBC"] or not rare_spawns["WOTLK"] then
					print("\124cffFF0000unitscan Error: Missing one or more required tables \124cff00FFFFCLASSIC\124cffFF0000, \124cff00FFFFTBC\124cffFF0000, or \124cff00FFFFWOTLK\124cffFF0000 in \124cff00FFFFrare_spawns\124cffFF0000 table.")

					do

						local panelFrame = CreateFrame("FRAME", nil, unitscanLC["Page1"])
						panelFrame:SetAllPoints(unitscanLC["Page1"])

						-- Adjust the position of panelFrame within unitscanLC["Page1"]
						panelFrame:SetPoint("TOPLEFT", unitscanLC["Page1"], "TOPLEFT", 130, 0)

						panelFrame.name = "unitscan"

						local mainTitle = unitscanLC:MakeTx(panelFrame, "unitscan", 0, 0)
						mainTitle:SetFont(mainTitle:GetFont(), 72)
						mainTitle:ClearAllPoints()
						mainTitle:SetPoint("TOP", 0, -72)

						local expTitle = unitscanLC:MakeTx(panelFrame, "Rare Ignore List", 0, 0)
						expTitle:SetFont(expTitle:GetFont(), 32)
						expTitle:ClearAllPoints()
						expTitle:SetPoint("TOP", 0, -152)

						local subTitle = unitscanLC:MakeTx(panelFrame, "Discord: sattva108", 0, 0)
						subTitle:SetFont(subTitle:GetFont(), 20)
						subTitle:ClearAllPoints()
						subTitle:SetPoint("BOTTOM", 0, 72)

						local slashTitleLine1 = unitscanLC:MakeTx(panelFrame, "Your Language database doesn't have", 0, 0)
						slashTitleLine1:SetFont(slashTitleLine1:GetFont(), 20)
						slashTitleLine1:ClearAllPoints()
						slashTitleLine1:SetPoint("BOTTOM", subTitle, "TOP", 0, 40)

						local slashTitleLine2 = unitscanLC:MakeTx(panelFrame, "any rare mobs in it, contact discord", 0, 0)
						slashTitleLine2:SetFont(slashTitleLine2:GetFont(), 20)
						slashTitleLine2:ClearAllPoints()
						slashTitleLine2:SetPoint("BOTTOM", slashTitleLine1, "TOP", 0, -50)

						local panelTexture = panelFrame:CreateTexture(nil, "BACKGROUND")
						panelTexture:SetAllPoints()
						panelTexture:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordgradient2")
						panelTexture:SetAlpha(0.2)
						panelTexture:SetTexCoord(0, 1, 1, 0)

						return

					end

				end


				--------------------------------------------------------------------------------
				-- Define urlencode function for Lua 5.3
				--------------------------------------------------------------------------------


				local function urlencode(str)
					return string.gsub(str, "([^%w%.%- ])", function(c)
						return string.format("%%%02X", string.byte(c))
					end):gsub(" ", "+")
				end

				--------------------------------------------------------------------------------
				-- Create Frame for RARE MOB buttons
				--------------------------------------------------------------------------------


				local eb = CreateFrame("Frame", nil, unitscanLC["Page1"])
				eb:SetSize(220, 280)
				eb:SetPoint("TOPLEFT", 450	, -80)
				eb:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
					edgeSize = 16,
					insets = {left = 8, right = 6, top = 8, bottom = 8},
				})
				eb:SetBackdropBorderColor(1.0, 0.85, 0.0, 0.5)
				eb:SetScale(0.8)

				eb.scroll = CreateFrame("ScrollFrame", nil, eb)
				eb.scroll:SetPoint("TOPLEFT", eb, 12, -10)
				eb.scroll:SetPoint("BOTTOMRIGHT", eb, -30, 10)

				local buttonHeight = 20
				local maxVisibleButtons = 450

				local contentFrame = CreateFrame("Frame", nil, eb.scroll)
				contentFrame:SetSize(eb:GetWidth() - 30, maxVisibleButtons * buttonHeight)
				contentFrame.Buttons = {}

				-- Sort rare spawns by zone and expansion
				local sortedSpawns = {}
				for expansion, spawns in pairs(rare_spawns) do
					for name, zone in pairs(spawns) do
						sortedSpawns[zone] = sortedSpawns[zone] or {}
						table.insert(sortedSpawns[zone], {name = name, expansion = expansion})
					end
				end


				-- Create rare mob buttons
				local index = 1
				for zone, mobs in pairs(sortedSpawns) do
					zoneButtons[zone] = {}
					for _, name in ipairs(mobs) do
						if index <= maxVisibleButtons then
							local button = CreateFrame("Button", nil, contentFrame)
							button:SetSize(contentFrame:GetWidth(), buttonHeight)
							--if index >= 2 then
							--	button:SetPoint("TOPLEFT", 0.5, -(index - 1) * buttonHeight - 0.5) -- Increase the vertical position by 1 to reduce overlap
							--else
								button:SetPoint("TOPLEFT", 0, -(index - 1) * buttonHeight)
							--end

							-- Create a texture region within the button frame
							local texture = button:CreateTexture(nil, "BACKGROUND")
							texture:SetAllPoints(true)
							texture:SetTexture(1.0, 0.5, 0.0, 0.8)
							texture:Hide()

							-- Create a texture region within the button frame
							button.IgnoreTexture = button:CreateTexture(nil, "BACKGROUND")
							button.IgnoreTexture:SetAllPoints(true)

							button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							button.Text:SetPoint("LEFT", 5, 0)

							button:SetScript("OnClick", function(self)
								-- Handle button click event here
								--print("Button clicked: " .. self.Text:GetText())

								--===== refresh nearby targets table =====--
								unitscan.refresh_nearby_targets()

								-- Get the rare mob's name from the button's text
								local rare = string.upper(self.Text:GetText())

								if unitscan_ignored[rare] then
									-- Remove rare from ignore list
									unitscan_ignored[rare] = nil
									unitscan.ignoreprintyellow("\124cffffff00" .. "- " .. rare)
									unitscan.refresh_nearby_targets()
									found[rare] = nil
									self.IgnoreTexture:SetTexture(nil) -- Set button texture to default color
									texture:Show()
								else
									-- Add rare to ignore list
									unitscan_ignored[rare] = true
									unitscan.ignoreprint("+ " .. rare)
									unitscan.refresh_nearby_targets()
									self.IgnoreTexture:SetTexture(1.0, 0.0, 0.0, 0.6) -- Set button texture to red color
									texture:Hide()
								end

								-- Clear focus of search box
								unitscan_searchbox:ClearFocus()
							end)

							--------------------------------------------------------------------------------
							-- WowHead Link OnMouseDown for rare mob
							--------------------------------------------------------------------------------


							button:SetScript("OnMouseDown", function(self, button)
								if button == "RightButton" then
									local rare = self.Text:GetText()
									local encodedRare = urlencode(rare)
									encodedRare = string.gsub(encodedRare, " ", "+") -- Replace space with plus sign
									local wowheadLocale = ""

									if GameLocale == "deDE" then wowheadLocale = "de/search?q="
									elseif GameLocale == "esMX" then wowheadLocale = "es/search?q="
									elseif GameLocale == "esES" then wowheadLocale = "es/search?q="
									elseif GameLocale == "frFR" then wowheadLocale = "fr/search?q="
									elseif GameLocale == "itIT" then wowheadLocale = "it/search?q="
									elseif GameLocale == "ptBR" then wowheadLocale = "pt/search?q="
									elseif GameLocale == "ruRU" then wowheadLocale = "ru/search?q="
									elseif GameLocale == "koKR" then wowheadLocale = "ko/search?q="
									elseif GameLocale == "zhCN" then wowheadLocale = "cn/search?q="
									elseif GameLocale == "zhTW" then wowheadLocale = "cn/search?q="
									else wowheadLocale = "search?q="
									end
									local rareLink = "https://www.wowhead.com/wotlk/" .. wowheadLocale .. encodedRare .. "#npcs"
									unitscanLC:ShowSystemEditBox(rareLink, false)
									unitscan_searchbox:ClearFocus()
								end
							end)

							--------------------------------------------------------------------------------
							-- Other Scripts
							--------------------------------------------------------------------------------


							-- Set button texture update function for OnShow event
							button:SetScript("OnShow", function(self)
								local rare = string.upper(button.Text:GetText())

								if unitscan_ignored[rare] then
									button.IgnoreTexture:SetTexture(1.0, 0.0, 0.0, 0.6) -- Set button texture to red color
								else
									button.IgnoreTexture:SetTexture(nil) -- Set button texture to default color
								end
							end)


							button:SetScript("OnEnter", function(self)
								-- Handle button click event here
								texture:Show()
							end)

							button:SetScript("OnLeave", function(self)
								-- Handle button click event here
								texture:Hide()
							end)

							button.Text:SetText(name)
							-- Initially hide buttons that don't belong to the selected zone
							if zone == selectedZone then
								button:Show()
							else
								button:Hide()
							end

							contentFrame.Buttons[index] = button
							table.insert(zoneButtons[zone], button)
						end
						index = index + 1
					end
				end

				eb.scroll:SetScrollChild(contentFrame)

				-- Scroll functionality
				local scrollbar = CreateFrame("Slider", nil, eb.scroll, "UIPanelScrollBarTemplate")
				scrollbar:SetPoint("TOPRIGHT", eb.scroll, "TOPRIGHT", 20, -14)
				scrollbar:SetPoint("BOTTOMRIGHT", eb.scroll, "BOTTOMRIGHT", 20, 14)

				--scrollbar:SetMinMaxValues(1, 8300)
				local actualMaxVisibleButtons = index - 1
				scrollbar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))

				scrollbar:SetValueStep(1)
				scrollbar:SetValue(1)
				scrollbar:SetWidth(16)
				scrollbar:SetScript("OnValueChanged", function(self, value)
					local min, max = self:GetMinMaxValues()
					local scrollRange = max - maxVisibleButtons + 1
					local newValue = math.max(1, math.min(value, scrollRange))
					self:GetParent():SetVerticalScroll(newValue)
				end)


				eb.scroll.ScrollBar = scrollbar

				-- Mouse wheel scrolling
				eb.scroll:EnableMouseWheel(true)
				eb.scroll:SetScript("OnMouseWheel", function(self, delta)
					scrollbar:SetValue(scrollbar:GetValue() - delta * 250)
				end)

				-- Hide unused buttons
				for i = index, maxVisibleButtons do
					if contentFrame.Buttons[i] then
						contentFrame.Buttons[i]:Hide()
					end
				end



				--------------------------------------------------------------------------------
				-- Create a separate frame for ZONE buttons
				--------------------------------------------------------------------------------


				local zoneFrame = CreateFrame("Frame", nil, eb)
				zoneFrame:SetSize(180, 280)
				zoneFrame:SetPoint("TOPRIGHT", eb, "TOPLEFT", 0, 0)
				zoneFrame:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
					edgeSize = 16,
					insets = {left = 8, right = 6, top = 8, bottom = 8},
				})
				zoneFrame:SetBackdropBorderColor(1.0, 0.85, 0.0, 0.5)
				zoneFrame:SetScale(1)

				zoneFrame.scroll = CreateFrame("ScrollFrame", nil, zoneFrame)
				zoneFrame.scroll:SetPoint("TOPLEFT", zoneFrame, 12, -10)
				zoneFrame.scroll:SetPoint("BOTTOMRIGHT", zoneFrame, -30, 10)

				local buttonHeight = 20
				local zoneMaxVisibleButtons = 1250

				local zoneContentFrame = CreateFrame("Frame", nil, zoneFrame.scroll)
				zoneContentFrame:SetSize(zoneFrame:GetWidth() - 30, zoneMaxVisibleButtons * buttonHeight)
				zoneContentFrame.Buttons = {}

				-- Sort the zone names alphabetically
				local sortedZones = {}
				for zone in pairs(sortedSpawns) do
					table.insert(sortedZones, zone)
				end
				table.sort(sortedZones)

				-- Create zone buttons
				local zoneIndex = 1
				for _, zone in ipairs(sortedZones) do
					if zoneIndex <= zoneMaxVisibleButtons then
						local zoneButton = CreateFrame("Button", nil, zoneContentFrame)
						zoneButton:SetSize(zoneContentFrame:GetWidth(), buttonHeight)
						zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)


						--===== Texture for Mouseover =====--
						local zoneTexture = zoneButton:CreateTexture(nil, "BACKGROUND")
						zoneTexture:SetAllPoints(true)
						zoneTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
						zoneTexture:SetVertexColor(0.0, 0.5, 1.0, 0.8)
						zoneTexture:Hide()

						--===== Texture for selected button =====--
						zoneButton.Texture = zoneButton:CreateTexture(nil, "BACKGROUND")
						zoneButton.Texture:SetAllPoints(true)
						zoneButton.Texture:SetTexture(nil)


						---- DEBUG START
						---- Create a separate font string for numeration
						--local numerationText = zoneButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
						--numerationText:SetPoint("LEFT", 90, 0)
						--numerationText:SetText(zoneIndex .. ".")
						---- DEBUG END

						zoneButton.Text = zoneButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
						zoneButton.Text:SetPoint("LEFT", 5, 0)

						
						--------------------------------------------------------------------------------
						-- Functions to hide all rare mob names and all zone names
						--------------------------------------------------------------------------------


						function unitscan_HideExistingButtons()
							for _, button in ipairs(contentFrame.Buttons) do
								button:Hide()
							end
						end

						function unitscan_HideExistingZoneButtons()
							for _, button in ipairs(zoneContentFrame.Buttons) do
								button:Hide()
							end
						end

						--------------------------------------------------------------------------------
						-- OnClick script
						--------------------------------------------------------------------------------


						-- Modify the existing OnClick function of zone buttons
						zoneButton:SetScript("OnClick", function(self)
							selectedZone = self.Text:GetText()

							-- Reset scroll position to the top
							eb.scroll:SetVerticalScroll(0)

							-- Reset scrollbar value to the top
							scrollbar:SetValue(1)

							unitscan_HideExistingButtons()

							local visibleButtonsCount = 0
							-- Create rare mob buttons for the selected zone
							local index = 1
							for zone, mobs in pairs(sortedSpawns) do
								if zone == selectedZone then
									for _, data in ipairs(mobs) do
										if index <= zoneMaxVisibleButtons then
											visibleButtonsCount = visibleButtonsCount + 1
											local button = contentFrame.Buttons[index]
											if not button then
												button = CreateFrame("Button", nil, contentFrame)
												button:SetSize(contentFrame:GetWidth(), buttonHeight)
												contentFrame.Buttons[index] = button
											end

											-- Set button text and position
											button.Text:SetText(data.name) -- Use the name from data
											--if index >= 2 then
											--	button:SetPoint("TOPLEFT", 0.5, -(index - 1) * buttonHeight - 0.5) -- Increase the vertical position by 1 to reduce overlap
											--else
												button:SetPoint("TOPLEFT", 0, -(index - 1) * buttonHeight)
											--end
											button:Show()

											index = index + 1
										end
									end
								end
							end

							-- Print the number of visible buttons
							--print("Number of visible buttons: " .. visibleButtonsCount)

							-- Hide scrollbar of rare mob list if 13 or more buttons visible.
							if visibleButtonsCount <= 13 then
								eb.scroll.ScrollBar:Hide()
								eb.scroll.ScrollBar:SetMinMaxValues(1, 1)
							else
								eb.scroll.ScrollBar:Show()
								eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
							end


							--===== Texture for selected button =====--
							for _, button in ipairs(zoneContentFrame.Buttons) do
								if button == self then
									-- Apply the clicked texture
									button.Texture:SetTexture(0, 1.0, 0, 0.5)
									zoneTexture:Hide()
								else
									-- Remove texture from other buttons
									button.Texture:SetTexture(nil)
								end
							end

							-- Clear focus of search box
							unitscan_searchbox:ClearFocus()

							-- Hide unused buttons
							for i = index, zoneMaxVisibleButtons do
								if contentFrame.Buttons[i] then
									contentFrame.Buttons[i]:Hide()
								end
							end
						end)






						--------------------------------------------------------------------------------
						-- WoWHead Link for zone
						--------------------------------------------------------------------------------


						zoneButton:SetScript("OnMouseDown", function(self, button)
							if button == "RightButton" then
								local selectedZone = self.Text:GetText()
								local encodedZone = urlencode(selectedZone)
								local wowheadLocale = ""
								if GameLocale == "deDE" then wowheadLocale = "de/search?q="
								elseif GameLocale == "esMX" then wowheadLocale = "es/search?q="
								elseif GameLocale == "esES" then wowheadLocale = "es/search?q="
								elseif GameLocale == "frFR" then wowheadLocale = "fr/search?q="
								elseif GameLocale == "itIT" then wowheadLocale = "it/search?q="
								elseif GameLocale == "ptBR" then wowheadLocale = "pt/search?q="
								elseif GameLocale == "ruRU" then wowheadLocale = "ru/search?q="
								elseif GameLocale == "koKR" then wowheadLocale = "ko/search?q="
								elseif GameLocale == "zhCN" then wowheadLocale = "cn/search?q="
								elseif GameLocale == "zhTW" then wowheadLocale = "cn/search?q="
								else wowheadLocale = "search?q="
								end
								local zoneLink = "https://www.wowhead.com/wotlk/" .. wowheadLocale .. encodedZone .. "#zones"
								unitscanLC:ShowSystemEditBox(zoneLink, false)
								unitscan_searchbox:ClearFocus()
							end
						end)



						--------------------------------------------------------------------------------
						-- OnEvent Script
						--------------------------------------------------------------------------------

						
						zoneButton:SetScript("OnEvent", function()
							if event == "PLAYER_ENTERING_WORLD" then
								LibCompat.After(1, function() unitscan_myzoneGUIButton:Click() end)
								unitscan_myzoneGUIButton:Click()
							end
						end)
						zoneButton:RegisterEvent("PLAYER_ENTERING_WORLD")

						--------------------------------------------------------------------------------
						-- Other Scripts
						--------------------------------------------------------------------------------


						zoneButton:SetScript("OnEnter", function(self)
							-- Handle zone button mouse enter event here
							zoneTexture:Show()
						end)

						zoneButton:SetScript("OnLeave", function(self)
							-- Handle zone button mouse leave event here
							zoneTexture:Hide()
						end)

						--===== Show Zone Text on button and show button itself. =====--
						zoneButton.Text:SetText(zone)
						zoneButton:Show()


						--------------------------------------------------------------------------------
						-- Function to toggle expansions
						--------------------------------------------------------------------------------


						local hideZoneButton = false

						function unitscan_toggleCLASSIC()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 930)
							unitscan_zoneScrollbar:Show()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()						


							unitscan_HideExistingButtons()
							hideZoneButton = not hideZoneButton -- Toggle the variable

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "CLASSIC") then
											shouldHideButton = false -- Show CLASSIC strings
										elseif string.find(data.expansion, "TBC") or string.find(data.expansion, "WOTLK") then
											shouldHideButton = true -- Hide TBC and WOTLK strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end


						function unitscan_toggleTBC()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()						

							unitscan_HideExistingButtons()

							hideZoneButton = not hideZoneButton

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "TBC") then
											shouldHideButton = false -- Show TBC strings
										elseif string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "WOTLK") then
											shouldHideButton = true -- Hide CLASSIC and WOTLK strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end


						function unitscan_toggleWOTLK()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()

							unitscan_HideExistingButtons()

							hideZoneButton = not hideZoneButton

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "WOTLK") then
											shouldHideButton = false -- Show WOTLK strings
										elseif string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "TBC") then
											shouldHideButton = true -- Hide CLASSIC and TBC strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end

						function unitscan_toggleMyZone()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()
							-- Sort the visible zone buttons based on zone names
							local visibleZoneButtons = {}
							for _, button in ipairs(zoneContentFrame.Buttons) do
								if button:IsShown() then
									table.insert(visibleZoneButtons, button)
								end
							end

							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end

						--------------------------------------------------------------------------------
						-- End of toggle Expansions functions.
						--------------------------------------------------------------------------------
						--------------------------------------------------------------------------------
						-- Zone Button Code continues inside loop.
						--------------------------------------------------------------------------------

						zoneContentFrame.Buttons.Texture = zoneButton.Texture
						zoneContentFrame.Buttons[zoneIndex] = zoneButton

					end
					zoneIndex = zoneIndex + 1
				end

				zoneFrame.scroll:SetScrollChild(zoneContentFrame)

				-- Scroll functionality for zone buttons
				local zoneScrollbar = CreateFrame("Slider", nil, zoneFrame.scroll, "UIPanelScrollBarTemplate")
				zoneScrollbar:SetPoint("TOPRIGHT", zoneFrame.scroll, "TOPRIGHT", 20, -14)
				zoneScrollbar:SetPoint("BOTTOMRIGHT", zoneFrame.scroll, "BOTTOMRIGHT", 20, 14)

				zoneScrollbar:SetMinMaxValues(1, zoneMaxVisibleButtons)
				zoneScrollbar:SetValueStep(1)
				zoneScrollbar:SetValue(1)
				zoneScrollbar:SetWidth(16)
				zoneScrollbar:SetScript("OnValueChanged", function(self, value)
					self:GetParent():SetVerticalScroll(value)
				end)

				zoneFrame.scroll.ScrollBar = zoneScrollbar

				-- Mouse wheel scrolling for zone buttons
				zoneFrame.scroll:EnableMouseWheel(true)
				zoneFrame.scroll:SetScript("OnMouseWheel", function(self, delta)
					zoneScrollbar:SetValue(zoneScrollbar:GetValue() - delta * 50)
				end)

				unitscan_zoneScrollbar = zoneScrollbar

				-- Hide unused zone buttons
				for i = zoneIndex, zoneMaxVisibleButtons do
					if zoneContentFrame.Buttons[i] then
						zoneContentFrame.Buttons[i]:Hide()
					end
				end


				--------------------------------------------------------------------------------
				-- Create Buttons for Expansions
				--------------------------------------------------------------------------------


				-- Create a table for each button
				local expbtn = {}

				local selectedButton = nil

				-- Declare visibleButtonsCount as a global variable
				local visibleButtonsCount = 0

				-- Create buttons
				local function MakeButtonNow(title, anchor)
					expbtn[title] = CreateFrame("Button", nil, unitscanLC["Page1"])
					expbtn[title]:SetSize(80, 16)

					-- Create a text label for the button
					expbtn[title].text = expbtn[title]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
					expbtn[title].text:SetPoint("LEFT")
					expbtn[title].text:SetText(title)
					expbtn[title].text:SetJustifyH("LEFT")

					-- Create the expTexture
					local expTexture = expbtn[title]:CreateTexture(nil, "BACKGROUND")
					expTexture:SetAllPoints(true)
					expTexture:SetPoint("RIGHT", -25, 0)
					expTexture:SetPoint("LEFT", 0, 0)

					expTexture:SetTexture(1.0, 0.5, 0.0, 0.6)

					expTexture:Hide()
					expbtn[title].expTexture = expTexture

					-- Set the anchor point based on the provided anchor parameter
					if anchor == "Zones" then
						-- position first button
						expbtn[title]:SetPoint("TOPLEFT", unitscanLC["Page1"], "TOPLEFT", 150, -70)
					else
						-- position other buttons, add gap
						expbtn[title]:SetPoint("TOPLEFT", expbtn[anchor], "BOTTOMLEFT", 0, -5)
					end

					-- Set the OnClick script for the buttons
					if title == "My Zone" then
						expbtn[title]:SetScript("OnClick", function()
							local currentZone = GetZoneText()
							local matchingButton

							-- Hide all zone buttons initially
							for _, button in ipairs(zoneContentFrame.Buttons) do
								button:Hide()
							end

							for _, button in ipairs(zoneContentFrame.Buttons) do
								local zone = button.Text:GetText()
								if zone == currentZone then
									matchingButton = button
									matchingButton:Show()
								end
							end

							unitscan_toggleMyZone()

							-- Update selected button
							if matchingButton then
								matchingButton:Click()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
								selectedButton.expTexture:Show()
							end
						end)

						expbtn[title].text:SetTextColor(1, 1, 1)
						unitscan_myzoneGUIButton = expbtn[title]

						-- Modify the OnClick script for the "Ignored Rares" button
					elseif title == "Ignored" then
						expbtn[title]:SetScript("OnClick", function()
							unitscan_HideExistingButtons()
							unitscan_HideExistingZoneButtons()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()



							visibleButtonsCount = 0 -- Reset visibleButtonsCount

							-- Show all ignored rares
							for rare in pairs(unitscan_ignored) do
								local button = contentFrame.Buttons[visibleButtonsCount + 1]
								if not button then
									button = CreateFrame("Button", nil, contentFrame)
									button:SetSize(contentFrame:GetWidth(), buttonHeight)
									contentFrame.Buttons[visibleButtonsCount + 1] = button
								end

								-- Set button text and position
								button.Text:SetText(rare)
								--if visibleButtonsCount >= 1 then
								--	button:SetPoint("TOPLEFT", 0.5, -(visibleButtonsCount * buttonHeight + 0.5)) -- Increase the vertical position by 1 to reduce overlap
								--else
									button:SetPoint("TOPLEFT", 0, -(visibleButtonsCount * buttonHeight))
								--end
								button:Show()

								visibleButtonsCount = visibleButtonsCount + 1

								-- print(visibleButtonsCount)
								if visibleButtonsCount <= 13 then
									eb.scroll.ScrollBar:Hide()
									eb.scroll.ScrollBar:SetMinMaxValues(1, 1)
								else
									eb.scroll.ScrollBar:Show()
									eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
								end

							end
							-- Clear focus of search box
							unitscan_searchbox:ClearFocus()

							if selectedButton ~= expbtn[title] then
								expbtn[title].expTexture:Show()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
							end

						end)

						--eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
						expbtn[title].text:SetTextColor(1, 0, 0) -- Set text color for the new button
						unitscan_ignoredGUIButton = expbtn[title]

					else
						expbtn[title]:SetScript("OnClick", function()
							if title == "CLASSIC" then
								unitscan_toggleCLASSIC()
							elseif title == "TBC" then
								unitscan_toggleTBC()
							elseif title == "WOTLK" then
								unitscan_toggleWOTLK()
							end

							if selectedButton ~= expbtn[title] then
								expbtn[title].expTexture:Show()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
							end
						end)

						if title == "CLASSIC" then
							expbtn[title].text:SetTextColor(1, 1, 0)
						elseif title == "TBC" then
							expbtn[title].text:SetTextColor(0, 1, 0)
						elseif title == "WOTLK" then
							expbtn[title].text:SetTextColor(0.7, 0.85, 1)
						end
					end

					-- Function to hide the selectedButton.expTexture
					function unitscan_HideSelectedButtonExpTexture()
						if selectedButton and selectedButton.expTexture then
							selectedButton.expTexture:Hide()
						end
					end

					-- Set the OnEnter script for the buttons
					expbtn[title]:SetScript("OnEnter", function()
						-- Show the expTexture on mouseover
						expbtn[title].expTexture:Show()
					end)
					-- Set the OnLeave script for the buttons
					expbtn[title]:SetScript("OnLeave", function()
						-- Hide the expTexture on mouse leave, but only if the button is not the selectedButton
						if selectedButton ~= expbtn[title] then
							expbtn[title].expTexture:Hide()
						end
					end)
				end

				-- Call the MakeButtonNow function for each button
				MakeButtonNow("CLASSIC", "Zones")
				MakeButtonNow("TBC", "CLASSIC")
				MakeButtonNow("WOTLK", "TBC")
				MakeButtonNow("My Zone", "WOTLK")
				MakeButtonNow("Ignored", "My Zone")





				--------------------------------------------------------------------------------
				-- Create Search Box
				--------------------------------------------------------------------------------


				local sBox = unitscanLC:CreateEditBox("RareListSearchBox", unitscanLC["Page1"], 60, 10, "TOPLEFT", 150, -260, "RareListSearchBox", "RareListSearchBox")
				sBox:SetMaxLetters(50)


				--------------------------------------------------------------------------------
				-- Main Searching Logic Functions
				--------------------------------------------------------------------------------

				local function Sanitize(text)
					if type(text) == "string" then
						text = string.gsub(text, "'", "")
						text = string.gsub(text, "%d", "")
					end
					return text
				end

				local function SearchButtons(text)
					GameTooltip:Hide()
					unitscan_HideSelectedButtonExpTexture()
					text = Sanitize(string.lower(text))

					for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
						zoneButton.Texture:SetTexture(nil)
						local zone = zoneButton.Text:GetText()
						local lowerZone = string.lower(zone) -- Convert zone name to lowercase

						-- Find the corresponding mobs for the zone
						local mobs = sortedSpawns[zone]
						if mobs then
							local shouldHideButton = true
							for _, data in ipairs(mobs) do
								if string.find(data.expansion, "TBC") or string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "WOTLK") then
									shouldHideButton = false -- Show buttons with any expansion
									break
								end
							end

							-- Perform case-insensitive search by comparing lowercase zone name
							if shouldHideButton or not string.find(lowerZone, text, 1, true) then
								zoneButton:Hide()
							else
								zoneButton:Show()
							end
						end
					end

					-- Sort the visible zone buttons based on zone names
					local visibleZoneButtons = {}
					for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
						if zoneButton:IsShown() then
							table.insert(visibleZoneButtons, zoneButton)
						end
					end

					table.sort(visibleZoneButtons, function(a, b)
						local zoneA = a.Text:GetText()
						local zoneB = b.Text:GetText()
						return zoneA < zoneB
					end)

					-- Update the button positions based on the sorted table
					local zoneIndex = 1
					for _, zoneButton in ipairs(visibleZoneButtons) do
						zoneButton:ClearAllPoints()
						zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
						zoneIndex = zoneIndex + 1
					end
				end

				--------------------------------------------------------------------------------
				-- Functions for editbox scripts - OnTextChanged, OnEnterPressed, etc...
				--------------------------------------------------------------------------------


				local function SearchEditBox_OnTextChanged(editBox)
					--scroll to top if text changed
					unitscan_zoneScrollbar:SetValue(unitscan_zoneScrollbar:GetMinMaxValues())
					
					local text = editBox:GetText()
					if not text or text:trim() == "" then
						sBox.clearButton:Hide()
					else
						sBox.clearButton:Show()
						SearchButtons(text)
					end
					-- Count visible zone buttons
					local visibleButtonCount = 0
					for _, button in ipairs(zoneContentFrame.Buttons) do
						if button:IsShown() then
							visibleButtonCount = visibleButtonCount + 1
						end
					end


					-- Multiply by button height to get scrollbar maximum   
					local maxValue = visibleButtonCount * 20  
					if visibleButtonCount >= 1 then
						-- Set scrollbar minimum and maximum values   



						-- Hide scrollbar if less than 5 buttons visible
						if visibleButtonCount <= 13 then
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
						else
							unitscan_zoneScrollbar:SetMinMaxValues(1, maxValue)
							unitscan_zoneScrollbar:Show()
						end  

					end

					if visibleButtonCount == 0 then unitscan_zoneScrollbar:SetMinMaxValues(1, 1); unitscan_zoneScrollbar:Hide() end
					-- Print count in chat
					--print(visibleButtonCount .. " zone buttons visible.")
				end

				sBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)

				local function SearchEditBox_OnEscapePressed()
					sBox.searchIcon:Show()
					sBox:ClearFocus()
					sBox:SetText('')
					SearchButtons("")
				end

				sBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)

				local function SearchEditBox_OnEnterPressed(self)
					self:ClearFocus()
				end

				sBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)


				--===== Setup Tooltip =====--
				local function onEnterSearchBox()
					--GameTooltip:SetOwner(sBox, "ANCHOR_RIGHT")
					--GameTooltip:SetOwner(sBox, "ANCHOR_CURSOR_RIGHT",0,-80)
					GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)

					GameTooltip:SetText("Zone Search")
					GameTooltip:AddLine("Enter your search query.")
					GameTooltip:Show()
				end

				local function onLeaveSearchBox()
					GameTooltip:Hide()
				end

				sBox:SetScript("OnEnter", onEnterSearchBox)
				sBox:SetScript("OnLeave", onLeaveSearchBox)


				sBox:SetScript("OnEditFocusGained", function(self)
					self.searchIcon:Hide()
					self.clearButton:Hide()
				end)
				sBox:SetScript("OnEditFocusLost", function(self)
					if self:GetText() == "" then
						self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
						self.clearButton:Hide()
					end
				end)

				unitscan_searchbox = sBox


				--------------------------------------------------------------------------------
				-- Create Search & Close Button, source code from ElvUI - Enhanced.
				--------------------------------------------------------------------------------

				--===== Search Button =====--
				sBox.searchIcon = sBox:CreateTexture(nil, "OVERLAY")
				sBox.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
				sBox.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
				sBox.searchIcon:SetSize(14,14)
				sBox.searchIcon:SetPoint("LEFT", 0, -2)

				--===== Close Button =====--
				local searchClearButton = CreateFrame("Button", nil, sBox)
				searchClearButton.texture = searchClearButton:CreateTexture()
				searchClearButton.texture:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
				searchClearButton.texture:SetSize(17,17)
				searchClearButton.texture:SetPoint("CENTER", 0, 0)
				searchClearButton:SetAlpha(0.5)
				searchClearButton:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
				searchClearButton:SetScript("OnLeave", function(self) self:SetAlpha(0.5) end)
				searchClearButton:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:SetPoint("CENTER", 1, -1) end end)
				searchClearButton:SetScript("OnMouseUp", function(self) self:SetPoint("CENTER") end)
				searchClearButton:SetPoint("RIGHT")
				searchClearButton:SetSize(20, 20)
				searchClearButton:SetText("X")
				searchClearButton:Hide()
				searchClearButton:SetScript('OnClick', SearchEditBox_OnEscapePressed)

				sBox.clearButton = searchClearButton

			end


			--===== End of whole big rare_spawns_list function =====--
		end

		-- Run on startup
		unitscanLC:rare_spawns_list()

		-- Release memory
		unitscanLC.rare_spawns_list = nil
	

		--------------------------------------------------------------------------------
		-- End of Rare Spawns buttons list module.
		--------------------------------------------------------------------------------


		----------------------------------------------------------------------
		-- Custom Scan List
		----------------------------------------------------------------------
		
		local selectedZone = nil

		local zoneButtons = {}

		function unitscanLC:scan_list()

			do

				--------------------------------------------------------------------------------
				-- Escape colors
				--------------------------------------------------------------------------------

				local RED = "\124cffff0000"
				local YELLOW = "\124cffffff00"
				local GREEN = "\124cff00ff00"
				local WHITE = "\124cffffffff"
				local ORANGE = "\124cffffa500"
				local BLUE = "\124cff0000ff"
				local GREY = "\124cffb4b4b4"
				local LYELLOW = "\124cffffff9a"				


				--------------------------------------------------------------------------------
				-- Define urlencode function for Lua 5.3
				--------------------------------------------------------------------------------


				local function urlencode(str)
					return string.gsub(str, "([^%w%.%- ])", function(c)
						return string.format("%%%02X", string.byte(c))
					end):gsub(" ", "+")
				end

				--------------------------------------------------------------------------------
				-- Create Frame for RARE MOB buttons
				--------------------------------------------------------------------------------


				local eb = CreateFrame("Frame", nil, unitscanLC["Page2"])
				eb:SetSize(220, 280)
				eb:SetPoint("TOPLEFT", 450	, -80)
				eb:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
					edgeSize = 16,
					insets = {left = 8, right = 6, top = 8, bottom = 8},
				})
				eb:SetBackdropBorderColor(1.0, 0.85, 0.0, 0.5)
				eb:SetScale(0.8)

				eb.scroll = CreateFrame("ScrollFrame", nil, eb)
				eb.scroll:SetPoint("TOPLEFT", eb, 12, -10)
				eb.scroll:SetPoint("BOTTOMRIGHT", eb, -30, 10)

				local buttonHeight = 20
				local maxVisibleButtons = 450

				local contentFrame = CreateFrame("Frame", nil, eb.scroll)
				contentFrame:SetSize(eb:GetWidth() - 30, maxVisibleButtons * buttonHeight)
				contentFrame.Buttons = {}

				---- Sort rare spawns by zone and expansion
				--local sortedSpawns = {}
				--for expansion, spawns in pairs(rare_spawns) do
				--	for name, zone in pairs(spawns) do
				--		sortedSpawns[zone] = sortedSpawns[zone] or {}
				--		table.insert(sortedSpawns[zone], {name = name, expansion = expansion})
				--	end
				--end

				local sortedSpawns = {}
				for name in pairs(unitscan_targets) do
				    table.insert(sortedSpawns, name)
				end
				table.sort(sortedSpawns)


				-- Create rare mob buttons
				local index = 1
				for zone, mobs in pairs(sortedSpawns) do
					print(zone .. mobs)
					zoneButtons[zone] = {}
					--for _, name in ipairs(mobs) do
						if index <= maxVisibleButtons then
							local button = CreateFrame("Button", nil, contentFrame)
							button:SetSize(contentFrame:GetWidth(), buttonHeight)
							--if index >= 2 then
							--	button:SetPoint("TOPLEFT", 0.5, -(index - 1) * buttonHeight - 0.5) -- Increase the vertical position by 1 to reduce overlap
							--else
								button:SetPoint("TOPLEFT", 0, -(index - 1) * buttonHeight)
							--end

							-- Create a texture region within the button frame
							local texture = button:CreateTexture(nil, "BACKGROUND")
							texture:SetAllPoints(true)
							texture:SetTexture(1.0, 0.5, 0.0, 0.8)
							texture:Hide()

							-- Create a texture region within the button frame
							button.IgnoreTexture = button:CreateTexture(nil, "BACKGROUND")
							button.IgnoreTexture:SetAllPoints(true)

							button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							button.Text:SetPoint("LEFT", 5, 0)

							button:SetScript("OnClick", function(self)
								-- Handle button click event here
								--print("Button clicked: " .. self.Text:GetText())

								----===== refresh nearby targets table =====--
								--unitscan.refresh_nearby_targets()

								---- Get the rare mob's name from the button's text
								--local rare = string.upper(self.Text:GetText())

								--if unitscan_ignored[rare] then
								--	-- Remove rare from ignore list
								--	unitscan_ignored[rare] = nil
								--	unitscan.ignoreprintyellow("\124cffffff00" .. "- " .. rare)
								--	unitscan.refresh_nearby_targets()
								--	found[rare] = nil
								--	self.IgnoreTexture:SetTexture(nil) -- Set button texture to default color
								--	texture:Show()
								--else
								--	-- Add rare to ignore list
								--	unitscan_ignored[rare] = true
								--	unitscan.ignoreprint("+ " .. rare)
								--	unitscan.refresh_nearby_targets()
								--	self.IgnoreTexture:SetTexture(1.0, 0.0, 0.0, 0.6) -- Set button texture to red color
								--	texture:Hide()
								--end

								-- Get the unit name from the button's text
								local key = strupper(self.Text:GetText())

								if not unitscan_targets[key] then
									-- Add unit to scan list
									unitscan_targets[key] = true
									unitscan.print(YELLOW .. "+ " .. key)
									self.IgnoreTexture:SetTexture(nil) -- Set button texture to default color
									texture:Show()
								else
									-- Remove unit from scan list
									unitscan_targets[key] = nil
									unitscan.print(RED .. "- " .. key)
									found[key] = nil
									self.IgnoreTexture:SetTexture(1.0, 0.0, 0.0, 0.6) -- Set button texture to red color
									texture:Hide()

									-- Insert the key into unitscan_removed table
									table.insert(unitscan_removed, key)

								end

								-- Clear focus of search box
								unitscan_searchbox:ClearFocus()
							end)

							--------------------------------------------------------------------------------
							-- WowHead Link OnMouseDown for rare mob
							--------------------------------------------------------------------------------


							button:SetScript("OnMouseDown", function(self, button)
								if button == "RightButton" then
									local rare = self.Text:GetText()
									local encodedRare = urlencode(rare)
									encodedRare = string.gsub(encodedRare, " ", "+") -- Replace space with plus sign
									local wowheadLocale = ""

									if GameLocale == "deDE" then wowheadLocale = "de/search?q="
									elseif GameLocale == "esMX" then wowheadLocale = "es/search?q="
									elseif GameLocale == "esES" then wowheadLocale = "es/search?q="
									elseif GameLocale == "frFR" then wowheadLocale = "fr/search?q="
									elseif GameLocale == "itIT" then wowheadLocale = "it/search?q="
									elseif GameLocale == "ptBR" then wowheadLocale = "pt/search?q="
									elseif GameLocale == "ruRU" then wowheadLocale = "ru/search?q="
									elseif GameLocale == "koKR" then wowheadLocale = "ko/search?q="
									elseif GameLocale == "zhCN" then wowheadLocale = "cn/search?q="
									elseif GameLocale == "zhTW" then wowheadLocale = "cn/search?q="
									else wowheadLocale = "search?q="
									end
									local rareLink = "https://www.wowhead.com/wotlk/" .. wowheadLocale .. encodedRare .. "#npcs"
									unitscanLC:ShowSystemEditBox(rareLink, false)
									unitscan_searchbox:ClearFocus()
								end
							end)

							--------------------------------------------------------------------------------
							-- Other Scripts
							--------------------------------------------------------------------------------


							-- Set button texture update function for OnShow event
							button:SetScript("OnShow", function(self)
								local rare = string.upper(button.Text:GetText())

								if unitscan_ignored[rare] then
									button.IgnoreTexture:SetTexture(1.0, 0.0, 0.0, 0.6) -- Set button texture to red color
								else
									button.IgnoreTexture:SetTexture(nil) -- Set button texture to default color
								end
							end)


							button:SetScript("OnEnter", function(self)
								-- Handle button click event here
								texture:Show()
							end)

							button:SetScript("OnLeave", function(self)
								-- Handle button click event here
								texture:Hide()
							end)

							button.Text:SetText(mobs)
							-- Initially hide buttons that don't belong to the selected zone
							--if zone == selectedZone then
							--	button:Show()
							--else
							--	button:Hide()
							--end

							contentFrame.Buttons[index] = button
							table.insert(zoneButtons[zone], button)
						end
						index = index + 1
					--end
				end

				eb.scroll:SetScrollChild(contentFrame)

				-- Scroll functionality
				local scrollbar = CreateFrame("Slider", nil, eb.scroll, "UIPanelScrollBarTemplate")
				scrollbar:SetPoint("TOPRIGHT", eb.scroll, "TOPRIGHT", 20, -14)
				scrollbar:SetPoint("BOTTOMRIGHT", eb.scroll, "BOTTOMRIGHT", 20, 14)

				--scrollbar:SetMinMaxValues(1, 8300)
				local actualMaxVisibleButtons = index - 1
				scrollbar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))

				scrollbar:SetValueStep(1)
				scrollbar:SetValue(1)
				scrollbar:SetWidth(16)
				scrollbar:SetScript("OnValueChanged", function(self, value)
					local min, max = self:GetMinMaxValues()
					local scrollRange = max - maxVisibleButtons + 1
					local newValue = math.max(1, math.min(value, scrollRange))
					self:GetParent():SetVerticalScroll(newValue)
				end)


				eb.scroll.ScrollBar = scrollbar

				-- Mouse wheel scrolling
				eb.scroll:EnableMouseWheel(true)
				eb.scroll:SetScript("OnMouseWheel", function(self, delta)
					scrollbar:SetValue(scrollbar:GetValue() - delta * 250)
				end)

				-- Hide unused buttons
				for i = index, maxVisibleButtons do
					if contentFrame.Buttons[i] then
						contentFrame.Buttons[i]:Hide()
					end
				end



				--------------------------------------------------------------------------------
				-- Create a separate frame for ZONE buttons
				--------------------------------------------------------------------------------


				local zoneFrame = CreateFrame("Frame", nil, eb)
				zoneFrame:SetSize(180, 280)
				zoneFrame:SetPoint("TOPRIGHT", eb, "TOPLEFT", 0, 0)
				zoneFrame:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
					edgeSize = 16,
					insets = {left = 8, right = 6, top = 8, bottom = 8},
				})
				zoneFrame:SetBackdropBorderColor(1.0, 0.85, 0.0, 0.5)
				zoneFrame:SetScale(1)

				zoneFrame.scroll = CreateFrame("ScrollFrame", nil, zoneFrame)
				zoneFrame.scroll:SetPoint("TOPLEFT", zoneFrame, 12, -10)
				zoneFrame.scroll:SetPoint("BOTTOMRIGHT", zoneFrame, -30, 10)

				local buttonHeight = 20
				local zoneMaxVisibleButtons = 1250

				local zoneContentFrame = CreateFrame("Frame", nil, zoneFrame.scroll)
				zoneContentFrame:SetSize(zoneFrame:GetWidth() - 30, zoneMaxVisibleButtons * buttonHeight)
				zoneContentFrame.Buttons = {}

				-- Sort the zone names alphabetically
				local sortedZones = {}
				for zone in pairs(sortedSpawns) do
					table.insert(sortedZones, zone)
				end
				table.sort(sortedZones)

				-- Create zone buttons
				local zoneIndex = 1
				for _, zone in ipairs(sortedZones) do
					if zoneIndex <= zoneMaxVisibleButtons then
						local zoneButton = CreateFrame("Button", nil, zoneContentFrame)
						zoneButton:SetSize(zoneContentFrame:GetWidth(), buttonHeight)
						zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)


						--===== Texture for Mouseover =====--
						local zoneTexture = zoneButton:CreateTexture(nil, "BACKGROUND")
						zoneTexture:SetAllPoints(true)
						zoneTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
						zoneTexture:SetVertexColor(0.0, 0.5, 1.0, 0.8)
						zoneTexture:Hide()

						--===== Texture for selected button =====--
						zoneButton.Texture = zoneButton:CreateTexture(nil, "BACKGROUND")
						zoneButton.Texture:SetAllPoints(true)
						zoneButton.Texture:SetTexture(nil)


						---- DEBUG START
						---- Create a separate font string for numeration
						--local numerationText = zoneButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
						--numerationText:SetPoint("LEFT", 90, 0)
						--numerationText:SetText(zoneIndex .. ".")
						---- DEBUG END

						zoneButton.Text = zoneButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
						zoneButton.Text:SetPoint("LEFT", 5, 0)

						
						--------------------------------------------------------------------------------
						-- Functions to hide all rare mob names and all zone names
						--------------------------------------------------------------------------------


						function unitscan_HideExistingButtons()
							for _, button in ipairs(contentFrame.Buttons) do
								button:Hide()
							end
						end

						function unitscan_HideExistingZoneButtons()
							for _, button in ipairs(zoneContentFrame.Buttons) do
								button:Hide()
							end
						end

						--------------------------------------------------------------------------------
						-- OnClick script
						--------------------------------------------------------------------------------


						-- Modify the existing OnClick function of zone buttons
						zoneButton:SetScript("OnClick", function(self)
							selectedZone = self.Text:GetText()

							-- Reset scroll position to the top
							eb.scroll:SetVerticalScroll(0)

							-- Reset scrollbar value to the top
							scrollbar:SetValue(1)

							unitscan_HideExistingButtons()

							local visibleButtonsCount = 0
							-- Create rare mob buttons for the selected zone
							local index = 1
							for zone, mobs in pairs(sortedSpawns) do
								if zone == selectedZone then
									--for _, data in ipairs(mobs) do
										if index <= zoneMaxVisibleButtons then
											visibleButtonsCount = visibleButtonsCount + 1
											local button = contentFrame.Buttons[index]
											if not button then
												button = CreateFrame("Button", nil, contentFrame)
												button:SetSize(contentFrame:GetWidth(), buttonHeight)
												contentFrame.Buttons[index] = button
											end

											-- Set button text and position
											button.Text:SetText(data.name) -- Use the name from data
											--if index >= 2 then
											--	button:SetPoint("TOPLEFT", 0.5, -(index - 1) * buttonHeight - 0.5) -- Increase the vertical position by 1 to reduce overlap
											--else
												button:SetPoint("TOPLEFT", 0, -(index - 1) * buttonHeight)
											--end
											button:Show()

											index = index + 1
										end
									--end
								end
							end

							-- Print the number of visible buttons
							--print("Number of visible buttons: " .. visibleButtonsCount)

							-- Hide scrollbar of rare mob list if 13 or more buttons visible.
							if visibleButtonsCount <= 13 then
								eb.scroll.ScrollBar:Hide()
								eb.scroll.ScrollBar:SetMinMaxValues(1, 1)
							else
								eb.scroll.ScrollBar:Show()
								eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
							end


							--===== Texture for selected button =====--
							for _, button in ipairs(zoneContentFrame.Buttons) do
								if button == self then
									-- Apply the clicked texture
									button.Texture:SetTexture(0, 1.0, 0, 0.5)
									zoneTexture:Hide()
								else
									-- Remove texture from other buttons
									button.Texture:SetTexture(nil)
								end
							end

							-- Clear focus of search box
							unitscan_searchbox:ClearFocus()

							-- Hide unused buttons
							for i = index, zoneMaxVisibleButtons do
								if contentFrame.Buttons[i] then
									contentFrame.Buttons[i]:Hide()
								end
							end
						end)






						--------------------------------------------------------------------------------
						-- WoWHead Link for zone
						--------------------------------------------------------------------------------


						zoneButton:SetScript("OnMouseDown", function(self, button)
							if button == "RightButton" then
								local selectedZone = self.Text:GetText()
								local encodedZone = urlencode(selectedZone)
								local wowheadLocale = ""
								if GameLocale == "deDE" then wowheadLocale = "de/search?q="
								elseif GameLocale == "esMX" then wowheadLocale = "es/search?q="
								elseif GameLocale == "esES" then wowheadLocale = "es/search?q="
								elseif GameLocale == "frFR" then wowheadLocale = "fr/search?q="
								elseif GameLocale == "itIT" then wowheadLocale = "it/search?q="
								elseif GameLocale == "ptBR" then wowheadLocale = "pt/search?q="
								elseif GameLocale == "ruRU" then wowheadLocale = "ru/search?q="
								elseif GameLocale == "koKR" then wowheadLocale = "ko/search?q="
								elseif GameLocale == "zhCN" then wowheadLocale = "cn/search?q="
								elseif GameLocale == "zhTW" then wowheadLocale = "cn/search?q="
								else wowheadLocale = "search?q="
								end
								local zoneLink = "https://www.wowhead.com/wotlk/" .. wowheadLocale .. encodedZone .. "#zones"
								unitscanLC:ShowSystemEditBox(zoneLink, false)
								unitscan_searchbox:ClearFocus()
							end
						end)



						--------------------------------------------------------------------------------
						-- OnEvent Script
						--------------------------------------------------------------------------------

						
						--zoneButton:SetScript("OnEvent", function()
						--	if event == "PLAYER_ENTERING_WORLD" then
						--		LibCompat.After(1, function() unitscan_myzoneGUIButton:Click() end)
						--		unitscan_myzoneGUIButton:Click()
						--	end
						--end)
						--zoneButton:RegisterEvent("PLAYER_ENTERING_WORLD")

						--------------------------------------------------------------------------------
						-- Other Scripts
						--------------------------------------------------------------------------------


						zoneButton:SetScript("OnEnter", function(self)
							-- Handle zone button mouse enter event here
							zoneTexture:Show()
						end)

						zoneButton:SetScript("OnLeave", function(self)
							-- Handle zone button mouse leave event here
							zoneTexture:Hide()
						end)

						--===== Show Zone Text on button and show button itself. =====--
						zoneButton.Text:SetText(zone)
						zoneButton:Show()


						--------------------------------------------------------------------------------
						-- Function to toggle expansions
						--------------------------------------------------------------------------------


						local hideZoneButton = false

						function unitscan_toggleCLASSIC()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 930)
							unitscan_zoneScrollbar:Show()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()						


							unitscan_HideExistingButtons()
							hideZoneButton = not hideZoneButton -- Toggle the variable

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "CLASSIC") then
											shouldHideButton = false -- Show CLASSIC strings
										elseif string.find(data.expansion, "TBC") or string.find(data.expansion, "WOTLK") then
											shouldHideButton = true -- Hide TBC and WOTLK strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end


						function unitscan_toggleTBC()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()						

							unitscan_HideExistingButtons()

							hideZoneButton = not hideZoneButton

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "TBC") then
											shouldHideButton = false -- Show TBC strings
										elseif string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "WOTLK") then
											shouldHideButton = true -- Hide CLASSIC and WOTLK strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end


						function unitscan_toggleWOTLK()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()

							unitscan_HideExistingButtons()

							hideZoneButton = not hideZoneButton

							local visibleZoneButtons = {} -- Table to store visible zone buttons

							for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
								zoneButton.Texture:SetTexture(nil)
								local zone = zoneButton.Text:GetText()

								-- Find the corresponding mobs for the zone
								local mobs = sortedSpawns[zone]
								if mobs then
									local shouldHideButton = hideZoneButton
									for _, data in ipairs(mobs) do
										if string.find(data.expansion, "WOTLK") then
											shouldHideButton = false -- Show WOTLK strings
										elseif string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "TBC") then
											shouldHideButton = true -- Hide CLASSIC and TBC strings
											break
										end
									end

									if shouldHideButton then
										zoneButton:Hide()
									else
										zoneButton:Show()
										table.insert(visibleZoneButtons, zoneButton) -- Add visible button to the table
									end
								end
							end

							-- Sort the visible zone buttons based on zone names
							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end

						function unitscan_toggleMyZone()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()
							-- Sort the visible zone buttons based on zone names
							local visibleZoneButtons = {}
							for _, button in ipairs(zoneContentFrame.Buttons) do
								if button:IsShown() then
									table.insert(visibleZoneButtons, button)
								end
							end

							table.sort(visibleZoneButtons, function(a, b)
								local zoneA = a.Text:GetText()
								local zoneB = b.Text:GetText()
								return zoneA < zoneB
							end)

							-- Update the button positions based on the sorted table
							local zoneIndex = 1
							for _, zoneButton in ipairs(visibleZoneButtons) do
								zoneButton:ClearAllPoints()
								zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
								zoneIndex = zoneIndex + 1
							end
						end

						--------------------------------------------------------------------------------
						-- End of toggle Expansions functions.
						--------------------------------------------------------------------------------
						--------------------------------------------------------------------------------
						-- Zone Button Code continues inside loop.
						--------------------------------------------------------------------------------

						zoneContentFrame.Buttons.Texture = zoneButton.Texture
						zoneContentFrame.Buttons[zoneIndex] = zoneButton

					end
					zoneIndex = zoneIndex + 1
				end

				zoneFrame.scroll:SetScrollChild(zoneContentFrame)

				-- Scroll functionality for zone buttons
				local zoneScrollbar = CreateFrame("Slider", nil, zoneFrame.scroll, "UIPanelScrollBarTemplate")
				zoneScrollbar:SetPoint("TOPRIGHT", zoneFrame.scroll, "TOPRIGHT", 20, -14)
				zoneScrollbar:SetPoint("BOTTOMRIGHT", zoneFrame.scroll, "BOTTOMRIGHT", 20, 14)

				zoneScrollbar:SetMinMaxValues(1, zoneMaxVisibleButtons)
				zoneScrollbar:SetValueStep(1)
				zoneScrollbar:SetValue(1)
				zoneScrollbar:SetWidth(16)
				zoneScrollbar:SetScript("OnValueChanged", function(self, value)
					self:GetParent():SetVerticalScroll(value)
				end)

				zoneFrame.scroll.ScrollBar = zoneScrollbar

				-- Mouse wheel scrolling for zone buttons
				zoneFrame.scroll:EnableMouseWheel(true)
				zoneFrame.scroll:SetScript("OnMouseWheel", function(self, delta)
					zoneScrollbar:SetValue(zoneScrollbar:GetValue() - delta * 50)
				end)

				unitscan_zoneScrollbar = zoneScrollbar

				-- Hide unused zone buttons
				for i = zoneIndex, zoneMaxVisibleButtons do
					if zoneContentFrame.Buttons[i] then
						zoneContentFrame.Buttons[i]:Hide()
					end
				end


				--------------------------------------------------------------------------------
				-- Create Buttons for Expansions
				--------------------------------------------------------------------------------


				-- Create a table for each button
				local expbtn = {}

				local selectedButton = nil

				-- Declare visibleButtonsCount as a global variable
				local visibleButtonsCount = 0

				-- Create buttons
				local function MakeButtonNow(title, anchor)
					expbtn[title] = CreateFrame("Button", nil, unitscanLC["Page2"])
					expbtn[title]:SetSize(80, 16)

					-- Create a text label for the button
					expbtn[title].text = expbtn[title]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
					expbtn[title].text:SetPoint("LEFT")
					expbtn[title].text:SetText(title)
					expbtn[title].text:SetJustifyH("LEFT")

					-- Create the expTexture
					local expTexture = expbtn[title]:CreateTexture(nil, "BACKGROUND")
					expTexture:SetAllPoints(true)
					expTexture:SetPoint("RIGHT", -25, 0)
					expTexture:SetPoint("LEFT", 0, 0)

					expTexture:SetTexture(1.0, 0.5, 0.0, 0.6)

					expTexture:Hide()
					expbtn[title].expTexture = expTexture

					-- Set the anchor point based on the provided anchor parameter
					if anchor == "Zones" then
						-- position first button
						expbtn[title]:SetPoint("TOPLEFT", unitscanLC["Page2"], "TOPLEFT", 150, -70)
					else
						-- position other buttons, add gap
						expbtn[title]:SetPoint("TOPLEFT", expbtn[anchor], "BOTTOMLEFT", 0, -5)
					end

					-- Set the OnClick script for the buttons
					if title == "My Zone" then
						expbtn[title]:SetScript("OnClick", function()
							local currentZone = GetZoneText()
							local matchingButton

							-- Hide all zone buttons initially
							for _, button in ipairs(zoneContentFrame.Buttons) do
								button:Hide()
							end

							for _, button in ipairs(zoneContentFrame.Buttons) do
								local zone = button.Text:GetText()
								if zone == currentZone then
									matchingButton = button
									matchingButton:Show()
								end
							end

							unitscan_toggleMyZone()

							-- Update selected button
							if matchingButton then
								matchingButton:Click()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
								selectedButton.expTexture:Show()
							end
						end)

						expbtn[title].text:SetTextColor(1, 1, 1)
						unitscan_myzoneGUIButton = expbtn[title]

						-- Modify the OnClick script for the "Ignored Rares" button
					elseif title == "Ignored" then
						expbtn[title]:SetScript("OnClick", function()
							unitscan_HideExistingButtons()
							unitscan_HideExistingZoneButtons()
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
							eb.scroll.ScrollBar:Hide()
							-- call searchbox
							unitscan_searchbox:ClearFocus()



							visibleButtonsCount = 0 -- Reset visibleButtonsCount

							-- Show all ignored rares
							for rare in pairs(unitscan_ignored) do
								local button = contentFrame.Buttons[visibleButtonsCount + 1]
								if not button then
									button = CreateFrame("Button", nil, contentFrame)
									button:SetSize(contentFrame:GetWidth(), buttonHeight)
									contentFrame.Buttons[visibleButtonsCount + 1] = button
								end

								-- Set button text and position
								button.Text:SetText(rare)
								--if visibleButtonsCount >= 1 then
								--	button:SetPoint("TOPLEFT", 0.5, -(visibleButtonsCount * buttonHeight + 0.5)) -- Increase the vertical position by 1 to reduce overlap
								--else
									button:SetPoint("TOPLEFT", 0, -(visibleButtonsCount * buttonHeight))
								--end
								button:Show()

								visibleButtonsCount = visibleButtonsCount + 1

								-- print(visibleButtonsCount)
								if visibleButtonsCount <= 13 then
									eb.scroll.ScrollBar:Hide()
									eb.scroll.ScrollBar:SetMinMaxValues(1, 1)
								else
									eb.scroll.ScrollBar:Show()
									eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
								end

							end
							-- Clear focus of search box
							unitscan_searchbox:ClearFocus()

							if selectedButton ~= expbtn[title] then
								expbtn[title].expTexture:Show()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
							end

						end)

						--eb.scroll.ScrollBar:SetMinMaxValues(1, (actualMaxVisibleButtons + 400))
						expbtn[title].text:SetTextColor(1, 0, 0) -- Set text color for the new button
						unitscan_ignoredGUIButton = expbtn[title]

					else
						expbtn[title]:SetScript("OnClick", function()
							if title == "CLASSIC" then
								unitscan_toggleCLASSIC()
							elseif title == "TBC" then
								unitscan_toggleTBC()
							elseif title == "WOTLK" then
								unitscan_toggleWOTLK()
							end

							if selectedButton ~= expbtn[title] then
								expbtn[title].expTexture:Show()
								if selectedButton then
									selectedButton.expTexture:Hide()
								end
								selectedButton = expbtn[title]
							end
						end)

						if title == "CLASSIC" then
							expbtn[title].text:SetTextColor(1, 1, 0)
						elseif title == "TBC" then
							expbtn[title].text:SetTextColor(0, 1, 0)
						elseif title == "WOTLK" then
							expbtn[title].text:SetTextColor(0.7, 0.85, 1)
						end
					end

					-- Function to hide the selectedButton.expTexture
					function unitscan_HideSelectedButtonExpTexture()
						if selectedButton and selectedButton.expTexture then
							selectedButton.expTexture:Hide()
						end
					end

					-- Set the OnEnter script for the buttons
					expbtn[title]:SetScript("OnEnter", function()
						-- Show the expTexture on mouseover
						expbtn[title].expTexture:Show()
					end)
					-- Set the OnLeave script for the buttons
					expbtn[title]:SetScript("OnLeave", function()
						-- Hide the expTexture on mouse leave, but only if the button is not the selectedButton
						if selectedButton ~= expbtn[title] then
							expbtn[title].expTexture:Hide()
						end
					end)
				end

				-- Call the MakeButtonNow function for each button
				MakeButtonNow("CLASSIC", "Zones")
				MakeButtonNow("TBC", "CLASSIC")
				MakeButtonNow("WOTLK", "TBC")
				MakeButtonNow("My Zone", "WOTLK")
				MakeButtonNow("Ignored", "My Zone")





				--------------------------------------------------------------------------------
				-- Create Search Box
				--------------------------------------------------------------------------------


				local sBox = unitscanLC:CreateEditBox("RareListSearchBox", unitscanLC["Page2"], 60, 10, "TOPLEFT", 150, -260, "RareListSearchBox", "RareListSearchBox")
				sBox:SetMaxLetters(50)


				--------------------------------------------------------------------------------
				-- Main Searching Logic Functions
				--------------------------------------------------------------------------------

				local function Sanitize(text)
					if type(text) == "string" then
						text = string.gsub(text, "'", "")
						text = string.gsub(text, "%d", "")
					end
					return text
				end

				local function SearchButtons(text)
					GameTooltip:Hide()
					unitscan_HideSelectedButtonExpTexture()
					text = Sanitize(string.lower(text))

					for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
						zoneButton.Texture:SetTexture(nil)
						local zone = zoneButton.Text:GetText()
						local lowerZone = string.lower(zone) -- Convert zone name to lowercase

						-- Find the corresponding mobs for the zone
						local mobs = sortedSpawns[zone]
						if mobs then
							local shouldHideButton = true
							for _, data in ipairs(mobs) do
								if string.find(data.expansion, "TBC") or string.find(data.expansion, "CLASSIC") or string.find(data.expansion, "WOTLK") then
									shouldHideButton = false -- Show buttons with any expansion
									break
								end
							end

							-- Perform case-insensitive search by comparing lowercase zone name
							if shouldHideButton or not string.find(lowerZone, text, 1, true) then
								zoneButton:Hide()
							else
								zoneButton:Show()
							end
						end
					end

					-- Sort the visible zone buttons based on zone names
					local visibleZoneButtons = {}
					for zoneIndex, zoneButton in ipairs(zoneContentFrame.Buttons) do
						if zoneButton:IsShown() then
							table.insert(visibleZoneButtons, zoneButton)
						end
					end

					table.sort(visibleZoneButtons, function(a, b)
						local zoneA = a.Text:GetText()
						local zoneB = b.Text:GetText()
						return zoneA < zoneB
					end)

					-- Update the button positions based on the sorted table
					local zoneIndex = 1
					for _, zoneButton in ipairs(visibleZoneButtons) do
						zoneButton:ClearAllPoints()
						zoneButton:SetPoint("TOPLEFT", 0, -(zoneIndex - 1) * buttonHeight)
						zoneIndex = zoneIndex + 1
					end
				end

				--------------------------------------------------------------------------------
				-- Functions for editbox scripts - OnTextChanged, OnEnterPressed, etc...
				--------------------------------------------------------------------------------


				local function SearchEditBox_OnTextChanged(editBox)
					--scroll to top if text changed
					unitscan_zoneScrollbar:SetValue(unitscan_zoneScrollbar:GetMinMaxValues())
					
					local text = editBox:GetText()
					if not text or text:trim() == "" then
						sBox.clearButton:Hide()
					else
						sBox.clearButton:Show()
						SearchButtons(text)
					end
					-- Count visible zone buttons
					local visibleButtonCount = 0
					for _, button in ipairs(zoneContentFrame.Buttons) do
						if button:IsShown() then
							visibleButtonCount = visibleButtonCount + 1
						end
					end


					-- Multiply by button height to get scrollbar maximum   
					local maxValue = visibleButtonCount * 20  
					if visibleButtonCount >= 1 then
						-- Set scrollbar minimum and maximum values   



						-- Hide scrollbar if less than 5 buttons visible
						if visibleButtonCount <= 13 then
							unitscan_zoneScrollbar:SetMinMaxValues(1, 1)
							unitscan_zoneScrollbar:Hide()
						else
							unitscan_zoneScrollbar:SetMinMaxValues(1, maxValue)
							unitscan_zoneScrollbar:Show()
						end  

					end

					if visibleButtonCount == 0 then unitscan_zoneScrollbar:SetMinMaxValues(1, 1); unitscan_zoneScrollbar:Hide() end
					-- Print count in chat
					--print(visibleButtonCount .. " zone buttons visible.")
				end

				sBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)

				local function SearchEditBox_OnEscapePressed()
					sBox.searchIcon:Show()
					sBox:ClearFocus()
					sBox:SetText('')
					SearchButtons("")
				end

				sBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)

				local function SearchEditBox_OnEnterPressed(self)
					self:ClearFocus()
				end

				sBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)


				--===== Setup Tooltip =====--
				local function onEnterSearchBox()
					--GameTooltip:SetOwner(sBox, "ANCHOR_RIGHT")
					--GameTooltip:SetOwner(sBox, "ANCHOR_CURSOR_RIGHT",0,-80)
					GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)

					GameTooltip:SetText("Zone Search")
					GameTooltip:AddLine("Enter your search query.")
					GameTooltip:Show()
				end

				local function onLeaveSearchBox()
					GameTooltip:Hide()
				end

				sBox:SetScript("OnEnter", onEnterSearchBox)
				sBox:SetScript("OnLeave", onLeaveSearchBox)


				sBox:SetScript("OnEditFocusGained", function(self)
					self.searchIcon:Hide()
					self.clearButton:Hide()
				end)
				sBox:SetScript("OnEditFocusLost", function(self)
					if self:GetText() == "" then
						self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
						self.clearButton:Hide()
					end
				end)

				unitscan_searchbox = sBox


				--------------------------------------------------------------------------------
				-- Create Search & Close Button, source code from ElvUI - Enhanced.
				--------------------------------------------------------------------------------

				--===== Search Button =====--
				sBox.searchIcon = sBox:CreateTexture(nil, "OVERLAY")
				sBox.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
				sBox.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
				sBox.searchIcon:SetSize(14,14)
				sBox.searchIcon:SetPoint("LEFT", 0, -2)

				--===== Close Button =====--
				local searchClearButton = CreateFrame("Button", nil, sBox)
				searchClearButton.texture = searchClearButton:CreateTexture()
				searchClearButton.texture:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
				searchClearButton.texture:SetSize(17,17)
				searchClearButton.texture:SetPoint("CENTER", 0, 0)
				searchClearButton:SetAlpha(0.5)
				searchClearButton:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
				searchClearButton:SetScript("OnLeave", function(self) self:SetAlpha(0.5) end)
				searchClearButton:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:SetPoint("CENTER", 1, -1) end end)
				searchClearButton:SetScript("OnMouseUp", function(self) self:SetPoint("CENTER") end)
				searchClearButton:SetPoint("RIGHT")
				searchClearButton:SetSize(20, 20)
				searchClearButton:SetText("X")
				searchClearButton:Hide()
				searchClearButton:SetScript('OnClick', SearchEditBox_OnEscapePressed)

				sBox.clearButton = searchClearButton


				--===== End of whole big scan_list function =====--
			end

		-- do end
		end

		-- Run on startup
		unitscanLC:scan_list()

		-- Release memory
		unitscanLC.scan_list = nil
	

		--------------------------------------------------------------------------------
		-- End of Custom Scan List module.
		--------------------------------------------------------------------------------

		----------------------------------------------------------------------
		-- Panel alpha
		----------------------------------------------------------------------

		-- Function to set panel alpha
		local function SetPlusAlpha()
			-- Set panel alpha
			unitscanLC["PageF"].t:SetAlpha(1 - unitscanLC["PlusPanelAlpha"])
			-- Show formatted value
			unitscanCB["PlusPanelAlpha"].f:SetFormattedText("%.0f%%", unitscanLC["PlusPanelAlpha"] * 100)
		end

		-- Set alpha on startup
		SetPlusAlpha()

		-- Set alpha after changing slider
		unitscanCB["PlusPanelAlpha"]:HookScript("OnValueChanged", SetPlusAlpha)

		----------------------------------------------------------------------
		-- Panel scale
		----------------------------------------------------------------------

		-- Function to set panel scale
		local function SetPlusScale()
			-- Reset panel position
			unitscanLC["MainPanelA"], unitscanLC["MainPanelR"], unitscanLC["MainPanelX"], unitscanLC["MainPanelY"] = "CENTER", "CENTER", 0, 0
			if unitscanLC["PageF"]:IsShown() then
				unitscanLC["PageF"]:Hide()
				unitscanLC["PageF"]:Show()
			end
			-- Set panel scale
			unitscanLC["PageF"]:SetScale(unitscanLC["PlusPanelScale"])
			-- Update music player highlight bar scale
			--unitscanLC:UpdateList()
		end

		-- Set scale on startup
		unitscanLC["PageF"]:SetScale(unitscanLC["PlusPanelScale"])

		-- Set scale and reset panel position after changing slider
		unitscanCB["PlusPanelScale"]:HookScript("OnMouseUp", SetPlusScale)
		unitscanCB["PlusPanelScale"]:HookScript("OnMouseWheel", SetPlusScale)

		-- Show formatted slider value
		unitscanCB["PlusPanelScale"]:HookScript("OnValueChanged", function()
			unitscanCB["PlusPanelScale"].f:SetFormattedText("%.0f%%", unitscanLC["PlusPanelScale"] * 100)
		end)

		----------------------------------------------------------------------
		-- Options panel
		----------------------------------------------------------------------

		-- Hide Leatrix Plus if game options panel is shown
		InterfaceOptionsFrame:HookScript("OnShow", unitscanLC.HideFrames);
		VideoOptionsFrame:HookScript("OnShow", unitscanLC.HideFrames);




		----------------------------------------------------------------------
		-- Final code for RunOnce
		----------------------------------------------------------------------

		-- Update addon memory usage (speeds up initial value)
		UpdateAddOnMemoryUsage();

		-- Release memory
		unitscanLC.RunOnce = nil

	end



----------------------------------------------------------------------
-- 	L60: Default events
----------------------------------------------------------------------

	local function eventHandler(self, event, arg1, arg2, ...)

		----------------------------------------------------------------------
		-- L62: Profile events
		----------------------------------------------------------------------

		if event == "ADDON_LOADED" then
			if arg1 == "unitscan" then

				-- Replace old var names with new ones
				local function UpdateVars(oldvar, newvar)
					if unitscanDB[oldvar] and not unitscanDB[newvar] then unitscanDB[newvar] = unitscanDB[oldvar]; unitscanDB[oldvar] = nil end
				end

				--UpdateVars("MuteStriders", "MuteMechSteps")					-- 2.5.108 (1st June 2022)
				--UpdateVars("MinimapMod", "MinimapModder")					-- 2.5.120 (24th August 2022)

				---- Automation
				--unitscanLC:LoadVarChk("AutomateQuests", "Off")				-- Automate quests


				-- Settings
				unitscanLC:LoadVarChk("ShowMinimapIcon", "On")				-- Show minimap button
				unitscanLC:LoadVarNum("PlusPanelScale", 1, 1, 2)				-- Panel scale
				unitscanLC:LoadVarNum("PlusPanelAlpha", 0, 0, 1)				-- Panel alpha

				-- Panel position
				unitscanLC:LoadVarAnc("MainPanelA", "CENTER")				-- Panel anchor
				unitscanLC:LoadVarAnc("MainPanelR", "CENTER")				-- Panel relative
				unitscanLC:LoadVarNum("MainPanelX", 0, -5000, 5000)			-- Panel X axis
				unitscanLC:LoadVarNum("MainPanelY", 0, -5000, 5000)			-- Panel Y axis

				-- Start page
				unitscanLC:LoadVarNum("LeaStartPage", 0, 0, unitscanLC["NumberOfPages"])

				-- Lock conflicting options
				do

					-- Function to disable and lock an option and add a note to the tooltip
					local function Lock(option, reason, optmodule)
						usLockList[option] = unitscanLC[option]
						unitscanLC:LockItem(unitscanCB[option], true)
						unitscanCB[option].tiptext = unitscanCB[option].tiptext .. "|n|n|cff00AAFF" .. reason
						if optmodule then
							unitscanCB[option].tiptext = unitscanCB[option].tiptext .. " " .. optmodule .. " " .. L["module"]
						end
						unitscanCB[option].tiptext = unitscanCB[option].tiptext .. "."
						-- Remove hover from configuration button if there is one
						local temp = {unitscanCB[option]:GetChildren()}
						if temp and temp[1] and temp[1].t and temp[1].t:GetTexture() == "Interface\\WorldMap\\Gear_64.png" then
							temp[1]:SetHighlightTexture(0)
							temp[1]:SetScript("OnEnter", nil)
						end
					end

					-- Disable items that conflict with Glass
					if unitscanLC.Glass then
						local reason = L["Cannot be used with Glass"]
						--Lock("UseEasyChatResizing", reason) -- Use easy resizing
						--Lock("NoCombatLogTab", reason) -- Hide the combat log
						--Lock("NoChatButtons", reason) -- Hide chat buttons
						--Lock("UnclampChat", reason) -- Unclamp chat frame
						--Lock("MoveChatEditBoxToTop", reason) -- Move editbox to top
						--Lock("MoreFontSizes", reason) --  More font sizes
						--Lock("NoChatFade", reason) --  Disable chat fade
						--Lock("ClassColorsInChat", reason) -- Use class colors in chat
						--Lock("RecentChatWindow", reason) -- Recent chat window
					end

					-- Disable items that conflict with ElvUI
					if unitscanLC.ElvUI then
						local E = unitscanLC.ElvUI
						if E and E.private then

							local reason = L["Cannot be used with ElvUI"]

							-- Chat
							if E.private.chat.enable then
								--Lock("UseEasyChatResizing", reason, "Chat") -- Use easy resizing
								--Lock("NoCombatLogTab", reason, "Chat") -- Hide the combat log
								--Lock("NoChatButtons", reason, "Chat") -- Hide chat buttons
								--Lock("UnclampChat", reason, "Chat") -- Unclamp chat frame
								--Lock("MoreFontSizes", reason, "Chat") --  More font sizes
								--Lock("NoStickyChat", reason, "Chat") -- Disable sticky chat
								--Lock("UseArrowKeysInChat", reason, "Chat") -- Use arrow keys in chat
								--Lock("NoChatFade", reason, "Chat") -- Disable chat fade
								--Lock("MaxChatHstory", reason, "Chat") -- Increase chat history
								--Lock("RestoreChatMessages", reason, "Chat") -- Restore chat messages
							end

							-- Minimap
							if E.private.general.minimap.enable then
								Lock("MinimapModder", reason, "Minimap") -- Enhance minimap
							end

							-- -- UnitFrames
							-- if E.private.unitframe.enable then
							-- 	Lock("ShowRaidToggle", reason, "UnitFrames") -- Show raid button
							-- end

							-- ActionBars
							if E.private.actionbar.enable then
								--Lock("NoGryphons", reason, "ActionBars") -- Hide gryphons
								--Lock("NoClassBar", reason, "ActionBars") -- Hide stance bar
								--Lock("HideKeybindText", reason, "ActionBars") -- Hide keybind text
								--Lock("HideMacroText", reason, "ActionBars") -- Hide macro text
							end

							-- Bags
							if E.private.bags.enable then
								--Lock("NoBagAutomation", reason, "Bags") -- Disable bag automation
								--Lock("ShowBagSearchBox", reason, "Bags") -- Show bag search box
							end

							-- Tooltip
							if E.private.tooltip.enable then
								--Lock("TipModEnable", reason, "Tooltip") -- Enhance tooltip
							end

							-- Buffs: Disable Blizzard
							if E.private.auras.disableBlizzard then
								--Lock("ManageBuffs", reason, "Buffs and Debuffs (Disable Blizzard)") -- Manage buffs
							end

							-- UnitFrames: Disabled Blizzard: Focus
							if E.private.unitframe.disabledBlizzardFrames.focus then
								--Lock("ManageFocus", reason, "UnitFrames (Disabled Blizzard Frames Focus)") -- Manage focus
							end

							-- UnitFrames: Disabled Blizzard: Player
							if E.private.unitframe.disabledBlizzardFrames.player then
								Lock("ShowPlayerChain", reason, "UnitFrames (Disabled Blizzard Frames Player)") -- Show player chain
								Lock("NoHitIndicators", reason, "UnitFrames (Disabled Blizzard Frames Player)") -- Hide portrait numbers
							end

							-- UnitFrames: Disabled Blizzard: Player and Target
							if E.private.unitframe.disabledBlizzardFrames.player or E.private.unitframe.disabledBlizzardFrames.target then
								--Lock("FrmEnabled", reason, "UnitFrames (Disabled Blizzard Frames Player and Target)") -- Manage frames
							end

							-- UnitFrames: Disabled Blizzard: Player, Target and Focus
							if E.private.unitframe.disabledBlizzardFrames.player or E.private.unitframe.disabledBlizzardFrames.target or E.private.unitframe.disabledBlizzardFrames.focus then
								--Lock("ClassColFrames", reason, "UnitFrames (Disabled Blizzard Frames Player, Target and Focus)") -- Class-colored frames
							end

							-- Skins: Blizzard Gossip Frame
							if E.private.skins.blizzard.enable and E.private.skins.blizzard.gossip then
								--Lock("QuestFontChange", reason, "Skins (Blizzard Gossip Frame)") -- Resize quest font
							end

							-- Base
							do
							--	Lock("ManageWidget", reason) -- Manage widget
								--Lock("ManageTimer", reason) -- Manage timer
								--Lock("ManageDurability", reason) -- Manage durability
								--Lock("ManageVehicle", reason) -- Manage vehicle
							end

						end

						EnableAddOn("unitscan")
					end

				end

				-- Run other startup items
				--unitscanLC:Live()
				--unitscanLC:Isolated()
				unitscanLC:RunOnce()
				unitscanLC:SetDim()

			end
			return
		end


		if event == "PLAYER_LOGIN" then
			unitscanLC:Player()
			collectgarbage()
			return
		end

		if event == "PLAYER_ENTERING_WORLD" then
			unitscanLC:World()
			usEvt:UnregisterEvent("PLAYER_ENTERING_WORLD")
			return
		end

		-- Save locals back to globals on logout
		if event == "PLAYER_LOGOUT" then

			-- Run the logout function without wipe flag
			unitscanLC:PlayerLogout(false)

			-- Settings
			unitscanDB["ShowMinimapIcon"] 		= unitscanLC["ShowMinimapIcon"]
			unitscanDB["PlusPanelScale"] 		= unitscanLC["PlusPanelScale"]
			unitscanDB["PlusPanelAlpha"] 		= unitscanLC["PlusPanelAlpha"]

			-- Panel position
			unitscanDB["MainPanelA"]				= unitscanLC["MainPanelA"]
			unitscanDB["MainPanelR"]				= unitscanLC["MainPanelR"]
			unitscanDB["MainPanelX"]				= unitscanLC["MainPanelX"]
			unitscanDB["MainPanelY"]				= unitscanLC["MainPanelY"]

			-- Start page
			unitscanDB["LeaStartPage"]			= unitscanLC["LeaStartPage"]

			---- Mute game sounds (unitscanLC["MuteGameSounds"])
			--for k, v in pairs(unitscanLC["muteTable"]) do
			--	unitscanDB[k] = unitscanLC[k]
			--end

		end

	end

--	Register event handler
	usEvt:SetScript("OnEvent", eventHandler);





----------------------------------------------------------------------
--	L70: Player logout
----------------------------------------------------------------------

	-- Player Logout
	function unitscanLC:PlayerLogout(wipe)

		----------------------------------------------------------------------
		-- Restore default values for options that do not require reloads
		----------------------------------------------------------------------

		if wipe then

			-- Max camera zoom (unitscanLC["MaxCameraZoom"])
			SetCVar("cameraDistanceMaxZoomFactor", 1.9)


		end



		----------------------------------------------------------------------
		-- Restore default values for options that require reloads
		----------------------------------------------------------------------

		---- More font sizes
		--if unitscanDB["MoreFontSizes"] == "On" and not LeaLockList["MoreFontSizes"] then
		--	if wipe or (not wipe and unitscanLC["MoreFontSizes"] == "Off") then
		--		RunScript('for i = 1, 50 do if _G["ChatFrame" .. i] then local void, fontSize = FCF_GetChatWindowInfo(i); if fontSize and fontSize ~= 12 and fontSize ~= 14 and fontSize ~= 16 and fontSize ~= 18 then FCF_SetChatWindowFontSize(self, _G["ChatFrame" .. i], CHAT_FRAME_DEFAULT_FONT_SIZE) end end end')
		--	end
		--end

	end

----------------------------------------------------------------------
-- 	Options panel functions
----------------------------------------------------------------------

	-- Function to add textures to panels
	function unitscanLC:CreateBar(name, parent, width, height, anchor, r, g, b, alp, tex)
		local ft = parent:CreateTexture(nil, "BORDER")
		ft:SetTexture(tex)
		ft:SetSize(width, height)
		ft:SetPoint(anchor)
		ft:SetVertexColor(r ,g, b, alp)
		if name == "MainTexture" then
			ft:SetTexCoord(0.09, 1, 0, 1);
		end
	end

	-- Create a configuration panel
	function unitscanLC:CreatePanel(title, globref)

		-- Create the panel
		local Side = CreateFrame("Frame", nil, UIParent)

		-- Make it a system frame
		_G["unitscanGlobalPanel_" .. globref] = Side
		table.insert(UISpecialFrames, "unitscanGlobalPanel_" .. globref)

		-- Store it in the configuration panel table
		tinsert(LeaConfigList, Side)

		-- Set frame parameters
		Side:Hide();
		Side:SetSize(570, 370);
		Side:SetClampedToScreen(true)
		Side:SetClampRectInsets(500, -500, -300, 300)
		Side:SetFrameStrata("FULLSCREEN_DIALOG")

		-- Set the background color
		Side.t = Side:CreateTexture(nil, "BACKGROUND")
		Side.t:SetAllPoints()
		Side.t:SetTexture(0.05, 0.05, 0.05, 0.9)

		-- Add a close Button
		Side.c = CreateFrame("Button", nil, Side, "UIPanelCloseButton")
		Side.c:SetSize(30, 30)
		Side.c:SetPoint("TOPRIGHT", 0, 0)
		Side.c:SetScript("OnClick", function() Side:Hide() end)

		-- Add reset, help and back buttons
		Side.r = unitscanLC:CreateButton("ResetButton", Side, "Reset", "TOPLEFT", 16, -292, 0, 25, true, "Click to reset the settings on this page.")
		Side.h = unitscanLC:CreateButton("HelpButton", Side, "Help", "TOPLEFT", 76, -292, 0, 25, true, "No help is available for this page.")
		Side.b = unitscanLC:CreateButton("BackButton", Side, "Back to Main Menu", "TOPRIGHT", -16, -292, 0, 25, true, "Click to return to the main menu.")

		-- Reposition help button so it doesn't overlap reset button
		Side.h:ClearAllPoints()
		Side.h:SetPoint("LEFT", Side.r, "RIGHT", 10, 0)

		-- Remove the click texture from the help button
		Side.h:SetPushedTextOffset(0, 0)

		-- Add a reload button and syncronise it with the main panel reload button
		local reloadb = unitscanLC:CreateButton("ConfigReload", Side, "Reload", "BOTTOMRIGHT", -16, 10, 0, 25, true, unitscanCB["ReloadUIButton"].tiptext)
		unitscanLC:LockItem(reloadb,true)
		reloadb:SetScript("OnClick", ReloadUI)

		reloadb.f = reloadb:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
		reloadb.f:SetHeight(32);
		reloadb.f:SetPoint('RIGHT', reloadb, 'LEFT', -10, 0)
		reloadb.f:SetText(unitscanCB["ReloadUIButton"].f:GetText())
		reloadb.f:Hide()

		unitscanCB["ReloadUIButton"]:HookScript("OnEnable", function()
			unitscanLC:LockItem(reloadb, false)
			reloadb.f:Show()
		end)

		unitscanCB["ReloadUIButton"]:HookScript("OnDisable", function()
			unitscanLC:LockItem(reloadb, true)
			reloadb.f:Hide()
		end)

		-- Set textures
		--unitscanLC:CreateBar("FootTexture", Side, 570, 48, "BOTTOM", 0.5, 0.5, 0.5, 1.0, "Interface\\addons\\unitscan\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")
		unitscanLC:CreateBar("MainTexture", Side, 570, 323, "TOPRIGHT", 0.7, 0.7, 0.7, 0.9,  "Interface\\addons\\unitscan\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")

		-- Allow movement
		Side:EnableMouse(true)
		Side:SetMovable(true)
		Side:RegisterForDrag("LeftButton")
		Side:SetScript("OnDragStart", Side.StartMoving)
		Side:SetScript("OnDragStop", function ()
			Side:StopMovingOrSizing();
			Side:SetUserPlaced(false);
			-- Save panel position
			unitscanLC["MainPanelA"], void, unitscanLC["MainPanelR"], unitscanLC["MainPanelX"], unitscanLC["MainPanelY"] = Side:GetPoint()
		end)

		-- Set panel attributes when shown
		Side:SetScript("OnShow", function()
			Side:ClearAllPoints()
			Side:SetPoint(unitscanLC["MainPanelA"], UIParent, unitscanLC["MainPanelR"], unitscanLC["MainPanelX"], unitscanLC["MainPanelY"])
			Side:SetScale(unitscanLC["PlusPanelScale"])
			Side.t:SetAlpha(1 - unitscanLC["PlusPanelAlpha"])
		end)

		-- Add title
		Side.f = Side:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
		Side.f:SetPoint('TOPLEFT', 16, -16);
		Side.f:SetText(L[title])

		-- Add description
		Side.v = Side:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		Side.v:SetHeight(32);
		Side.v:SetPoint('TOPLEFT', Side.f, 'BOTTOMLEFT', 0, -8);
		Side.v:SetPoint('RIGHT', Side, -32, 0)
		Side.v:SetJustifyH('LEFT'); Side.v:SetJustifyV('TOP');
		Side.v:SetText(L["Configuration Panel"])

		-- Prevent options panel from showing while side panel is showing
		unitscanLC["PageF"]:HookScript("OnShow", function()
			if Side:IsShown() then unitscanLC["PageF"]:Hide(); end
		end)

		-- Return the frame
		return Side

	end

	-- Define subheadings
	function unitscanLC:MakeTx(frame, title, x, y)
		local text = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		text:SetPoint("TOPLEFT", x, y)
		text:SetText(L[title])
		return text
	end

	-- Define text
	function unitscanLC:MakeWD(frame, title, x, y)
		local text = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
		text:SetPoint("TOPLEFT", x, y)
		text:SetText(L[title])
		text:SetJustifyH"LEFT";
		return text
	end

	-- Create a slider control (uses standard template)
	function unitscanLC:MakeSL(frame, field, caption, low, high, step, x, y, form)

		-- Create slider control
		local Slider = CreateFrame("Slider", "unitscanGlobalSlider" .. field, frame, "OptionssliderTemplate")
		unitscanCB[field] = Slider;
		Slider:SetMinMaxValues(low, high)
		Slider:SetValueStep(step)
		Slider:EnableMouseWheel(true)
		Slider:SetPoint('TOPLEFT', x,y)
		Slider:SetWidth(100)
		Slider:SetHeight(20)
		Slider:SetHitRectInsets(0, 0, 0, 0);
		Slider.tiptext = L[caption]
		Slider:SetScript("OnEnter", unitscanLC.TipSee)
		Slider:SetScript("OnLeave", GameTooltip_Hide)

		-- Remove slider text
		_G[Slider:GetName().."Low"]:SetText('');
		_G[Slider:GetName().."High"]:SetText('');

		-- Create slider label
		Slider.f = Slider:CreateFontString(nil, 'BACKGROUND')
		Slider.f:SetFontObject('GameFontHighlight')
		Slider.f:SetPoint('LEFT', Slider, 'RIGHT', 12, 0)
		Slider.f:SetFormattedText("%.2f", Slider:GetValue())

		-- Process mousewheel scrolling
		Slider:SetScript("OnMouseWheel", function(self, arg1)
			if Slider:IsEnabled() then
				local step = step * arg1
				local value = self:GetValue()
				if step > 0 then
					self:SetValue(min(value + step, high))
				else
					self:SetValue(max(value + step, low))
				end
			end
		end)

		-- Process value changed
		Slider:SetScript("OnValueChanged", function(self, value)
			local value = floor((value - low) / step + 0.5) * step + low
			Slider.f:SetFormattedText(form, value)
			unitscanLC[field] = value
		end)

		-- Set slider value when shown
		Slider:SetScript("OnShow", function(self)
			self:SetValue(unitscanLC[field])
		end)

	end

	-- Create a checkbox control (uses standard template)
	function unitscanLC:MakeCB(parent, field, caption, x, y, reload, tip, tipstyle)

		-- Create the checkbox
		local Cbox = CreateFrame('CheckButton', nil, parent, "ChatConfigCheckButtonTemplate")
		unitscanCB[field] = Cbox
		Cbox:SetPoint("TOPLEFT",x, y)
		Cbox:SetScript("OnEnter", unitscanLC.TipSee)
		Cbox:SetScript("OnLeave", GameTooltip_Hide)

		-- Add label and tooltip
		Cbox.f = Cbox:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
		Cbox.f:SetPoint('LEFT', 20, 0)
		if reload then
			-- Checkbox requires UI reload
			Cbox.f:SetText(L[caption] .. "*")
			Cbox.tiptext = L[tip] .. "|n|n* " .. L["Requires UI reload."]
		else
			-- Checkbox does not require UI reload
			Cbox.f:SetText(L[caption])
			Cbox.tiptext = L[tip]
		end

		-- Set label parameters
		Cbox.f:SetJustifyH("LEFT")
		Cbox.f:SetWordWrap(false)

		-- Set maximum label width
		if parent:GetParent() == unitscanLC["PageF"] then
			-- Main panel checkbox labels
			if Cbox.f:GetWidth() > 152 then
				Cbox.f:SetWidth(152)
				unitscanLC["TruncatedLabelsList"] = unitscanLC["TruncatedLabelsList"] or {}
				unitscanLC["TruncatedLabelsList"][Cbox.f] = L[caption]
			end
			-- Set checkbox click width
			if Cbox.f:GetStringWidth() > 152 then
				Cbox:SetHitRectInsets(0, -142, 0, 0)
			else
				Cbox:SetHitRectInsets(0, -Cbox.f:GetStringWidth() + 4, 0, 0)
			end
		else
			-- Configuration panel checkbox labels (other checkboxes either have custom functions or blank labels)
			if Cbox.f:GetWidth() > 302 then
				Cbox.f:SetWidth(302)
				unitscanLC["TruncatedLabelsList"] = unitscanLC["TruncatedLabelsList"] or {}
				unitscanLC["TruncatedLabelsList"][Cbox.f] = L[caption]
			end
			-- Set checkbox click width
			if Cbox.f:GetStringWidth() > 302 then
				Cbox:SetHitRectInsets(0, -292, 0, 0)
			else
				Cbox:SetHitRectInsets(0, -Cbox.f:GetStringWidth() + 4, 0, 0)
			end
		end

		-- Set default checkbox state and click area
		Cbox:SetScript('OnShow', function(self)
			if unitscanLC[field] == "On" then
				self:SetChecked(true)
			else
				self:SetChecked(false)
			end
		end)

		-- Process clicks
		Cbox:SetScript('OnClick', function()
			if Cbox:GetChecked() then
				unitscanLC[field] = "On"
			else
				unitscanLC[field] = "Off"
			end
			unitscanLC:SetDim(); -- Lock invalid options
			unitscanLC:ReloadCheck(); -- Show reload button if needed
			--unitscanLC:Live(); -- Run live code
		end)
	end

	-- Create an editbox (uses standard template)
	function unitscanLC:CreateEditBox(frame, parent, width, maxchars, anchor, x, y, tab, shifttab)

		-- Create editbox
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		unitscanCB[frame] = eb
		eb:SetPoint(anchor, x, y)
		eb:SetWidth(width)
		eb:SetHeight(24)
		eb:SetFontObject("GameFontNormal")
		eb:SetTextColor(1.0, 1.0, 1.0)
		eb:SetAutoFocus(false)
		eb:SetMaxLetters(maxchars)
		eb:SetScript("OnEscapePressed", eb.ClearFocus)
		eb:SetScript("OnEnterPressed", eb.ClearFocus)
		eb:DisableDrawLayer("BACKGROUND")

		-- Add editbox border and backdrop
		eb.f = CreateFrame("FRAME", nil, eb)
		eb.f:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 }})
		eb.f:SetPoint("LEFT", -6, 0)
		eb.f:SetWidth(eb:GetWidth()+6)
		eb.f:SetHeight(eb:GetHeight())
		eb.f:SetBackdropColor(1.0, 1.0, 1.0, 0.3)

		-- Move onto next editbox when tab key is pressed
		eb:SetScript("OnTabPressed", function(self)
			self:ClearFocus()
			if IsShiftKeyDown() then
				unitscanCB[shifttab]:SetFocus()
			else
				unitscanCB[tab]:SetFocus()
			end
		end)

		return eb

	end


	-- Create a standard button (using standard button template)
	function unitscanLC:CreateButton(name, frame, label, anchor, x, y, width, height, reskin, tip, naked)
		local mbtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		unitscanCB[name] = mbtn
		mbtn:SetSize(width, height)
		mbtn:SetPoint(anchor, x, y)
		mbtn:SetHitRectInsets(0, 0, 0, 0)
		mbtn:SetText(L[label])

		-- Create fontstring so the button can be sized correctly
		mbtn.f = mbtn:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		mbtn.f:SetText(L[label])
		if width > 0 then
			-- Button should have static width
			mbtn:SetWidth(width)
		else
			-- Button should have variable width
			mbtn:SetWidth(mbtn.f:GetStringWidth() + 20)
		end

		-- Tooltip handler
		mbtn.tiptext = L[tip]
		mbtn:SetScript("OnEnter", unitscanLC.TipSee)
		mbtn:SetScript("OnLeave", GameTooltip_Hide)

		-- Texture the button
		if reskin then

			-- Set skinned button textures
			if not naked then
				mbtn:SetNormalTexture("Interface\\AddOns\\Leatrix_Plus\\Leatrix_Plus.blp")
				mbtn:GetNormalTexture():SetTexCoord(0.125, 0.25, 0.4375, 0.5)
			end
			mbtn:SetHighlightTexture("Interface\\AddOns\\Leatrix_Plus\\Leatrix_Plus.blp")
			mbtn:GetHighlightTexture():SetTexCoord(0, 0.125, 0.4375, 0.5)

			-- Hide the default textures
			-- mbtn:HookScript("OnShow", function() mbtn.Left:Hide(); mbtn.Middle:Hide(); mbtn.Right:Hide() end)
			-- mbtn:HookScript("OnEnable", function() mbtn.Left:Hide(); mbtn.Middle:Hide(); mbtn.Right:Hide() end)
			-- mbtn:HookScript("OnDisable", function() mbtn.Left:Hide(); mbtn.Middle:Hide(); mbtn.Right:Hide() end)
			-- mbtn:HookScript("OnMouseDown", function() mbtn:GetPushedTexture():Hide() end)
			-- mbtn:HookScript("OnMouseUp", function() mbtn.Left:Hide(); mbtn.Middle:Hide(); mbtn.Right:Hide() end)


			--===== 3.3.5 texture disables =====--

			-- mbtn:GetNormalTexture():SetTexture(nil)
			mbtn:GetPushedTexture():SetTexture(nil)
			-- mbtn:GetDisabledTexture():SetTexture(nil)
			-- mbtn:GetHighlightTexture():SetTexture(nil)

		end

		return mbtn
	end

	-- Create a dropdown menu (using custom function to avoid taint)
	function unitscanLC:CreateDropDown(ddname, label, parent, width, anchor, x, y, items, tip)

		-- Add the dropdown name to a table
		tinsert(LeaDropList, ddname)

		-- Populate variable with item list
		unitscanLC[ddname .. "Table"] = items

		-- Create outer frame
		local frame = CreateFrame("FRAME", nil, parent); frame:SetWidth(width); frame:SetHeight(42); frame:SetPoint("BOTTOMLEFT", parent, anchor, x, y);

		-- Create dropdown inside outer frame
		local dd = CreateFrame("Frame", nil, frame); dd:SetPoint("BOTTOMLEFT", -16, -8); dd:SetPoint("BOTTOMRIGHT", 15, -4); dd:SetHeight(32);

		-- Create dropdown textures
		local lt = dd:CreateTexture(nil, "ARTWORK"); lt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"); lt:SetTexCoord(0, 0.1953125, 0, 1); lt:SetPoint("TOPLEFT", dd, 0, 17); lt:SetWidth(25); lt:SetHeight(64);
		local rt = dd:CreateTexture(nil, "BORDER"); rt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"); rt:SetTexCoord(0.8046875, 1, 0, 1); rt:SetPoint("TOPRIGHT", dd, 0, 17); rt:SetWidth(25); rt:SetHeight(64);
		local mt = dd:CreateTexture(nil, "BORDER"); mt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"); mt:SetTexCoord(0.1953125, 0.8046875, 0, 1); mt:SetPoint("LEFT", lt, "RIGHT"); mt:SetPoint("RIGHT", rt, "LEFT"); mt:SetHeight(64);

		-- Create dropdown label
		local lf = dd:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lf:SetPoint("TOPLEFT", frame, 0, 0); lf:SetPoint("TOPRIGHT", frame, -5, 0); lf:SetJustifyH("LEFT"); lf:SetText(L[label])

		-- Create dropdown placeholder for value (set it using OnShow)
		local value = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		value:SetPoint("LEFT", lt, 26, 2); value:SetPoint("RIGHT", rt, -43, 0); value:SetJustifyH("LEFT"); value:SetWordWrap(false)
		dd:SetScript("OnShow", function() value:SetText(unitscanLC[ddname.."Table"][unitscanLC[ddname]]) end)

		-- Create dropdown button (clicking it opens the dropdown list)
		local dbtn = CreateFrame("Button", nil, dd)
		dbtn:SetPoint("TOPRIGHT", rt, -16, -18); dbtn:SetWidth(24); dbtn:SetHeight(24)
		dbtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"); dbtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down"); dbtn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled"); dbtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight"); dbtn:GetHighlightTexture():SetBlendMode("ADD")
		dbtn.tiptext = tip; dbtn:SetScript("OnEnter", unitscanLC.ShowDropTip)
		dbtn:SetScript("OnLeave", GameTooltip_Hide)

		-- Create dropdown list
		local ddlist =  CreateFrame("Frame",nil,frame)
		unitscanCB["ListFrame"..ddname] = ddlist
		ddlist:SetPoint("TOP",0,-42)
		ddlist:SetWidth(frame:GetWidth())
		ddlist:SetHeight((#items * 16) + 16 + 16)
		ddlist:SetFrameStrata("FULLSCREEN_DIALOG")
		ddlist:SetFrameLevel(12)
		ddlist:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, tileSize = 0, edgeSize = 32, insets = { left = 4, right = 4, top = 4, bottom = 4 }});
		ddlist:Hide()

		-- Hide list if parent is closed
		parent:HookScript("OnHide", function() ddlist:Hide() end)

		-- Create checkmark (it marks the currently selected item)
		local ddlistchk = CreateFrame("FRAME", nil, ddlist)
		ddlistchk:SetHeight(16); ddlistchk:SetWidth(16)
		ddlistchk.t = ddlistchk:CreateTexture(nil, "ARTWORK"); ddlistchk.t:SetAllPoints(); ddlistchk.t:SetTexture("Interface\\Common\\UI-DropDownRadioChecks"); ddlistchk.t:SetTexCoord(0, 0.5, 0.5, 1.0);

		-- Create dropdown list items
		for k, v in pairs(items) do

			local dditem = CreateFrame("Button", nil, unitscanCB["ListFrame"..ddname])
			unitscanCB["Drop"..ddname..k] = dditem;
			dditem:Show();
			dditem:SetWidth(ddlist:GetWidth() - 22)
			dditem:SetHeight(16)
			dditem:SetPoint("TOPLEFT", 12, -k * 16)

			dditem.f = dditem:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
			dditem.f:SetPoint('LEFT', 16, 0)
			dditem.f:SetText(items[k])

			dditem.f:SetWordWrap(false)
			dditem.f:SetJustifyH("LEFT")
			dditem.f:SetWidth(ddlist:GetWidth()-36)

			dditem.t = dditem:CreateTexture(nil, "BACKGROUND")
			dditem.t:SetAllPoints()
			dditem.t:SetTexture(0.3, 0.3, 0.00, 0.8)
			dditem.t:Hide();

			dditem:SetScript("OnEnter", function() dditem.t:Show() end)
			dditem:SetScript("OnLeave", function() dditem.t:Hide() end)
			dditem:SetScript("OnClick", function()
				unitscanLC[ddname] = k
				value:SetText(unitscanLC[ddname.."Table"][k])
				ddlist:Hide(); -- Must be last in click handler as other functions hook it
			end)

			-- Show list when button is clicked
			dbtn:SetScript("OnClick", function()
				-- Show the dropdown
				if ddlist:IsShown() then ddlist:Hide() else
					ddlist:Show();
					ddlistchk:SetPoint("TOPLEFT",10,select(5,unitscanCB["Drop"..ddname..unitscanLC[ddname]]:GetPoint()))
					ddlistchk:Show();
				end;
				-- Hide all other dropdowns except the one we're dealing with
				for void,v in pairs(LeaDropList) do
					if v ~= ddname then
						unitscanCB["ListFrame"..v]:Hide()
					end
				end
			end)

			-- Expand the clickable area of the button to include the entire menu width
			dbtn:SetHitRectInsets(-width+28, 0, 0, 0)

		end

		return frame

	end

----------------------------------------------------------------------
-- 	Create main options panel frame
----------------------------------------------------------------------

	function unitscanLC:CreateMainPanel()

		-- Create the panel
		local PageF = CreateFrame("Frame", nil, UIParent);

		-- Make it a system frame
		_G["unitscanGlobalPanel"] = PageF
		table.insert(UISpecialFrames, "unitscanGlobalPanel")

		-- Set frame parameters
		unitscanLC["PageF"] = PageF
		PageF:SetSize(570,370)
		PageF:Hide();
		PageF:SetFrameStrata("FULLSCREEN_DIALOG")
		PageF:SetClampedToScreen(true)
		PageF:SetClampRectInsets(500, -500, -300, 300)
		PageF:EnableMouse(true)
		PageF:SetMovable(true)
		PageF:RegisterForDrag("LeftButton")
		PageF:SetScript("OnDragStart", PageF.StartMoving)
		PageF:SetScript("OnDragStop", function ()
		PageF:StopMovingOrSizing();
		PageF:SetUserPlaced(false);
		-- Save panel position
		unitscanLC["MainPanelA"], void, unitscanLC["MainPanelR"], unitscanLC["MainPanelX"], unitscanLC["MainPanelY"] = PageF:GetPoint()
		end)

		-- Add background color
		PageF.t = PageF:CreateTexture(nil, "BACKGROUND")
		PageF.t:SetAllPoints()
		PageF.t:SetTexture(0.05, 0.05, 0.05, 0.9)

		-- Add textures
		--unitscanLC:CreateBar("FootTexture", PageF, 570, 42, "BOTTOM", 0.5, 0.5, 0.5, 1.0, "Interface\\addons\\Leatrix_Plus\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")
		unitscanLC:CreateBar("MainTexture", PageF, 440, 348, "TOPRIGHT", 0.7, 0.7, 0.7, 0.7, "Interface\\addons\\Leatrix_Plus\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")
		unitscanLC:CreateBar("MenuTexture", PageF, 130, 348, "TOPLEFT", 0.7, 0.7, 0.7, 0.7, "Interface\\addons\\Leatrix_Plus\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")

		-- Set panel position when shown
		PageF:SetScript("OnShow", function()
			PageF:ClearAllPoints()
			PageF:SetPoint(unitscanLC["MainPanelA"], UIParent, unitscanLC["MainPanelR"], unitscanLC["MainPanelX"], unitscanLC["MainPanelY"])
		end)

		-- Add main title (shown above menu in the corner)
		PageF.mt = PageF:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
		PageF.mt:SetPoint('TOPLEFT', 16, -16)
		PageF.mt:SetText("\124cff00ff00unitscan")

		-- Add version text (shown underneath main title)
		PageF.v = PageF:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		PageF.v:SetHeight(32);
		PageF.v:SetPoint('TOPLEFT', PageF.mt, 'BOTTOMLEFT', 0, -8);
		PageF.v:SetPoint('RIGHT', PageF, -32, 0)
		PageF.v:SetJustifyH('LEFT'); PageF.v:SetJustifyV('TOP');
		PageF.v:SetNonSpaceWrap(true); PageF.v:SetText(L["Version"] .. " " .. unitscanLC["AddonVer"])

		-- Add reload UI Button
		local reloadb = unitscanLC:CreateButton("ReloadUIButton", PageF, "Reload", "BOTTOMRIGHT", -16, 25, 0, 25, true, "Your UI needs to be reloaded for some of the changes to take effect.|n|nYou don't have to click the reload button immediately but you do need to click it when you are done making changes and you want the changes to take effect.")
		unitscanLC:LockItem(reloadb,true)
		reloadb:SetScript("OnClick", ReloadUI)

		reloadb.f = reloadb:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
		reloadb.f:SetHeight(32);
		reloadb.f:SetPoint('RIGHT', reloadb, 'LEFT', -10, 0)
		reloadb.f:SetText(L["Your UI needs to be reloaded."])
		reloadb.f:Hide()

		-- Add close Button
		local CloseB = CreateFrame("Button", nil, PageF, "UIPanelCloseButton")
		CloseB:SetSize(30, 30)
		CloseB:SetPoint("TOPRIGHT", 0, 0)
		CloseB:SetScript("OnClick", unitscanLC.HideFrames)

		---- Add web link Button
		--local PageFAlertButton = unitscanLC:CreateButton("PageFAlertButton", PageF, "You should keybind web link!", "BOTTOMLEFT", 16, 10, 0, 25, true, "You should set a keybind for the web link feature.  It's very useful.|n|nOpen the key bindings window (accessible from the game menu) and click Leatrix Plus.|n|nSet a keybind for Show web link.|n|nNow when your pointer is over an item, NPC or spell (and more), press your keybind to get a web link.")
		--PageFAlertButton:SetPushedTextOffset(0, 0)
		--PageF:HookScript("OnShow", function()
		--	if GetBindingKey("LEATRIX_PLUS_GLOBAL_WEBLINK") then PageFAlertButton:Hide() else PageFAlertButton:Show() end
		--end)

		-- Release memory
		unitscanLC.CreateMainPanel = nil

	end

	unitscanLC:CreateMainPanel();



	----------------------------------------------------------------------
	-- 	L90: Create options panel pages (no content yet)
	----------------------------------------------------------------------

	-- Function to add menu button
	function unitscanLC:MakeMN(name, text, parent, anchor, x, y, width, height, disabled)

		local mbtn = CreateFrame("Button", nil, parent)
		unitscanLC[name] = mbtn
		mbtn:Show();
		mbtn:SetSize(width, height)
		mbtn:SetAlpha(1.0)
		mbtn:SetPoint(anchor, x, y)

		mbtn.t = mbtn:CreateTexture(nil, "BACKGROUND")
		mbtn.t:SetAllPoints()
		mbtn.t:SetTexture("Interface\\Buttons\\WHITE8X8")
		mbtn.t:SetVertexColor(1.0, 0.5, 0.0, 0.8)
		mbtn.t:SetAlpha(0.7)
		mbtn.t:Hide()

		mbtn.s = mbtn:CreateTexture(nil, "BACKGROUND")
		mbtn.s:SetAllPoints()
		mbtn.s:SetTexture("Interface\\Buttons\\WHITE8X8")
		mbtn.s:SetVertexColor(1.0, 0.5, 0.0, 0.8)
		mbtn.s:Hide()

		mbtn.f = mbtn:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		mbtn.f:SetPoint('LEFT', 16, 0)
		mbtn.f:SetText(L[text])

		mbtn:SetScript("OnEnter", function()
			mbtn.t:Show()
		end)

		mbtn:SetScript("OnLeave", function()
			mbtn.t:Hide()
		end)

		if disabled then mbtn:Hide() end

		return mbtn, mbtn.s

	end

	-- Function to create individual options panel pages
	function unitscanLC:MakePage(name, title, menu, menuname, menuparent, menuanchor, menux, menuy, menuwidth, menuheight, disabled)

		-- Create frame
		local oPage = CreateFrame("Frame", nil, unitscanLC["PageF"]);
		unitscanLC[name] = oPage
		oPage:SetAllPoints(unitscanLC["PageF"])
		oPage:Hide();

		-- Add page title
		oPage.s = oPage:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
		oPage.s:SetPoint('TOPLEFT', 146, -16)
		oPage.s:SetText(L[title])

		-- Add menu item if needed
		if menu then
			unitscanLC[menu], unitscanLC[menu .. ".s"] = unitscanLC:MakeMN(menu, menuname, menuparent, menuanchor, menux, menuy, menuwidth, menuheight, disabled)
			unitscanLC[name]:SetScript("OnShow", function() unitscanLC[menu .. ".s"]:Show(); end)
			unitscanLC[name]:SetScript("OnHide", function() unitscanLC[menu .. ".s"]:Hide(); end)
		end

		return oPage;

	end

	-- Create options pages
	unitscanLC["Page0"] = unitscanLC:MakePage("Page0", "Home"			, "unitscanNav0", "Home"			, unitscanLC["PageF"], "TOPLEFT", 16, -72, 112, 20)
	unitscanLC["Page1"] = unitscanLC:MakePage("Page1", "Rare Ignore List"	, "unitscanNav1", "Rare Ignore"	, unitscanLC["PageF"], "TOPLEFT", 16, -112, 112, 20)
	unitscanLC["Page2"] = unitscanLC:MakePage("Page2", "Custom Scan List"		, "unitscanNav2", "Scan List"		, unitscanLC["PageF"], "TOPLEFT", 16, -132, 112, 20)
	unitscanLC["Page3"] = unitscanLC:MakePage("Page3", "Chat"			, "unitscanNav3", "Chat"			, unitscanLC["PageF"], "TOPLEFT", 16, -152, 112, 20, true)
	unitscanLC["Page4"] = unitscanLC:MakePage("Page4", "Text"			, "unitscanNav4", "Text"			, unitscanLC["PageF"], "TOPLEFT", 16, -172, 112, 20, true)
	unitscanLC["Page5"] = unitscanLC:MakePage("Page5", "Interface"	, "unitscanNav5", "Interface"	, unitscanLC["PageF"], "TOPLEFT", 16, -192, 112, 20, true)
	unitscanLC["Page6"] = unitscanLC:MakePage("Page6", "Frames"		, "unitscanNav6", "Frames"		, unitscanLC["PageF"], "TOPLEFT", 16, -212, 112, 20, true)
	unitscanLC["Page7"] = unitscanLC:MakePage("Page7", "System"		, "unitscanNav7", "System"		, unitscanLC["PageF"], "TOPLEFT", 16, -232, 112, 20, true)
	unitscanLC["Page8"] = unitscanLC:MakePage("Page8", "Settings"		, "unitscanNav8", "Settings"		, unitscanLC["PageF"], "TOPLEFT", 16, -272, 112, 20)
	unitscanLC["Page9"] = unitscanLC:MakePage("Page9", "Media"		, "unitscanNav9", "Media"		, unitscanLC["PageF"], "TOPLEFT", 16, -292, 112, 20, true)

	-- Page navigation mechanism
	for i = 0, unitscanLC["NumberOfPages"] do
		unitscanLC["unitscanNav"..i]:SetScript("OnClick", function()
			unitscanLC:HideFrames()
			unitscanLC["PageF"]:Show();
			unitscanLC["Page"..i]:Show();
			unitscanLC["LeaStartPage"] = i
		end)
	end

	-- Use a variable to contain the page number (makes it easier to move options around)
	local pg;

	----------------------------------------------------------------------
	-- 	LC0: Welcome
	----------------------------------------------------------------------

	pg = "Page0";

	unitscanLC:MakeTx(unitscanLC[pg], "Welcome to unitscan.", 146, -72);
	unitscanLC:MakeWD(unitscanLC[pg], "To begin, choose an options page.", 146, -92);

	unitscanLC:MakeTx(unitscanLC[pg], "Help", 146, -132);
	unitscanLC:MakeWD(unitscanLC[pg], "Type" .. "\124cff00ff00" .. " /unitscan help " .. "\124cffffffff" .. "for available chat commands", 146, -152);

	unitscanLC:MakeTx(unitscanLC[pg], "Support", 146, -192);
	unitscanLC:MakeWD(unitscanLC[pg], "\124cff00ff00" .. "Feedback Discord:" .. "\124cffffff00" .. " sattva108", 146, -212);


----------------------------------------------------------------------
-- 	LC1: Automation
----------------------------------------------------------------------

	pg = "Page1";



----------------------------------------------------------------------
-- 	LC2: Social
----------------------------------------------------------------------

	pg = "Page2";


----------------------------------------------------------------------
-- 	LC3: Chat
----------------------------------------------------------------------

	pg = "Page3";


----------------------------------------------------------------------
-- 	LC4: Text
----------------------------------------------------------------------

	pg = "Page4";


----------------------------------------------------------------------
-- 	LC5: Interface
----------------------------------------------------------------------

	pg = "Page5";


----------------------------------------------------------------------
-- 	LC6: Frames
----------------------------------------------------------------------

	pg = "Page6";


----------------------------------------------------------------------
-- 	LC7: System
----------------------------------------------------------------------

	pg = "Page7";


----------------------------------------------------------------------
-- 	LC8: Settings
----------------------------------------------------------------------

	pg = "Page8";

	unitscanLC:MakeTx(unitscanLC[pg], "Addon"						, 146, -72);
	unitscanLC:MakeCB(unitscanLC[pg], "ShowMinimapIcon"			, "Show minimap button"				, 146, -92,		false,	"If checked, a minimap button will be available.|n|nClick - Toggle options panel.|n|nSHIFT-click - Toggle music.|n|nALT-click - Toggle errors (if enabled).|n|nCTRL/SHIFT-click - Toggle Zygor (if installed).|n|nCTRL/ALT-click - Toggle windowed mode.")

	unitscanLC:MakeTx(unitscanLC[pg], "Scale", 340, -72);
	unitscanLC:MakeSL(unitscanLC[pg], "PlusPanelScale", "Drag to set the scale of the Leatrix Plus panel.", 1, 2, 0.1, 340, -92, "%.1f")

	unitscanLC:MakeTx(unitscanLC[pg], "Transparency", 340, -132);
	unitscanLC:MakeSL(unitscanLC[pg], "PlusPanelAlpha", "Drag to set the transparency of the Leatrix Plus panel.", 0, 1, 0.1, 340, -152, "%.1f")



--------------------------------------------------------------------------------
-- Play sound if wasn't played recently.
--------------------------------------------------------------------------------


	do
		local last_played
		
		function unitscan.play_sound()
			if not last_played or GetTime() - last_played > 3 then
				--PlaySoundFile([[Interface\AddOns\unitscan\assets\Event_wardrum_ogre.ogg]], 'Sound')
				--PlaySoundFile([[Sound\Interface\MapPing.wav]], 'Sound')
				last_played = GetTime()
			end
		end
	end


--------------------------------------------------------------------------------
-- Main function to scan for targets.
--------------------------------------------------------------------------------


	function unitscan.target(name)
		forbidden = false
		TargetUnit(name)
		-- unitscan.print(tostring(UnitHealth(name)) .. " " .. name)
		-- if not deadscan and UnitIsCorpse(name) then
		-- 	return
		-- end
		if forbidden then
			if not found[name] then
				found[name] = true
				--FlashClientIcon()
				unitscan.play_sound()
				unitscan.flash.animation:Play()
				unitscan.discovered_unit = name
				if InCombatLockdown() then
					print("\124cFF00FF00" .. "unitscan found - " .. "\124cffffff00" .. name)
				end
			end
		else
			found[name] = false
		end
	end


--------------------------------------------------------------------------------
-- Functions that creates button, and other visuals during alert.
--------------------------------------------------------------------------------


	function unitscan.LOAD()
		UIParent:UnregisterEvent'ADDON_ACTION_FORBIDDEN'
		do
			local flash = CreateFrame'Frame'
			unitscan.flash = flash
			flash:Show()
			flash:SetAllPoints()
			flash:SetAlpha(0)
			flash:SetFrameStrata'LOW'
			SetCVar("Sound_EnableErrorSpeech", 0)
			
			local texture = flash:CreateTexture()
			texture:SetBlendMode'ADD'
			texture:SetAllPoints()
			texture:SetTexture[[Interface\FullScreenTextures\LowHealth]]

			flash.animation = CreateFrame'Frame'
			flash.animation:Hide()
			flash.animation:SetScript('OnUpdate', function(self)
				local t = GetTime() - self.t0
				if t <= .5 then
					flash:SetAlpha(t * 2)
				elseif t <= 1 then
					flash:SetAlpha(1)
				elseif t <= 1.5 then
					flash:SetAlpha(1 - (t - 1) * 2)
				else
					flash:SetAlpha(0)
					self.loops = self.loops - 1
					if self.loops == 0 then
						self.t0 = nil
						self:Hide()
					else
						self.t0 = GetTime()
					end
				end
			end)
			function flash.animation:Play()
				if self.t0 then
					self.loops = 2
				else
					self.t0 = GetTime()
					self.loops = 1
				end
				self:Show()
			end
		end
		
		local button = CreateFrame('Button', 'unitscan_button', UIParent, 'SecureActionButtonTemplate')
		-- first code to set left and right click of button
		button:SetAttribute("type1", "macro")
		button:SetAttribute("type2", "macro")
		-- rest of button code
		button:Hide()
		unitscan.button = button
		button:SetPoint('BOTTOM', UIParent, 0, 128)
		button:SetWidth(150)
		button:SetHeight(42)
		button:SetScale(1.25)
		button:SetMovable(true)
		button:SetUserPlaced(true)
		button:SetClampedToScreen(true)

		-- code to enable ctrl-click to move (it has nothing to do with left and right click function)
		button:SetScript('OnMouseDown', function(self)
		    if IsControlKeyDown() then
		        self:RegisterForClicks("AnyDown", "AnyUp")
		        self:StartMoving()
		    end
		end)
		button:SetScript('OnMouseUp', function(self)
		    self:StopMovingOrSizing()
		    self:RegisterForClicks("AnyDown", "AnyUp")
		end) 

		button:SetFrameStrata'LOW'
		button:SetNormalTexture[[Interface\AddOns\unitscan\assets\UI-Achievement-Parchment-Horizontal]]
		
		if isWOTLK or isTBC then
			button:SetBackdrop{
				tile = true,
				edgeSize = 16,
				edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
			}
			button:SetBackdropBorderColor(unpack(BROWN))
			button:SetScript('OnEnter', function(self)
				self:SetBackdropBorderColor(unpack(YELLOW))
			end)
			button:SetScript('OnLeave', function(self)
				self:SetBackdropBorderColor(unpack(BROWN))
			end)
		end

		function button:set_target(name)
			-- string that adds name text to the button
			self:SetText(name)
			-- second code to set left and right click of button macro texts
			self:SetAttribute("macrotext1", "/cleartarget\n/targetexact " .. name)
			self:SetAttribute("macrotext2", "/click unitscan_close") -- this is made to click "close" button code for which is defined below
			-- rest of code
			self:Show()
			self.glow.animation:Play()
			self.shine.animation:Play()
		end
		
		do
			local background = button:GetNormalTexture()
			background:SetDrawLayer'BACKGROUND'
			background:ClearAllPoints()
			background:SetPoint('BOTTOMLEFT', 3, 3)
			background:SetPoint('TOPRIGHT', -3, -3)
			background:SetTexCoord(0, 1, 0, .25)
		end
		
		do
			local title_background = button:CreateTexture(nil, 'BORDER')
			title_background:SetTexture[[Interface\AddOns\unitscan\assets\UI-Achievement-Title]]
			title_background:SetPoint('TOPRIGHT', -5, -5)
			title_background:SetPoint('LEFT', 5, 0)
			title_background:SetHeight(18)
			title_background:SetTexCoord(0, .9765625, 0, .3125)
			title_background:SetAlpha(.8)


			--===== Create Title (UNIT name) =====--
			local title = button:CreateFontString(nil, 'OVERLAY')
			title:SetFont(GameFontNormal:GetFont(), 14, 'OUTLINE')
			--title:SetWordWrap(false)

			--===== Fix for UNIT name in Chinese, should i add zhTW? =====--
			-- if currentLocale == "zhCN" and isWOTLK then
			-- 	title:SetFont([[Fonts\ZYHei.ttf]], 14)
			-- else	
			-- 	title:SetFont([[Fonts\FRIZQT__.TTF]], 14)
			-- end

			title:SetShadowOffset(1, -1)
			title:SetPoint('TOPLEFT', title_background, 0, 0)
			title:SetPoint('RIGHT', title_background)
			button:SetFontString(title)

			local subtitle = button:CreateFontString(nil, 'OVERLAY')
			subtitle:SetFont([[Fonts\FRIZQT__.TTF]], 14)
			subtitle:SetTextColor(0, 0, 0)
			subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
			subtitle:SetPoint('RIGHT', title)
			subtitle:SetText'Unit Found!'
		end
		
		do
			local model = CreateFrame('PlayerModel', nil, button)
			button.model = model
			model:SetPoint('BOTTOMLEFT', button, 'TOPLEFT', 0, -4)
			model:SetPoint('RIGHT', 0, 0)
			model:SetHeight(button:GetWidth() * .6)
		end
		
		do
			local close = CreateFrame('Button', "unitscan_close", button, 'UIPanelCloseButton')
			close:SetPoint('BOTTOMRIGHT', 5, -5)
			close:SetWidth(32)
			close:SetHeight(32)
			close:SetScale(.8)
			close:SetHitRectInsets(8, 8, 8, 8)
		end
		
		do
			local glow = button.model:CreateTexture(nil, 'OVERLAY')
			button.glow = glow
			glow:SetPoint('CENTER', button, 'CENTER')
			glow:SetWidth(400 / 300 * button:GetWidth())
			glow:SetHeight(171 / 70 * button:GetHeight())
			glow:SetTexture[[Interface\AddOns\unitscan\assets\UI-Achievement-Alert-Glow]]
			glow:SetBlendMode'ADD'
			glow:SetTexCoord(0, .78125, 0, .66796875)
			glow:SetAlpha(0)

			glow.animation = CreateFrame'Frame'
			glow.animation:Hide()
			glow.animation:SetScript('OnUpdate', function(self)
				local t = GetTime() - self.t0
				if t <= .2 then
					glow:SetAlpha(t * 5)
				elseif t <= .7 then
					glow:SetAlpha(1 - (t - .2) * 2)
				else
					glow:SetAlpha(0)
					self:Hide()
				end
			end)
			function glow.animation:Play()
				self.t0 = GetTime()
				self:Show()
			end
		end

		do
			local shine = button:CreateTexture(nil, 'ARTWORK')
			button.shine = shine
			shine:SetPoint('TOPLEFT', button, 0, 8)
			shine:SetWidth(67 / 300 * button:GetWidth())
			shine:SetHeight(1.28 * button:GetHeight())
			shine:SetTexture[[Interface\AddOns\unitscan\assets\UI-Achievement-Alert-Glow]]
			shine:SetBlendMode'ADD'
			shine:SetTexCoord(.78125, .912109375, 0, .28125)
			shine:SetAlpha(0)
			
			shine.animation = CreateFrame'Frame'
			shine.animation:Hide()
			shine.animation:SetScript('OnUpdate', function(self)
				local t = GetTime() - self.t0
				if t <= .3 then
					shine:SetPoint('TOPLEFT', button, 0, 8)
				elseif t <= .7 then
					shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * self.distance, 8)
				end
				if t <= .3 then
					shine:SetAlpha(0)
				elseif t <= .5 then
					shine:SetAlpha(1)
				elseif t <= .7 then
					shine:SetAlpha(1 - (t - .5) * 5)
				else
					shine:SetAlpha(0)
					self:Hide()
				end
			end)
			function shine.animation:Play()
				self.t0 = GetTime()
				self.distance = button:GetWidth() - shine:GetWidth() + 8
				self:Show()
				button:SetAlpha(1)
			end
		end
	end


--------------------------------------------------------------------------------
-- Function to scan for units with conditions. 
--------------------------------------------------------------------------------


do
    unitscan.last_check = GetTime()
    function unitscan.UPDATE()
        if is_resting then return end
        if not InCombatLockdown() and unitscan.discovered_unit then
            unitscan.button:set_target(unitscan.discovered_unit)
            unitscan.discovered_unit = nil
        end
        if GetTime() - unitscan.last_check >= unitscan_defaults.CHECK_INTERVAL then
            unitscan.last_check = GetTime()
            for name in pairs(unitscan_targets) do
                unitscan.target(name)
            end
            for _, target in ipairs(nearby_targets) do
                local name, expansion = unpack(target)
                if expansion == "CLASSIC" or expansion == "TBC" or expansion == "WOTLK" then
                    unitscan.target(name)
                end
            end
        end
    end
end


--------------------------------------------------------------------------------
-- Escape colors
--------------------------------------------------------------------------------

local RED = "\124cffff0000"
local YELLOW = "\124cffffff00"
local GREEN = "\124cff00ff00"
local WHITE = "\124cffffffff"
local ORANGE = "\124cffffa500"
local BLUE = "\124cff0000ff"
local GREY = "\124cffb4b4b4"
local LYELLOW = "\124cffffff9a"


--------------------------------------------------------------------------------
-- Prints to add prefix to message and color text.
--------------------------------------------------------------------------------

	--===== Prints in light yellow =====--
	function unitscan.print(msg)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "/unitscan " .. LYELLOW .. msg)
		end
	end

	--===== prints in green + red =====--
	function unitscan.ignoreprint(msg)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "/unitscan ignore " .. RED .. msg)
		end
	end

	--===== prints in green + lightyellow =====--
	function unitscan.ignoreprintyellow(msg)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "/unitscan ignore " .. LYELLOW .. msg)

		end
	end


--------------------------------------------------------------------------------
-- Function for sorting targets alphabetically. For user QOL.
--------------------------------------------------------------------------------


	function unitscan.sorted_targets()
		local sorted_targets = {}
		for key in pairs(unitscan_targets) do
			tinsert(sorted_targets, key)
		end
		sort(sorted_targets, function(key1, key2) return key1 < key2 end)
		return sorted_targets
	end


--------------------------------------------------------------------------------
-- Function to add current target to the scanning list.
--------------------------------------------------------------------------------


	function unitscan.toggle_target(name)
		local key = strupper(name)
		if unitscan_targets[key] then
			unitscan_targets[key] = nil
			found[key] = nil
			unitscan.print(RED .. '- ' .. key)
		elseif key ~= '' then
			unitscan_targets[key] = true
			unitscan.print(YELLOW .. '+ ' .. key)
		end
	end


	--------------------------------------------------------------------------------
	-- Slash Commands /unitscan
	--------------------------------------------------------------------------------

	-- Slash command function
	function unitscanLC:SlashFunc(parameter)
		local _, _, command, args = string.find(parameter, '^(%S+)%s*(.*)$')

		--===== Slash to put current player target to the unit scanning list. =====--    
		if command == "target" then
			local targetName = UnitName("target")
			if targetName then
				local key = strupper(targetName)
				if not unitscan_targets[key] then
					unitscan_targets[key] = true
					unitscan.print(YELLOW .. "+ " .. key)
				else
					unitscan_targets[key] = nil
					unitscan.print(RED .. "- " .. key)
					found[key] = nil
				end
			else
				unitscan.print("No target selected.")
			end

			--===== Slash to change unit scanning interval. Default is 0.3 =====--    
		elseif command == "interval" then
			local newInterval = tonumber(args)
			if newInterval then
				unitscan_defaults.CHECK_INTERVAL = newInterval
				unitscan.print("Check interval set to " .. newInterval)
			else
				unitscan.print("Invalid interval value. Usage: /unitscan interval <number>")
			end

			--===== Slash Ignore Rare =====--
		elseif command == "ignore" then
			unitscan_LoadRareSpawns()
			if args == "" then
				-- Print list of ignored NPCs
				if next(unitscan_ignored) == nil then
					print("Ignore list is empty.")
				else
					print(YELLOW .. "Ignore list currently contains:")
					for rare in pairs(unitscan_ignored) do
						unitscan.ignoreprint(rare)
					end
				end
				return
			else
				local rare = string.upper(args)
				if rare_spawns["CLASSIC"][rare] or rare_spawns["TBC"][rare] or rare_spawns["WOTLK"][rare] then
					if unitscan_ignored[rare] then
						-- Remove rare from ignore list
						unitscan_ignored[rare] = nil
						unitscan.ignoreprintyellow("- " .. rare)
						unitscan.refresh_nearby_targets()
						found[rare] = nil
					else
						-- Add rare to ignore list
						unitscan_ignored[rare] = true
						unitscan.ignoreprint("+ " .. rare)
						unitscan.refresh_nearby_targets()
					end
				else
					-- Rare does not exist in rare_spawns table
					unitscan.print(YELLOW .. args .. WHITE .. " is not a valid rare spawn.")
				end
				return
			end

		--===== Slash to avoid people confusion if they do /unitscan name =====--    
		elseif command == "name" then
			print(" ")
			unitscan.print("replace " .. YELLOW .. "'name'" .. WHITE .. " with npc you want to scan.")
			print(" - for example: " .. GREEN .. "/unitscan " .. YELLOW .. "Hogger")

			--===== Slash to only print currently tracked non-rare targets. =====--
		elseif command == "list" then
			if unitscan_targets then
				if next(unitscan_targets) == nil then
					unitscan.print("Unit Scanner is currently empty.")
				else
					print(" " .. YELLOW .. "unitscan list" .. WHITE .. " currently contains:")
					for k, v in pairs(unitscan_targets) do
						unitscan.print(tostring(k))
					end
				end
			end

			--===== Slash to show rare spawns that are currently being scanned. =====--    
		elseif command == "nearby" then
			unitscan.print("Is someone missing?")
			unitscan.print(" - Add it to your list with " .. GREEN .. "/unitscan name")
			unitscan.print(YELLOW .. "ignore")
			unitscan.print(" - Adds/removes the rare mob 'name' from the unit scanner " .. YELLOW .. "ignore list.")
			unitscan.print(" ")

			for _, target in ipairs(nearby_targets) do
				local name, expansion = unpack(target)
				if not (name == "Lumbering Horror" or name == "Spirit of the Damned" or name == "Bone Witch") then
					unitscan.print(name)
				end
			end

			--===== Slash to show all avaliable commands =====--    
		elseif command == 'help' then
			-- Prevent options panel from showing if a game options panel is showing
			--if InterfaceOptionsFrame:IsShown() or VideoOptionsFrame:IsShown() or ChatConfigFrame:IsShown() then return end
			---- Prevent options panel from showing if Blizzard Store is showing
			--if StoreFrame and StoreFrame:GetAttribute("isshown") then return end
			-- Toggle the options panel if game options panel is not showing
			if unitscanLC:IsUnitscanShowing() then
				unitscanLC:HideFrames()
				unitscanLC:HideConfigPanels()
			end


			-- Help panel
			if not unitscanLC.HelpFrame then
				local frame = CreateFrame("FRAME", nil, UIParent)
				frame:SetSize(570, 340); frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(100)
				frame.tex = frame:CreateTexture(nil, "BACKGROUND"); frame.tex:SetAllPoints(); 
				frame.tex:SetVertexColor(0.05, 0.05, 0.05, 0.9)
				frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); frame.close:SetSize(30, 30); frame.close:SetPoint("TOPRIGHT", 0, 0); frame.close:SetScript("OnClick", function() frame:Hide() end)
				frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
				frame:SetClampedToScreen(true)
				frame:SetClampRectInsets(450, -450, -300, 300)
				frame:EnableMouse(true)
				frame:SetMovable(true)
				frame:RegisterForDrag("LeftButton")
				frame:SetScript("OnDragStart", frame.StartMoving)
				frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() frame:SetUserPlaced(false) end)
				frame:Hide()
				unitscanLC:CreateBar("HelpPanelMainTexture", frame, 570, 340, "TOPRIGHT", 0.7, 0.7, 0.7, 0.7,  "Interface\\addons\\Leatrix_Plus\\assets\\ui-guildachievement-parchment-horizontal-desaturated.blp")
				-- Panel contents
				local col1, col2, color1 = 10, 120, "|cffffffaa"
				unitscanLC:MakeTx(frame, "unitscan Help", col1, -10)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan", col1, -30)
				unitscanLC:MakeWD(frame, "Toggle options panel.", col2, -30)

				unitscanLC:MakeWD(frame, color1 .. "/unitscan target", col1, -50)
				unitscanLC:MakeWD(frame, "Adds/removes the name of your " .. YELLOW .. "current target" .. WHITE .. " to the scanner.", col2, -50)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan name", col1, -70)
				unitscanLC:MakeWD(frame, "Adds/removes the " .. YELLOW .. "mob/player 'name'" .. WHITE .. " from the unit scanner.", col2, -70)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan nearby", col1, -90)
				unitscanLC:MakeWD(frame, "List of " .. YELLOW .. "rare mob names" .. WHITE .. " that are being scanned in your current zone.", col2, -90)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan ignore", col1, -110)
				unitscanLC:MakeWD(frame, "Adds/removes the rare mob" .. GREEN .. " 'name'" .. WHITE .. " from the unit scanner " .. RED .. "ignore list.", col2, -110)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan list", col1, -130)
				unitscanLC:MakeWD(frame, "Prints in chat" .. GREEN .. " list of NPC/Players " .. WHITE .. "that are currently being scanned", col2, -130)
				unitscanLC:MakeWD(frame, color1 .. "/unitscan interval", col1, -150)
				unitscanLC:MakeWD(frame, "Choose interval, How often should we scan for unit?" .. GREY ..  " Default: 0.3 sec.", col2, -150)

				--unitscanLC:MakeWD(frame, color1 .. "/ltp id", col1, -170)
				--unitscanLC:MakeWD(frame, "Show a web link for whatever the pointer is over.", col2, -170)
				--unitscanLC:MakeWD(frame, color1 .. "/ltp zygor", col1, -190)
				--unitscanLC:MakeWD(frame, "Toggle the Zygor addon (reloads UI).", col2, -190)
				--unitscanLC:MakeWD(frame, color1 .. "/ltp movie <id>", col1, -210)
				--unitscanLC:MakeWD(frame, "Play a movie by its ID.", col2, -210)

				unitscanLC:MakeWD(frame, color1 .. "/rl", col1, -310)
				unitscanLC:MakeWD(frame, "Reload the UI.", col2, -310)
				unitscanLC.HelpFrame = frame
				_G["unitscanGlobalHelpPanel"] = frame
				table.insert(UISpecialFrames, "unitscanGlobalHelpPanel")
			end
			if unitscanLC.HelpFrame:IsShown() then unitscanLC.HelpFrame:Hide() else unitscanLC.HelpFrame:Show() end
			return

			--===== Slash without any arguments (/unitscan) prints currently tracked user-defined units and some basic available slash commands  =====--
			--===== If an agrugment after /unitscan is given, it will add a unit to the scanning targets. =====--
		elseif not command then

			-- Prevent options panel from showing if a game options panel is showing
			if InterfaceOptionsFrame:IsShown() or VideoOptionsFrame:IsShown() or ChatConfigFrame:IsShown() then return end
			-- Prevent options panel from showing if Blizzard Store is showing
			if StoreFrame and StoreFrame:GetAttribute("isshown") then return end
			-- Toggle the options panel if game options panel is not showing
			if unitscanLC:IsUnitscanShowing() then
				unitscanLC:HideFrames()
				unitscanLC:HideConfigPanels()
			else
				unitscanLC:HideFrames()
				unitscanLC["PageF"]:Show()
			end
			unitscanLC["Page"..unitscanLC["LeaStartPage"]]:Show()
		else
			unitscan.toggle_target(parameter)
		end
	end

	-- Slash command for global function
	_G.SLASH_UNITSCAN1 = "/unitscan"
	--_G.SLASH_UNITSCAN2 = "/uns"

	SlashCmdList["UNITSCAN"] = function(self)
	-- Run slash command function
	unitscanLC:SlashFunc(self)
		-- Redirect tainted variables
		RunScript('ACTIVE_CHAT_EDIT_BOX = ACTIVE_CHAT_EDIT_BOX')
		RunScript('LAST_ACTIVE_CHAT_EDIT_BOX = LAST_ACTIVE_CHAT_EDIT_BOX')
	end

	-- Slash command for UI reload
	_G.SLASH_UNITSCAN_RL1 = "/rl"
	SlashCmdList["UNITSCAN_RL"] = function()
		ReloadUI()
	end


--------------------------------------------------------------------------------
-- End of unitscan code
--------------------------------------------------------------------------------

