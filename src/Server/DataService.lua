--[[
	DataService.lua
	Main entry point for Memory Rush backend system
	
	This script initializes all data management modules in the correct order
	and sets up player connection handlers.
	
	Place this in ServerScriptService to run automatically on server start.
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------------------
-- MODULE LOADING
--------------------------------------------------------------------------------

-- Wait for shared modules to be available
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
	error("[DataService] Failed to find Shared folder in ReplicatedStorage")
end

-- Load shared modules first
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

print("[DataService] Shared modules loaded")

-- Load server modules
local ServerModules = script.Parent
local ProfileManager = require(ServerModules:WaitForChild("ProfileManager"))
local DataValidator = require(ServerModules:WaitForChild("DataValidator"))
local AntiCheat = require(ServerModules:WaitForChild("AntiCheat"))
local CurrencyManager = require(ServerModules:WaitForChild("CurrencyManager"))
local InventoryManager = require(ServerModules:WaitForChild("InventoryManager"))
local StatisticsManager = require(ServerModules:WaitForChild("StatisticsManager"))
local TradeManager = require(ServerModules:WaitForChild("TradeManager"))
local GiftManager = require(ServerModules:WaitForChild("GiftManager"))

print("[DataService] Server modules loaded")

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

local DataService = {}

local isInitialized = false

function DataService.Initialize()
	if isInitialized then
		warn("[DataService] Already initialized")
		return
	end
	
	print("[DataService] Initializing Memory Rush backend...")
	
	-- Initialize ProfileManager (must be first)
	ProfileManager.Initialize()
	
	-- Set up remote event handlers
	DataService.SetupRemoteHandlers()
	
	-- Set up player connection handlers
	DataService.SetupPlayerHandlers()
	
	-- Set up admin commands (for testing)
	DataService.SetupAdminCommands()
	
	isInitialized = true
	print("[DataService] Memory Rush backend initialized successfully!")
end

--------------------------------------------------------------------------------
-- REMOTE EVENT HANDLERS
--------------------------------------------------------------------------------

function DataService.SetupRemoteHandlers()
	-- Handle data requests from clients
	RemoteEvents.SetCallback("RequestPlayerData", function(player: Player)
		local userId = player.UserId
		
		-- Check rate limit
		if not AntiCheat.CheckRateLimit(userId, "DataRequest") then
			return { Error = "Rate limited" }
		end
		
		local profileData = ProfileManager.GetData(userId)
		
		if not profileData then
			return { Error = "Profile not loaded" }
		end
		
		-- Return safe data subset (don't expose internal flags)
		return {
			Currency = profileData.Currency,
			Inventory = profileData.Inventory,
			Statistics = profileData.Statistics,
			Settings = profileData.Settings,
			DailyRewards = StatisticsManager.GetDailyRewardInfo(userId),
		}
	end)
	
	-- Handle trade data requests
	RemoteEvents.SetCallback("RequestTradeData", function(player: Player)
		local userId = player.UserId
		
		if not AntiCheat.CheckRateLimit(userId, "DataRequest") then
			return { Error = "Rate limited" }
		end
		
		return {
			PendingTrades = TradeManager.GetPendingTrades(userId),
		}
	end)
	
	-- Handle gift data requests
	RemoteEvents.SetCallback("RequestGiftData", function(player: Player)
		local userId = player.UserId
		
		if not AntiCheat.CheckRateLimit(userId, "DataRequest") then
			return { Error = "Rate limited" }
		end
		
		return {
			PendingGifts = GiftManager.GetPendingGifts(userId),
			RemainingDailyGifts = GiftManager.GetRemainingDailyGifts(userId),
		}
	end)
	
	-- Handle leaderboard requests
	RemoteEvents.SetCallback("RequestLeaderboardData", function(player: Player, statName: string)
		local userId = player.UserId
		
		if not AntiCheat.CheckRateLimit(userId, "DataRequest") then
			return { Error = "Rate limited" }
		end
		
		if type(statName) ~= "string" then
			return { Error = "Invalid stat name" }
		end
		
		return {
			Leaderboard = StatisticsManager.GetLeaderboard(statName, 20),
			PlayerRank = StatisticsManager.GetPlayerRank(userId, statName),
		}
	end)
	
	print("[DataService] Remote handlers set up")
end

--------------------------------------------------------------------------------
-- PLAYER CONNECTION HANDLERS
--------------------------------------------------------------------------------

function DataService.SetupPlayerHandlers()
	-- Handle player joining
	local function onPlayerAdded(player: Player)
		local userId = player.UserId
		
		print(string.format("[DataService] Player %s (%d) joining...", player.Name, userId))
		
		-- Check if banned
		local isBanned, banReason = AntiCheat.IsBanned(userId)
		
		if isBanned then
			player:Kick("You are banned: " .. (banReason or "Unknown reason"))
			return
		end
		
		-- Load profile
		local profileData = ProfileManager.LoadProfile(player)
		
		if profileData then
			-- Validate and auto-fix profile data
			local issues = DataValidator.ValidateProfile(profileData)
			
			if #issues > 0 then
				DataValidator.LogIssues(userId, issues)
				
				-- Check for critical issues
				local summary = DataValidator.GetIssueSummary(issues)
				
				if summary.Critical > 0 then
					warn(string.format("[DataService] Player %d has %d CRITICAL data issues!", 
						userId, summary.Critical))
				end
				
				-- Auto-fix what we can
				local fixCount = DataValidator.AutoFix(profileData, userId)
				
				if fixCount > 0 then
					print(string.format("[DataService] Applied %d fixes to player %d's profile", 
						fixCount, userId))
				end
			end
			
			-- Clean expired trades and gifts
			DataValidator.CleanExpiredTrades(profileData)
			DataValidator.CleanExpiredGifts(profileData)
			
			-- Start session tracking
			StatisticsManager.StartSession(userId)
			
			-- Notify client that profile is ready
			RemoteEvents.FireClient("ProfileLoaded", player, {
				Currency = profileData.Currency,
				Inventory = profileData.Inventory,
				Statistics = profileData.Statistics,
				Settings = profileData.Settings,
				DailyRewards = StatisticsManager.GetDailyRewardInfo(userId),
				PendingGiftCount = GiftManager.GetPendingGiftCount(userId),
				PendingTradeCount = #TradeManager.GetPendingTrades(userId),
			})
			
			print(string.format("[DataService] Player %s (%d) loaded successfully", player.Name, userId))
		else
			warn(string.format("[DataService] Failed to load profile for player %s (%d)", 
				player.Name, userId))
		end
	end
	
	-- Handle player leaving
	local function onPlayerRemoving(player: Player)
		local userId = player.UserId
		
		print(string.format("[DataService] Player %s (%d) leaving...", player.Name, userId))
		
		-- End session tracking (updates play time)
		StatisticsManager.EndSession(userId)
		
		-- ProfileManager.ReleaseProfile is called automatically via its PlayerRemoving connection
		
		print(string.format("[DataService] Player %s (%d) cleanup complete", player.Name, userId))
	end
	
	-- Connect handlers
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	-- Handle players already in game (for late module load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	
	print("[DataService] Player handlers set up")
end

--------------------------------------------------------------------------------
-- ADMIN COMMANDS (for testing)
--------------------------------------------------------------------------------

function DataService.SetupAdminCommands()
	-- Admin command system via chat
	Players.PlayerAdded:Connect(function(player: Player)
		player.Chatted:Connect(function(message: string)
			-- Only process commands from admins
			local adminLevel = GameConfig.Admins[player.UserId]
			
			if not adminLevel or adminLevel < 1 then
				return
			end
			
			-- Check if message is a command
			if not string.sub(message, 1, 1) == "/" then
				return
			end
			
			local args = {}
			for arg in string.gmatch(message, "[^%s]+") do
				table.insert(args, arg)
			end
			
			local command = args[1]
			
			-- Admin commands (level 1+)
			if command == "/viewdata" and adminLevel >= 1 then
				local targetName = args[2]
				if targetName then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						local data = ProfileManager.GetData(targetPlayer.UserId)
						if data then
							print("[Admin] Player data for", targetName, ":")
							print("Coins:", data.Currency.Coins)
							print("Gems:", data.Currency.Gems)
							print("Total Memories:", data.Inventory.TotalMemories)
						end
					end
				end
				
			-- Admin commands (level 2+)
			elseif command == "/addcoins" and adminLevel >= 2 then
				local targetName = args[2]
				local amount = tonumber(args[3])
				if targetName and amount then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						CurrencyManager.AddCoins(targetPlayer.UserId, amount, "admin_grant")
						print("[Admin] Added", amount, "coins to", targetName)
					end
				end
				
			elseif command == "/addgems" and adminLevel >= 2 then
				local targetName = args[2]
				local amount = tonumber(args[3])
				if targetName and amount then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						CurrencyManager.AddGems(targetPlayer.UserId, amount, "admin_grant")
						print("[Admin] Added", amount, "gems to", targetName)
					end
				end
				
			elseif command == "/addmemory" and adminLevel >= 2 then
				local targetName = args[2]
				local memoryId = args[3]
				local count = tonumber(args[4]) or 1
				if targetName and memoryId then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						local result = InventoryManager.AddMemory(targetPlayer.UserId, memoryId, count, "admin_grant")
						print("[Admin] Add memory result:", result)
					end
				end
				
			elseif command == "/ban" and adminLevel >= 2 then
				local targetName = args[2]
				local reason = table.concat(args, " ", 3) or "Admin ban"
				if targetName then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						AntiCheat.BanPlayer(targetPlayer.UserId, reason, nil, player.UserId)
						print("[Admin] Banned", targetName)
					end
				end
				
			-- Owner commands (level 3)
			elseif command == "/resetdata" and adminLevel >= 3 then
				local targetName = args[2]
				if targetName then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						ProfileManager.ResetProfile(targetPlayer.UserId)
						print("[Admin] Reset data for", targetName)
					end
				end
				
			elseif command == "/forcesave" and adminLevel >= 3 then
				ProfileManager.ForceSaveAll()
				print("[Admin] Force saved all profiles")
				
			elseif command == "/securityreport" and adminLevel >= 2 then
				local targetName = args[2]
				if targetName then
					local targetPlayer = Players:FindFirstChild(targetName)
					if targetPlayer then
						local report = AntiCheat.GenerateSecurityReport(targetPlayer.UserId)
						print("[Admin] Security report for", targetName, ":")
						print("Total flags:", report.Flags.Total)
						print("Anomalies:", #report.Anomalies)
						for _, anomaly in ipairs(report.Anomalies) do
							print("  -", anomaly)
						end
					end
				end
			end
		end)
	end)
	
	print("[DataService] Admin commands set up")
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Expose modules for other scripts
DataService.ProfileManager = ProfileManager
DataService.CurrencyManager = CurrencyManager
DataService.InventoryManager = InventoryManager
DataService.StatisticsManager = StatisticsManager
DataService.TradeManager = TradeManager
DataService.GiftManager = GiftManager
DataService.AntiCheat = AntiCheat
DataService.DataValidator = DataValidator
DataService.GameConfig = GameConfig
DataService.RemoteEvents = RemoteEvents

-- Check if profile is ready
function DataService.IsPlayerReady(player: Player): boolean
	return ProfileManager.IsProfileLoaded(player.UserId)
end

-- Wait for player profile to be ready
function DataService.WaitForPlayer(player: Player, timeout: number?): boolean
	local maxWait = timeout or 30
	local elapsed = 0
	
	while elapsed < maxWait do
		if ProfileManager.IsProfileLoaded(player.UserId) then
			return true
		end
		
		if not player:IsDescendantOf(Players) then
			return false
		end
		
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end
	
	return false
end

--------------------------------------------------------------------------------
-- AUTO-INITIALIZE
--------------------------------------------------------------------------------

DataService.Initialize()

return DataService
