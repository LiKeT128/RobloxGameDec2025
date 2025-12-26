--[[
	DataValidator.lua
	Data validation and repair system for Memory Rush
	
	Handles:
	- Validating all profile data fields
	- Detecting data corruption
	- Auto-fixing minor issues
	- Logging validation problems
	
	Usage:
		local DataValidator = require(ServerScriptService.Server.DataValidator)
		
		-- Validate a profile
		local issues = DataValidator.ValidateProfile(profileData)
		
		-- Auto-fix issues
		local fixed = DataValidator.AutoFix(profileData)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local DataValidator = {}

-- Issue severity levels
DataValidator.Severity = {
	INFO = 1,      -- Minor issue, informational
	WARNING = 2,   -- Issue that should be fixed
	ERROR = 3,     -- Serious issue that needs immediate attention
	CRITICAL = 4,  -- Data corruption or security issue
}

-- Issue log storage (recent issues per player)
local IssueLog = {} -- [userId] = { {timestamp, severity, message}, ... }
local MAX_LOG_ENTRIES = 100

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ERROR" or level == "CRITICAL" then
		warn(string.format("[DataValidator] %s%s %s: %s", timestamp, userStr, level, message))
	else
		print(string.format("[DataValidator] %s%s %s: %s", timestamp, userStr, level, message))
	end
end

local function AddIssue(issues: table, severity: number, field: string, message: string)
	table.insert(issues, {
		Severity = severity,
		Field = field,
		Message = message,
		Timestamp = os.time(),
	})
end

local function IsValidNumber(value: any, min: number?, max: number?): boolean
	if type(value) ~= "number" then
		return false
	end
	
	if value ~= value then -- NaN check
		return false
	end
	
	if min and value < min then
		return false
	end
	
	if max and value > max then
		return false
	end
	
	return true
end

local function IsValidString(value: any, maxLength: number?): boolean
	if type(value) ~= "string" then
		return false
	end
	
	if maxLength and #value > maxLength then
		return false
	end
	
	return true
end

local function IsValidBoolean(value: any): boolean
	return type(value) == "boolean"
end

local function IsValidTable(value: any): boolean
	return type(value) == "table"
end

--------------------------------------------------------------------------------
-- VALIDATION FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Validate memory data (inventory)
	Checks if all memory IDs are valid and counts are reasonable
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidateMemoryData(profile: table): {table}
	local issues = {}
	
	if not profile.Inventory then
		AddIssue(issues, DataValidator.Severity.ERROR, "Inventory", "Inventory table is missing")
		return issues
	end
	
	if not profile.Inventory.Memories then
		AddIssue(issues, DataValidator.Severity.ERROR, "Inventory.Memories", "Memories table is missing")
		return issues
	end
	
	local memories = profile.Inventory.Memories
	local totalCount = 0
	local invalidMemories = {}
	
	for memoryId, count in pairs(memories) do
		-- Check if memory ID is a string
		if type(memoryId) ~= "string" then
			AddIssue(issues, DataValidator.Severity.WARNING, "Inventory.Memories", 
				string.format("Invalid memory ID type: %s (expected string)", type(memoryId)))
			table.insert(invalidMemories, memoryId)
		-- Check if memory ID exists in registry
		elseif not GameConfig.IsValidMemory(memoryId) then
			AddIssue(issues, DataValidator.Severity.WARNING, "Inventory.Memories." .. memoryId, 
				string.format("Unknown memory ID: %s", memoryId))
			-- Note: We don't remove unknown memories - they might be from a newer version
		end
		
		-- Check if count is valid
		if not IsValidNumber(count, 0, 999999) then
			AddIssue(issues, DataValidator.Severity.ERROR, "Inventory.Memories." .. tostring(memoryId), 
				string.format("Invalid memory count: %s", tostring(count)))
		else
			totalCount = totalCount + count
		end
	end
	
	-- Check TotalMemories consistency
	if profile.Inventory.TotalMemories then
		if profile.Inventory.TotalMemories ~= totalCount then
			AddIssue(issues, DataValidator.Severity.WARNING, "Inventory.TotalMemories", 
				string.format("TotalMemories mismatch: stored=%d, calculated=%d", 
					profile.Inventory.TotalMemories, totalCount))
		end
	end
	
	-- Check for suspiciously high memory counts
	if totalCount > 100000 then
		AddIssue(issues, DataValidator.Severity.CRITICAL, "Inventory", 
			string.format("Suspiciously high total memory count: %d", totalCount))
	end
	
	return issues
end

--[[
	Validate currency data
	Checks if currency values are within reasonable bounds
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidateCurrency(profile: table): {table}
	local issues = {}
	
	if not profile.Currency then
		AddIssue(issues, DataValidator.Severity.ERROR, "Currency", "Currency table is missing")
		return issues
	end
	
	local currency = profile.Currency
	local coinConfig = GameConfig.Currency.Coins
	local gemConfig = GameConfig.Currency.Gems
	
	-- Validate Coins
	if currency.Coins == nil then
		AddIssue(issues, DataValidator.Severity.ERROR, "Currency.Coins", "Coins value is missing")
	elseif not IsValidNumber(currency.Coins, coinConfig.Min, coinConfig.Max) then
		AddIssue(issues, DataValidator.Severity.ERROR, "Currency.Coins", 
			string.format("Invalid Coins value: %s (must be %d-%d)", 
				tostring(currency.Coins), coinConfig.Min, coinConfig.Max))
	end
	
	-- Validate Gems
	if currency.Gems == nil then
		AddIssue(issues, DataValidator.Severity.ERROR, "Currency.Gems", "Gems value is missing")
	elseif not IsValidNumber(currency.Gems, gemConfig.Min, gemConfig.Max) then
		AddIssue(issues, DataValidator.Severity.ERROR, "Currency.Gems", 
			string.format("Invalid Gems value: %s (must be %d-%d)", 
				tostring(currency.Gems), gemConfig.Min, gemConfig.Max))
	end
	
	-- Check for negative values (serious issue)
	if type(currency.Coins) == "number" and currency.Coins < 0 then
		AddIssue(issues, DataValidator.Severity.CRITICAL, "Currency.Coins", 
			string.format("Negative Coins value: %d", currency.Coins))
	end
	
	if type(currency.Gems) == "number" and currency.Gems < 0 then
		AddIssue(issues, DataValidator.Severity.CRITICAL, "Currency.Gems", 
			string.format("Negative Gems value: %d", currency.Gems))
	end
	
	return issues
end

--[[
	Validate statistics data
	Checks for logical consistency in statistics
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidateStatistics(profile: table): {table}
	local issues = {}
	
	if not profile.Statistics then
		AddIssue(issues, DataValidator.Severity.ERROR, "Statistics", "Statistics table is missing")
		return issues
	end
	
	local stats = profile.Statistics
	
	-- Required stat fields
	local requiredStats = {
		"MemoriesOpened", "MemoriesUniqueCollected", "TradesCompleted",
		"GiftsGiven", "GiftsReceived", "LastMemoryOpenTime", "SessionCount"
	}
	
	for _, statName in ipairs(requiredStats) do
		if stats[statName] == nil then
			AddIssue(issues, DataValidator.Severity.WARNING, "Statistics." .. statName, 
				statName .. " is missing")
		elseif not IsValidNumber(stats[statName], 0) then
			AddIssue(issues, DataValidator.Severity.ERROR, "Statistics." .. statName, 
				string.format("Invalid %s value: %s", statName, tostring(stats[statName])))
		end
	end
	
	-- Logical consistency checks
	
	-- UniqueCollected should not exceed total unique memories in game
	local totalUniqueInGame = 0
	for _ in pairs(GameConfig.MemoryRegistry) do
		totalUniqueInGame = totalUniqueInGame + 1
	end
	
	if stats.MemoriesUniqueCollected and stats.MemoriesUniqueCollected > totalUniqueInGame then
		AddIssue(issues, DataValidator.Severity.ERROR, "Statistics.MemoriesUniqueCollected", 
			string.format("UniqueCollected (%d) exceeds total unique memories in game (%d)", 
				stats.MemoriesUniqueCollected, totalUniqueInGame))
	end
	
	-- UniqueCollected should not exceed MemoriesOpened
	if stats.MemoriesUniqueCollected and stats.MemoriesOpened then
		if stats.MemoriesUniqueCollected > stats.MemoriesOpened then
			AddIssue(issues, DataValidator.Severity.WARNING, "Statistics", 
				string.format("UniqueCollected (%d) exceeds MemoriesOpened (%d)", 
					stats.MemoriesUniqueCollected, stats.MemoriesOpened))
		end
	end
	
	-- Timestamp validation
	local now = os.time()
	local releaseDate = 1700000000 -- Approximate game release timestamp
	
	if stats.LastMemoryOpenTime and stats.LastMemoryOpenTime > 0 then
		if stats.LastMemoryOpenTime < releaseDate then
			AddIssue(issues, DataValidator.Severity.WARNING, "Statistics.LastMemoryOpenTime", 
				"Timestamp is before game release")
		elseif stats.LastMemoryOpenTime > now + 86400 then -- More than 1 day in future
			AddIssue(issues, DataValidator.Severity.ERROR, "Statistics.LastMemoryOpenTime", 
				"Timestamp is in the future")
		end
	end
	
	-- SessionCount should be reasonable
	if stats.SessionCount and stats.SessionCount > 1000000 then
		AddIssue(issues, DataValidator.Severity.CRITICAL, "Statistics.SessionCount", 
			string.format("Unreasonably high session count: %d", stats.SessionCount))
	end
	
	return issues
end

--[[
	Validate settings data
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidateSettings(profile: table): {table}
	local issues = {}
	
	if not profile.Settings then
		AddIssue(issues, DataValidator.Severity.WARNING, "Settings", "Settings table is missing")
		return issues
	end
	
	local settings = profile.Settings
	
	-- Validate Language
	if settings.Language then
		if not IsValidString(settings.Language, 10) then
			AddIssue(issues, DataValidator.Severity.WARNING, "Settings.Language", 
				"Invalid Language value")
		end
	end
	
	-- Validate volume settings
	if settings.MusicVolume then
		if not IsValidNumber(settings.MusicVolume, 0, 1) then
			AddIssue(issues, DataValidator.Severity.WARNING, "Settings.MusicVolume", 
				string.format("Invalid MusicVolume: %s (must be 0-1)", tostring(settings.MusicVolume)))
		end
	end
	
	if settings.SFXVolume then
		if not IsValidNumber(settings.SFXVolume, 0, 1) then
			AddIssue(issues, DataValidator.Severity.WARNING, "Settings.SFXVolume", 
				string.format("Invalid SFXVolume: %s (must be 0-1)", tostring(settings.SFXVolume)))
		end
	end
	
	-- Validate boolean settings
	if settings.NotificationsEnabled ~= nil then
		if not IsValidBoolean(settings.NotificationsEnabled) then
			AddIssue(issues, DataValidator.Severity.WARNING, "Settings.NotificationsEnabled", 
				"Invalid NotificationsEnabled value (must be boolean)")
		end
	end
	
	return issues
end

--[[
	Validate pending trades
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidatePendingTrades(profile: table): {table}
	local issues = {}
	
	if not profile.PendingTrades then
		AddIssue(issues, DataValidator.Severity.WARNING, "PendingTrades", "PendingTrades table is missing")
		return issues
	end
	
	if not IsValidTable(profile.PendingTrades) then
		AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades", "PendingTrades is not a table")
		return issues
	end
	
	local tradeCount = 0
	for tradeId, trade in pairs(profile.PendingTrades) do
		tradeCount = tradeCount + 1
		
		-- Validate trade structure
		if not IsValidTable(trade) then
			AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades." .. tostring(tradeId), 
				"Trade is not a table")
		else
			-- Check required fields
			if not trade.FromPlayerId or not IsValidNumber(trade.FromPlayerId, 1) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades." .. tostring(tradeId), 
					"Invalid FromPlayerId")
			end
			
			if not trade.ToPlayerId or not IsValidNumber(trade.ToPlayerId, 1) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades." .. tostring(tradeId), 
					"Invalid ToPlayerId")
			end
			
			if not IsValidTable(trade.OfferedMemories) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades." .. tostring(tradeId), 
					"Invalid OfferedMemories")
			end
			
			if not IsValidTable(trade.RequestedMemories) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingTrades." .. tostring(tradeId), 
					"Invalid RequestedMemories")
			end
		end
	end
	
	-- Check trade limit
	if tradeCount > GameConfig.Trade.MaxPendingTrades then
		AddIssue(issues, DataValidator.Severity.WARNING, "PendingTrades", 
			string.format("Too many pending trades: %d (max %d)", 
				tradeCount, GameConfig.Trade.MaxPendingTrades))
	end
	
	return issues
end

--[[
	Validate pending gifts
	
	@param profile: table - Profile data to validate
	@return table - Array of issues found
]]
function DataValidator.ValidatePendingGifts(profile: table): {table}
	local issues = {}
	
	if not profile.PendingGifts then
		AddIssue(issues, DataValidator.Severity.WARNING, "PendingGifts", "PendingGifts table is missing")
		return issues
	end
	
	if not IsValidTable(profile.PendingGifts) then
		AddIssue(issues, DataValidator.Severity.ERROR, "PendingGifts", "PendingGifts is not a table")
		return issues
	end
	
	local giftCount = 0
	for giftId, gift in pairs(profile.PendingGifts) do
		giftCount = giftCount + 1
		
		if not IsValidTable(gift) then
			AddIssue(issues, DataValidator.Severity.ERROR, "PendingGifts." .. tostring(giftId), 
				"Gift is not a table")
		else
			if not gift.FromPlayerId or not IsValidNumber(gift.FromPlayerId, 1) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingGifts." .. tostring(giftId), 
					"Invalid FromPlayerId")
			end
			
			if not gift.MemoryId or not IsValidString(gift.MemoryId, 100) then
				AddIssue(issues, DataValidator.Severity.ERROR, "PendingGifts." .. tostring(giftId), 
					"Invalid MemoryId")
			end
		end
	end
	
	-- Check gift limit
	if giftCount > GameConfig.Gift.MaxPendingGifts then
		AddIssue(issues, DataValidator.Severity.WARNING, "PendingGifts", 
			string.format("Too many pending gifts: %d (max %d)", 
				giftCount, GameConfig.Gift.MaxPendingGifts))
	end
	
	return issues
end

--[[
	Validate entire profile
	Runs all validation checks
	
	@param profile: table - Profile data to validate
	@return table - Array of all issues found
]]
function DataValidator.ValidateProfile(profile: table): {table}
	local allIssues = {}
	
	if not profile then
		AddIssue(allIssues, DataValidator.Severity.CRITICAL, "Profile", "Profile is nil")
		return allIssues
	end
	
	if not IsValidTable(profile) then
		AddIssue(allIssues, DataValidator.Severity.CRITICAL, "Profile", "Profile is not a table")
		return allIssues
	end
	
	-- Run all validators
	local validators = {
		DataValidator.ValidateMemoryData,
		DataValidator.ValidateCurrency,
		DataValidator.ValidateStatistics,
		DataValidator.ValidateSettings,
		DataValidator.ValidatePendingTrades,
		DataValidator.ValidatePendingGifts,
	}
	
	for _, validator in ipairs(validators) do
		local issues = validator(profile)
		for _, issue in ipairs(issues) do
			table.insert(allIssues, issue)
		end
	end
	
	return allIssues
end

--------------------------------------------------------------------------------
-- AUTO-FIX FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Attempt to auto-fix issues in profile data
	Only fixes issues that can be safely corrected
	
	@param profile: table - Profile data to fix
	@param userId: number? - User ID for logging
	@return number - Number of fixes applied
]]
function DataValidator.AutoFix(profile: table, userId: number?): number
	if not profile then
		return 0
	end
	
	local fixCount = 0
	
	-- Fix missing Inventory
	if not profile.Inventory then
		profile.Inventory = GameConfig.DeepCopy(GameConfig.DefaultProfile.Inventory)
		fixCount = fixCount + 1
		Log("INFO", "Fixed missing Inventory table", userId)
	end
	
	-- Fix missing Memories table
	if profile.Inventory and not profile.Inventory.Memories then
		profile.Inventory.Memories = {}
		fixCount = fixCount + 1
		Log("INFO", "Fixed missing Memories table", userId)
	end
	
	-- Fix TotalMemories mismatch
	if profile.Inventory and profile.Inventory.Memories then
		local totalCount = 0
		for _, count in pairs(profile.Inventory.Memories) do
			if type(count) == "number" and count > 0 then
				totalCount = totalCount + count
			end
		end
		
		if profile.Inventory.TotalMemories ~= totalCount then
			profile.Inventory.TotalMemories = totalCount
			fixCount = fixCount + 1
			Log("INFO", "Fixed TotalMemories mismatch", userId)
		end
	end
	
	-- Fix missing Currency
	if not profile.Currency then
		profile.Currency = GameConfig.DeepCopy(GameConfig.DefaultProfile.Currency)
		fixCount = fixCount + 1
		Log("INFO", "Fixed missing Currency table", userId)
	end
	
	-- Fix negative or missing currency values
	if profile.Currency then
		if not profile.Currency.Coins or profile.Currency.Coins < 0 then
			profile.Currency.Coins = math.max(0, profile.Currency.Coins or 0)
			fixCount = fixCount + 1
			Log("INFO", "Fixed invalid Coins value", userId)
		end
		
		if not profile.Currency.Gems or profile.Currency.Gems < 0 then
			profile.Currency.Gems = math.max(0, profile.Currency.Gems or 0)
			fixCount = fixCount + 1
			Log("INFO", "Fixed invalid Gems value", userId)
		end
		
		-- Cap currency at max
		local coinMax = GameConfig.Currency.Coins.Max
		local gemMax = GameConfig.Currency.Gems.Max
		
		if profile.Currency.Coins > coinMax then
			profile.Currency.Coins = coinMax
			fixCount = fixCount + 1
			Log("WARN", "Capped Coins at maximum", userId)
		end
		
		if profile.Currency.Gems > gemMax then
			profile.Currency.Gems = gemMax
			fixCount = fixCount + 1
			Log("WARN", "Capped Gems at maximum", userId)
		end
	end
	
	-- Fix missing Statistics
	if not profile.Statistics then
		profile.Statistics = GameConfig.DeepCopy(GameConfig.DefaultProfile.Statistics)
		fixCount = fixCount + 1
		Log("INFO", "Fixed missing Statistics table", userId)
	else
		-- Fix missing stat fields
		local defaults = GameConfig.DefaultProfile.Statistics
		for key, defaultValue in pairs(defaults) do
			if profile.Statistics[key] == nil then
				profile.Statistics[key] = defaultValue
				fixCount = fixCount + 1
			end
		end
	end
	
	-- Fix missing Settings
	if not profile.Settings then
		profile.Settings = GameConfig.DeepCopy(GameConfig.DefaultProfile.Settings)
		fixCount = fixCount + 1
		Log("INFO", "Fixed missing Settings table", userId)
	else
		-- Fix volume out of bounds
		if profile.Settings.MusicVolume then
			profile.Settings.MusicVolume = math.clamp(profile.Settings.MusicVolume, 0, 1)
		end
		if profile.Settings.SFXVolume then
			profile.Settings.SFXVolume = math.clamp(profile.Settings.SFXVolume, 0, 1)
		end
	end
	
	-- Fix missing PendingTrades and PendingGifts
	if not profile.PendingTrades then
		profile.PendingTrades = {}
		fixCount = fixCount + 1
	end
	
	if not profile.PendingGifts then
		profile.PendingGifts = {}
		fixCount = fixCount + 1
	end
	
	-- Fix missing Purchases
	if not profile.Purchases then
		profile.Purchases = GameConfig.DeepCopy(GameConfig.DefaultProfile.Purchases)
		fixCount = fixCount + 1
	end
	
	-- Fix missing DailyRewards
	if not profile.DailyRewards then
		profile.DailyRewards = GameConfig.DeepCopy(GameConfig.DefaultProfile.DailyRewards)
		fixCount = fixCount + 1
	end
	
	-- Fix missing Flags
	if not profile.Flags then
		profile.Flags = GameConfig.DeepCopy(GameConfig.DefaultProfile.Flags)
		fixCount = fixCount + 1
	end
	
	if fixCount > 0 then
		Log("INFO", string.format("Applied %d auto-fixes to profile", fixCount), userId)
	end
	
	return fixCount
end

--[[
	Clean up expired trades from profile
	
	@param profile: table - Profile data
	@return number - Number of trades cleaned
]]
function DataValidator.CleanExpiredTrades(profile: table): number
	if not profile.PendingTrades then
		return 0
	end
	
	local now = os.time()
	local cleaned = 0
	local toRemove = {}
	
	for tradeId, trade in pairs(profile.PendingTrades) do
		if trade.Expiry and trade.Expiry < now then
			table.insert(toRemove, tradeId)
		end
	end
	
	for _, tradeId in ipairs(toRemove) do
		profile.PendingTrades[tradeId] = nil
		cleaned = cleaned + 1
	end
	
	return cleaned
end

--[[
	Clean up expired gifts from profile
	
	@param profile: table - Profile data
	@return number - Number of gifts cleaned
]]
function DataValidator.CleanExpiredGifts(profile: table): number
	if not profile.PendingGifts then
		return 0
	end
	
	local now = os.time()
	local cleaned = 0
	local toRemove = {}
	
	for giftId, gift in pairs(profile.PendingGifts) do
		if gift.Expiry and gift.Expiry < now then
			table.insert(toRemove, giftId)
		end
	end
	
	for _, giftId in ipairs(toRemove) do
		profile.PendingGifts[giftId] = nil
		cleaned = cleaned + 1
	end
	
	return cleaned
end

--------------------------------------------------------------------------------
-- LOGGING FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Log issues for a player
	
	@param userId: number - User ID
	@param issues: table - Array of issues
]]
function DataValidator.LogIssues(userId: number, issues: {table})
	if not IssueLog[userId] then
		IssueLog[userId] = {}
	end
	
	local log = IssueLog[userId]
	
	for _, issue in ipairs(issues) do
		table.insert(log, {
			Timestamp = os.time(),
			Severity = issue.Severity,
			Field = issue.Field,
			Message = issue.Message,
		})
		
		-- Log serious issues
		if issue.Severity >= DataValidator.Severity.ERROR then
			Log("ERROR", string.format("[%s] %s", issue.Field, issue.Message), userId)
		end
	end
	
	-- Trim log if too large
	while #log > MAX_LOG_ENTRIES do
		table.remove(log, 1)
	end
