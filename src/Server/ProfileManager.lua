--[[
	ProfileManager.lua
	Core profile management system for Memory Rush
	
	Handles:
	- Profile loading with timeout and retry logic
	- Profile saving (manual and auto-save)
	- Profile release on player disconnect
	- Data corruption detection and recovery
	- Graceful server shutdown handling
	
	Usage:
		local ProfileManager = require(ServerScriptService.Server.ProfileManager)
		
		-- Load a player's profile
		local profile = ProfileManager.LoadProfile(player)
		
		-- Get profile data
		local data = ProfileManager.GetData(player.UserId)
		
		-- Update data safely
		ProfileManager.UpdateData(player.UserId, "Currency.Coins", 500)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import modules
local ProfileService = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ProfileService"))
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local ProfileManager = {}

-- Private state
local ProfileStore = nil -- ProfileService store
local Profiles = {} -- [userId: number] = profile
local LoadingPlayers = {} -- [userId: number] = true (players currently loading)
local SaveDebounce = {} -- [userId: number] = lastSaveTime

-- Events for internal use
local ProfileLoadedEvent = Instance.new("BindableEvent")
ProfileManager.ProfileLoaded = ProfileLoadedEvent.Event

local ProfileReleasedEvent = Instance.new("BindableEvent")
ProfileManager.ProfileReleased = ProfileReleasedEvent.Event

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

-- Log messages with timestamp
local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ERROR" then
		warn(string.format("[ProfileManager] %s%s ERROR: %s", timestamp, userStr, message))
	elseif level == "WARN" then
		warn(string.format("[ProfileManager] %s%s WARN: %s", timestamp, userStr, message))
	else
		print(string.format("[ProfileManager] %s%s INFO: %s", timestamp, userStr, message))
	end
end

-- Deep copy a table
local function DeepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	
	local copy = {}
	for key, value in pairs(original) do
		copy[DeepCopy(key)] = DeepCopy(value)
	end
	
	return copy
end

-- Reconcile profile data with template (fill in missing keys)
local function ReconcileProfile(profileData: table)
	local template = GameConfig.DefaultProfile
	
	local function reconcileTable(target, source)
		for key, value in pairs(source) do
			if type(key) == "string" then
				if target[key] == nil then
					if type(value) == "table" then
						target[key] = DeepCopy(value)
					else
						target[key] = value
					end
				elseif type(target[key]) == "table" and type(value) == "table" then
					reconcileTable(target[key], value)
				end
			end
		end
	end
	
	reconcileTable(profileData, template)
end

-- Get a nested value from a table using dot notation path
local function GetNestedValue(tbl: table, path: string): any
	local current = tbl
	
	for key in string.gmatch(path, "[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end
		
		-- Try to convert to number for array access
		local numKey = tonumber(key)
		current = current[numKey or key]
	end
	
	return current
end

-- Set a nested value in a table using dot notation path
local function SetNestedValue(tbl: table, path: string, value: any): boolean
	local keys = {}
	for key in string.gmatch(path, "[^%.]+") do
		table.insert(keys, key)
	end
	
	if #keys == 0 then
		return false
	end
	
	local current = tbl
	
	-- Navigate to the parent table
	for i = 1, #keys - 1 do
		local key = keys[i]
		local numKey = tonumber(key)
		local actualKey = numKey or key
		
		if type(current[actualKey]) ~= "table" then
			current[actualKey] = {}
		end
		
		current = current[actualKey]
	end
	
	-- Set the final value
	local finalKey = keys[#keys]
	local numFinalKey = tonumber(finalKey)
	current[numFinalKey or finalKey] = value
	
	return true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	Initialize the ProfileManager
	Must be called once at server startup
]]
function ProfileManager.Initialize()
	if ProfileStore then
		Log("WARN", "ProfileManager already initialized")
		return
	end
	
	Log("INFO", "Initializing ProfileManager...")
	
	-- Create the ProfileStore
	ProfileStore = ProfileService.GetProfileStore(
		GameConfig.DataStoreKey,
		GameConfig.DefaultProfile
	)
	
	-- Handle ProfileService errors
	ProfileService.IssueSignal:Connect(function(errorMessage, profileStoreName, profileKey)
		Log("ERROR", string.format("ProfileService error in '%s' for key '%s': %s",
			profileStoreName, profileKey, errorMessage))
	end)
	
	-- Handle profile corruption
	ProfileService.CorruptionSignal:Connect(function(profileStoreName, profileKey)
		Log("ERROR", string.format("Profile corruption detected in '%s' for key '%s'",
			profileStoreName, profileKey))
	end)
	
	-- Handle critical state (DataStore having too many errors)
	ProfileService.CriticalStateSignal:Connect(function(isCritical)
		if isCritical then
			Log("ERROR", "ProfileService entered CRITICAL STATE - DataStore is having issues!")
		else
			Log("INFO", "ProfileService exited critical state - DataStore is stable again")
		end
	end)
	
	-- Bind to server close for graceful shutdown
	game:BindToClose(function()
		ProfileManager.OnServerShutdown()
	end)
	
	Log("INFO", "ProfileManager initialized successfully")
end

--[[
	Load a player's profile
	
	@param player: Player - The player to load the profile for
	@return table|nil - The profile data if successful, nil otherwise
]]
function ProfileManager.LoadProfile(player: Player): table?
	local userId = player.UserId
	
	-- Check if already loaded
	if Profiles[userId] then
		Log("WARN", "Profile already loaded", userId)
		return Profiles[userId].Data
	end
	
	-- Check if currently loading
	if LoadingPlayers[userId] then
		Log("WARN", "Profile is currently loading", userId)
		return nil
	end
	
	LoadingPlayers[userId] = true
	Log("INFO", "Loading profile...", userId)
	
	-- Create the profile key
	local profileKey = "Player_" .. tostring(userId)
	
	-- Attempt to load with timeout
	local startTime = os.clock()
	local timeout = GameConfig.ProfileService.LoadTimeout
	local maxRetries = GameConfig.ProfileService.MaxRetries
	local retryDelay = GameConfig.ProfileService.RetryDelay
	
	local profile = nil
	local retries = 0
	
	while retries < maxRetries do
		-- Check if player left during loading
		if not player:IsDescendantOf(Players) then
			Log("WARN", "Player left during profile loading", userId)
			LoadingPlayers[userId] = nil
			return nil
		end
		
		-- Check timeout
		if os.clock() - startTime > timeout then
			Log("ERROR", "Profile loading timed out after " .. timeout .. " seconds", userId)
			break
		end
		
		-- Attempt to load the profile
		profile = ProfileStore:LoadProfileAsync(profileKey, "ForceLoad")
		
		if profile then
			break
		end
		
		retries = retries + 1
		Log("WARN", string.format("Profile load failed, retry %d/%d", retries, maxRetries), userId)
		task.wait(retryDelay)
	end
	
	LoadingPlayers[userId] = nil
	
	-- Check if profile was loaded
	if not profile then
		Log("ERROR", "Failed to load profile after " .. maxRetries .. " retries", userId)
		-- Create a fallback in-memory profile
		return ProfileManager.CreateFallbackProfile(player)
	end
	
	-- Check if player is still in game
	if not player:IsDescendantOf(Players) then
		Log("WARN", "Player left during profile loading (after load)", userId)
		profile:Release()
		return nil
	end
	
	-- Profile loaded successfully
	Log("INFO", "Profile loaded successfully", userId)
	
	-- Reconcile with template (add any missing keys)
	ReconcileProfile(profile.Data)
	
	-- Update metadata
	profile.Data.UserId = userId
	profile.Data.LastSave = os.time()
	profile.Data.Statistics.SessionCount = (profile.Data.Statistics.SessionCount or 0) + 1
	
	-- Add user ID for GDPR compliance
	profile:AddUserId(userId)
	
	-- Listen for profile release (external or internal)
	profile:ListenToRelease(function()
		Profiles[userId] = nil
		Log("INFO", "Profile released", userId)
		ProfileReleasedEvent:Fire(userId)
		
		-- Kick player if profile was released while they're still in game
		if player:IsDescendantOf(Players) then
			player:Kick("Your data was loaded on another server. Please rejoin.")
		end
	end)
	
	-- Store the profile
	Profiles[userId] = profile
	
	-- Fire loaded event
	ProfileLoadedEvent:Fire(userId, profile.Data)
	
	return profile.Data
end

--[[
	Create a fallback in-memory profile when loading fails
	WARNING: This profile will NOT be saved to DataStore
	
	@param player: Player - The player to create fallback for
	@return table - The fallback profile data
]]
function ProfileManager.CreateFallbackProfile(player: Player): table
	local userId = player.UserId
	
	Log("WARN", "Creating fallback in-memory profile (DATA WILL NOT SAVE)", userId)
	
	-- Create profile from template
	local fallbackData = GameConfig.CreateNewProfile(userId)
	
	-- Create a mock profile object
	local mockProfile = {
		Data = fallbackData,
		_isFallback = true,
		
		IsActive = function() return true end,
		Release = function() end,
		Save = function() end,
		AddUserId = function() end,
		ListenToRelease = function() return {Disconnect = function() end} end,
	}
	
	Profiles[userId] = mockProfile
	ProfileLoadedEvent:Fire(userId, fallbackData)
	
	return fallbackData
end

--[[
	Save a player's profile manually
	Includes debouncing to prevent rapid saves
	
	@param userId: number - The user ID to save
	@return boolean - True if save was initiated
]]
function ProfileManager.SaveProfile(userId: number): boolean
	local profile = Profiles[userId]
	
	if not profile then
		Log("WARN", "Cannot save - profile not found", userId)
		return false
	end
	
	-- Skip if fallback profile
	if profile._isFallback then
		Log("WARN", "Cannot save fallback profile", userId)
		return false
	end
	
	-- Debounce check (minimum 5 seconds between saves)
	local now = os.clock()
	local lastSave = SaveDebounce[userId] or 0
	
	if now - lastSave < 5 then
		Log("INFO", "Save debounced (too frequent)", userId)
		return false
	end
	
	SaveDebounce[userId] = now
	
	-- Update last save timestamp
	if profile.Data then
		profile.Data.LastSave = os.time()
	end
	
	-- Save the profile
	profile:Save()
	Log("INFO", "Profile save initiated", userId)
	
	return true
end

--[[
	Get a player's profile (safe getter)
	
	@param userId: number - The user ID
	@return table|nil - The profile object or nil
]]
function ProfileManager.GetProfile(userId: number): table?
	return Profiles[userId]
end

--[[
	Get a player's profile data
	
	@param userId: number - The user ID
	@return table|nil - The profile data or nil
]]
function ProfileManager.GetData(userId: number): table?
	local profile = Profiles[userId]
	
	if profile then
		return profile.Data
	end
	
	return nil
end

--[[
	Update a specific value in profile data
	Uses dot notation path for nested access
	
	@param userId: number - The user ID
	@param path: string - Dot notation path (e.g., "Currency.Coins")
	@param value: any - The new value
	@return boolean - True if update was successful
]]
function ProfileManager.UpdateData(userId: number, path: string, value: any): boolean
	local profile = Profiles[userId]
	
	if not profile or not profile.Data then
		Log("WARN", "Cannot update - profile not found", userId)
		return false
	end
	
	local success = SetNestedValue(profile.Data, path, value)
	
	if success then
		profile.Data.LastSave = os.time()
	else
		Log("WARN", string.format("Failed to update path '%s'", path), userId)
	end
	
	return success
end

--[[
	Get a specific value from profile data
	Uses dot notation path for nested access
	
	@param userId: number - The user ID
	@param path: string - Dot notation path (e.g., "Currency.Coins")
	@return any - The value at the path or nil
]]
function ProfileManager.GetValue(userId: number, path: string): any
	local data = ProfileManager.GetData(userId)
	
	if not data then
		return nil
	end
	
	return GetNestedValue(data, path)
end

--[[
	Release a player's profile (call when player leaves)
	
	@param player: Player - The player leaving
]]
function ProfileManager.ReleaseProfile(player: Player)
	local userId = player.UserId
	local profile = Profiles[userId]
	
	if not profile then
		-- Check if still loading
		if LoadingPlayers[userId] then
			LoadingPlayers[userId] = nil
			Log("INFO", "Cancelled profile loading for leaving player", userId)
		end
		return
	end
	
	-- Skip release for fallback profiles (just remove from table)
	if profile._isFallback then
		Profiles[userId] = nil
		Log("INFO", "Removed fallback profile", userId)
		return
	end
	
	-- Update final statistics before release
	if profile.Data then
		profile.Data.LastSave = os.time()
	end
	
	-- Release the profile
	profile:Release()
	Log("INFO", "Profile released for leaving player", userId)
	
	-- Clean up
	SaveDebounce[userId] = nil
end

--[[
	Check if a player's profile is loaded
	
	@param userId: number - The user ID
	@return boolean - True if profile is loaded and active
]]
function ProfileManager.IsProfileLoaded(userId: number): boolean
	local profile = Profiles[userId]
	return profile ~= nil and (profile._isFallback or profile:IsActive())
end

--[[
	Check if a player's profile is currently loading
	
	@param userId: number - The user ID
	@return boolean - True if profile is loading
]]
function ProfileManager.IsProfileLoading(userId: number): boolean
	return LoadingPlayers[userId] == true
end

--[[
	Get all loaded profiles (for debugging/admin)
	
	@return table - Dictionary of userId -> profile data
]]
function ProfileManager.GetAllProfiles(): {[number]: table}
	local result = {}
	
	for userId, profile in pairs(Profiles) do
		if profile.Data then
			result[userId] = profile.Data
		end
	end
	
	return result
end

--[[
	Graceful server shutdown handler
	Releases all profiles to ensure data is saved
]]
function ProfileManager.OnServerShutdown()
	Log("INFO", "Server shutting down - releasing all profiles...")
	
	-- Wait for any loading profiles to finish or timeout
	local shutdownStart = os.clock()
	while next(LoadingPlayers) and os.clock() - shutdownStart < 5 do
		task.wait(0.1)
	end
	
	-- Release all profiles
	for userId, profile in pairs(Profiles) do
		if not profile._isFallback then
			Log("INFO", "Releasing profile during shutdown", userId)
			profile:Release()
		end
	end
	
	-- Wait a moment for saves to complete
	task.wait(1)
	
	Log("INFO", "All profiles released - shutdown complete")
end

--[[
	Force save all profiles (for admin/emergency use)
]]
function ProfileManager.ForceSaveAll()
	Log("INFO", "Force saving all profiles...")
	
	for userId, profile in pairs(Profiles) do
		if not profile._isFallback then
			if profile.Data then
				profile.Data.LastSave = os.time()
			end
			profile:Save()
		end
	end
	
	Log("INFO", "Force save initiated for all profiles")
end

--[[
	Admin function to reset a player's profile (DANGEROUS)
	
	@param userId: number - The user ID to reset
	@return boolean - True if reset was successful
]]
function ProfileManager.ResetProfile(userId: number): boolean
	local profile = Profiles[userId]
	
	if not profile or profile._isFallback then
		Log("ERROR", "Cannot reset - profile not found or is fallback", userId)
		return false
	end
	
	-- Create fresh data from template
	local freshData = GameConfig.CreateNewProfile(userId)
	
	-- Replace profile data
	for key in pairs(profile.Data) do
		profile.Data[key] = nil
	end
	
	for key, value in pairs(freshData) do
		profile.Data[key] = value
	end
	
	-- Mark as reset for logging
	profile.Data.Statistics.FirstJoinTime = os.time()
	
	-- Save immediately
	profile:Save()
	
	Log("WARN", "Profile has been RESET by admin", userId)
	
	return true
end

--------------------------------------------------------------------------------
-- PLAYER CONNECTION HANDLERS
--------------------------------------------------------------------------------

-- These are called by DataService.lua, but we set up PlayerRemoving here for safety
Players.PlayerRemoving:Connect(function(player)
	ProfileManager.ReleaseProfile(player)
end)

--------------------------------------------------------------------------------

return ProfileManager