end

--[[
	Get recent issues for a player
	
	@param userId: number - User ID
	@return table - Array of recent issues
]]
function DataValidator.GetIssues(userId: number): {table}
	return IssueLog[userId] or {}
end

--[[
	Clear issue log for a player
	
	@param userId: number - User ID
]]
function DataValidator.ClearIssues(userId: number)
	IssueLog[userId] = nil
end

--[[
	Get summary of issues by severity
	
	@param issues: table - Array of issues
	@return table - Counts by severity
]]
function DataValidator.GetIssueSummary(issues: {table}): table
	local summary = {
		Info = 0,
		Warning = 0,
		Error = 0,
		Critical = 0,
		Total = #issues,
	}
	
	for _, issue in ipairs(issues) do
		if issue.Severity == DataValidator.Severity.INFO then
			summary.Info = summary.Info + 1
		elseif issue.Severity == DataValidator.Severity.WARNING then
			summary.Warning = summary.Warning + 1
		elseif issue.Severity == DataValidator.Severity.ERROR then
			summary.Error = summary.Error + 1
		elseif issue.Severity == DataValidator.Severity.CRITICAL then
			summary.Critical = summary.Critical + 1
		end
	end
	
	return summary
end

--[[
	Check if profile has critical issues
	
	@param profile: table - Profile data
	@return boolean - True if critical issues exist
]]
function DataValidator.HasCriticalIssues(profile: table): boolean
	local issues = DataValidator.ValidateProfile(profile)
	
	for _, issue in ipairs(issues) do
		if issue.Severity == DataValidator.Severity.CRITICAL then
			return true
		end
	end
	
	return false
end

return DataValidator
