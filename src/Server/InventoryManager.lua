--[[
	InventoryManager.lua
	Memory collection management for Memory Rush
	
	Handles:
	- Adding/removing memories from inventory
	- Memory count and ownership checks
	- Memory transfers between players (trading)
	- Inventory validation
	
	Usage:
		local InventoryManager = require(ServerScriptService.Server.InventoryManager)
		
		-- Add a memory to player
		InventoryManager.AddMemory(userId, "meme_drake", 1)
		
		-- Check if player has a memory
		local count = InventoryManager.GetMemoryCount(userId, "meme_doge")
		
		-- Transfer memories between players
		InventoryManager.TransferMemory(fromUserId, toUserId, "meme_stonks", 1)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProfileManager = require(script.Parent.ProfileManager)
local AntiCheat = require(script.Parent.AntiCheat)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local InventoryManager = {}

-- Result codes
InventoryManager.Result = {
	SUCCESS = "SUCCESS",
	INSUFFICIENT_MEMORIES = "INSUFFICIENT_MEMORIES",
	INVALID_MEMORY = "INVALID_MEMORY",
	INVALID_AMOUNT = "INVALID_AMOUNT",
	PROFILE_NOT_FOUND = "PROFILE_NOT_FOUND",
	RATE_LIMITED = "RATE_LIMITED",
}

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ERROR" then
		warn(string.format("[InventoryManager] %s%s ERROR: %s", timestamp, userStr, message))
	elseif level == "WARN" then
		warn(string.format("[InventoryManager] %s%s WARN: %s", timestamp, userStr, message))
	else
		print(string.format("[InventoryManager] %s%s INFO: %s", timestamp, userStr, message))
	end
end

-- Notify client of inventory change
local function NotifyClient(userId: number, memoryId: string, newCount: number, change: number, reason: string?)
	local player = Players:GetPlayerByUserId(userId)
	
	if player then
		local memoryInfo = GameConfig.GetMemoryInfo(memoryId)
		
		RemoteEvents.FireClient("InventoryChanged", player, {
			MemoryId = memoryId,
			MemoryName = memoryInfo and memoryInfo.Name or memoryId,
			Count = newCount,
			Change = change,
			Reason = reason or "unknown",
			Timestamp = os.time(),
		})
	end
end

-- Recalculate total memories
local function RecalculateTotals(inventory: table)
	local total = 0
	
	for _, count in pairs(inventory.Memories) do
		if type(count) == "number" and count > 0 then
			total = total + count
		end
	end
	
	inventory.TotalMemories = total
end

--------------------------------------------------------------------------------
-- ADD/REMOVE OPERATIONS
--------------------------------------------------------------------------------

--[[
	Add memory to a player's inventory
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID to add
	@param count: number - Number to add (default: 1)
	@param reason: string? - Reason for addition (for logging)
	@return string - Result code
]]
function InventoryManager.AddMemory(userId: number, memoryId: string, count: number?, reason: string?): string
	local amount = count or 1
	
	-- Validate memory ID
	if not GameConfig.IsValidMemory(memoryId) then
		Log("WARN", string.format("Invalid memory ID: %s", memoryId), userId)
		return InventoryManager.Result.INVALID_MEMORY
	end
	
	-- Validate amount
	if type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
		Log("WARN", string.format("Invalid memory amount: %s", tostring(amount)), userId)
		return InventoryManager.Result.INVALID_AMOUNT
	end
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(userId, "InventoryChange") then
		Log("WARN", "Rate limited on inventory addition", userId)
		return InventoryManager.Result.RATE_LIMITED
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		Log("ERROR", "Profile not found for memory addition", userId)
		return InventoryManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Ensure inventory structure exists
	if not profileData.Inventory then
		profileData.Inventory = { Memories = {}, TotalMemories = 0 }
	end
	
	if not profileData.Inventory.Memories then
		profileData.Inventory.Memories = {}
	end
	
	-- Check if this is a new unique memory
	local isNewUnique = (profileData.Inventory.Memories[memoryId] or 0) == 0
	
	-- Add memory
	local currentCount = profileData.Inventory.Memories[memoryId] or 0
	local newCount = currentCount + amount
	profileData.Inventory.Memories[memoryId] = newCount
	
	-- Update totals
	RecalculateTotals(profileData.Inventory)
	
	-- Update unique count if first of this type
	if isNewUnique and profileData.Statistics then
		profileData.Statistics.MemoriesUniqueCollected = (profileData.Statistics.MemoriesUniqueCollected or 0) + 1
	end
	
	-- Log transaction
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.MEMORY_ADD, amount, {
		MemoryId = memoryId,
		Reason = reason or "unknown",
		NewCount = newCount,
		PreviousCount = currentCount,
		IsNewUnique = isNewUnique,
	})
	
	-- Notify client
	NotifyClient(userId, memoryId, newCount, amount, reason)
	
	Log("INFO", string.format("Added %dx %s (reason: %s) - New count: %d", 
		amount, memoryId, reason or "unknown", newCount), userId)
	
	return InventoryManager.Result.SUCCESS
end

--[[
	Remove memory from a player's inventory
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID to remove
	@param count: number - Number to remove (default: 1)
	@param reason: string? - Reason for removal (for logging)
	@return string - Result code
]]
function InventoryManager.RemoveMemory(userId: number, memoryId: string, count: number?, reason: string?): string
	local amount = count or 1
	
	-- Validate memory ID (allow removal of invalid IDs for cleanup purposes)
	if type(memoryId) ~= "string" then
		Log("WARN", "Invalid memory ID type", userId)
		return InventoryManager.Result.INVALID_MEMORY
	end
	
	-- Validate amount
	if type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
		Log("WARN", string.format("Invalid memory amount: %s", tostring(amount)), userId)
		return InventoryManager.Result.INVALID_AMOUNT
	end
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(userId, "InventoryChange") then
		Log("WARN", "Rate limited on inventory removal", userId)
		return InventoryManager.Result.RATE_LIMITED
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Inventory or not profileData.Inventory.Memories then
		Log("ERROR", "Profile/Inventory not found for memory removal", userId)
		return InventoryManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Check current count
	local currentCount = profileData.Inventory.Memories[memoryId] or 0
	
	if currentCount < amount then
		Log("WARN", string.format("Insufficient memories: has %d, needs %d of %s", 
			currentCount, amount, memoryId), userId)
		return InventoryManager.Result.INSUFFICIENT_MEMORIES
	end
	
	-- Remove memory
	local newCount = currentCount - amount
	
	if newCount > 0 then
		profileData.Inventory.Memories[memoryId] = newCount
	else
		profileData.Inventory.Memories[memoryId] = nil -- Remove entry completely
	end
	
	-- Update totals
	RecalculateTotals(profileData.Inventory)
	
	-- Log transaction
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.MEMORY_REMOVE, amount, {
		MemoryId = memoryId,
		Reason = reason or "unknown",
		NewCount = newCount,
		PreviousCount = currentCount,
	})
	
	-- Notify client
	NotifyClient(userId, memoryId, newCount, -amount, reason)
	
	Log("INFO", string.format("Removed %dx %s (reason: %s) - New count: %d", 
		amount, memoryId, reason or "unknown", newCount), userId)
	
	return InventoryManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- QUERY OPERATIONS
--------------------------------------------------------------------------------

--[[
	Get count of a specific memory
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID to check
	@return number - Count of the memory (0 if not found)
]]
function InventoryManager.GetMemoryCount(userId: number, memoryId: string): number
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Inventory or not profileData.Inventory.Memories then
		return 0
	end
	
	return profileData.Inventory.Memories[memoryId] or 0
end

--[[
	Get all memories for a player
	
	@param userId: number - Player user ID
	@return table? - { Memories: { [memoryId] = count }, TotalMemories: number } or nil
]]
function InventoryManager.GetAllMemories(userId: number): table?
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Inventory then
		return nil
	end
	
	-- Return a copy to prevent external modification
	local result = {
		Memories = {},
		TotalMemories = profileData.Inventory.TotalMemories or 0,
	}
	
	if profileData.Inventory.Memories then
		for memoryId, count in pairs(profileData.Inventory.Memories) do
			result.Memories[memoryId] = count
		end
	end
	
	return result
end

--[[
	Check if player has at least a certain amount of a memory
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID to check
	@param count: number - Required count (default: 1)
	@return boolean - True if player has enough
]]
function InventoryManager.HasMemory(userId: number, memoryId: string, count: number?): boolean
	local required = count or 1
	return InventoryManager.GetMemoryCount(userId, memoryId) >= required
end

--[[
	Check if player has all specified memories
	
	@param userId: number - Player user ID
	@param memories: table - { [memoryId] = count, ... }
	@return boolean - True if player has all memories
]]
function InventoryManager.HasAllMemories(userId: number, memories: { [string]: number }): boolean
	for memoryId, count in pairs(memories) do
		if not InventoryManager.HasMemory(userId, memoryId, count) then
			return false
		end
	end
	
	return true
end

--[[
	Get inventory statistics
	
	@param userId: number - Player user ID
	@return table? - Stats or nil
]]
function InventoryManager.GetInventoryStats(userId: number): table?
	local inventory = InventoryManager.GetAllMemories(userId)
	
	if not inventory then
		return nil
	end
	
	local stats = {
		TotalMemories = inventory.TotalMemories,
		UniqueMemories = 0,
		ByRarity = {},
	}
	
	-- Count unique and by rarity
	for memoryId, count in pairs(inventory.Memories) do
		if count > 0 then
			stats.UniqueMemories = stats.UniqueMemories + 1
			
			local info = GameConfig.GetMemoryInfo(memoryId)
			if info then
				local rarity = info.Rarity or 1
				stats.ByRarity[rarity] = (stats.ByRarity[rarity] or 0) + count
			end
		end
	end
	
	return stats
end

--------------------------------------------------------------------------------
-- TRANSFER OPERATIONS
--------------------------------------------------------------------------------

--[[
	Transfer memories from one player to another (atomic operation)
	
	@param fromUserId: number - Source player user ID
	@param toUserId: number - Destination player user ID
	@param memoryId: string - Memory ID to transfer
	@param count: number - Number to transfer (default: 1)
	@return string - Result code
]]
function InventoryManager.TransferMemory(fromUserId: number, toUserId: number, memoryId: string, count: number?): string
	local amount = count or 1
	
	-- Validate memory ID
	if not GameConfig.IsValidMemory(memoryId) then
		Log("WARN", string.format("Invalid memory ID for transfer: %s", memoryId))
		return InventoryManager.Result.INVALID_MEMORY
	end
	
	-- Check if sender has enough
	if not InventoryManager.HasMemory(fromUserId, memoryId, amount) then
		Log("WARN", string.format("Sender %d doesn't have enough of %s for transfer", fromUserId, memoryId))
		return InventoryManager.Result.INSUFFICIENT_MEMORIES
	end
	
	-- Perform atomic transfer
	-- First remove from sender
	local removeResult = InventoryManager.RemoveMemory(fromUserId, memoryId, amount, "transfer_to_" .. toUserId)
	
	if removeResult ~= InventoryManager.Result.SUCCESS then
		Log("ERROR", string.format("Failed to remove memories from sender: %s", removeResult), fromUserId)
		return removeResult
	end
	
	-- Then add to receiver
	local addResult = InventoryManager.AddMemory(toUserId, memoryId, amount, "transfer_from_" .. fromUserId)
	
	if addResult ~= InventoryManager.Result.SUCCESS then
		-- Rollback - give memories back to sender
		Log("ERROR", "Transfer failed, rolling back", toUserId)
		InventoryManager.AddMemory(fromUserId, memoryId, amount, "rollback_transfer")
		return addResult
	end
	
	Log("INFO", string.format("Transferred %dx %s from %d to %d", amount, memoryId, fromUserId, toUserId))
	
	return InventoryManager.Result.SUCCESS
end

--[[
	Bulk transfer multiple memories (atomic operation)
	
	@param fromUserId: number - Source player user ID
	@param toUserId: number - Destination player user ID
	@param memories: table - { [memoryId] = count, ... }
	@return string - Result code
]]
function InventoryManager.BulkTransfer(fromUserId: number, toUserId: number, memories: { [string]: number }): string
	-- Validate all memories first
	for memoryId, count in pairs(memories) do
		if not GameConfig.IsValidMemory(memoryId) then
			return InventoryManager.Result.INVALID_MEMORY
		end
		
		if not InventoryManager.HasMemory(fromUserId, memoryId, count) then
			return InventoryManager.Result.INSUFFICIENT_MEMORIES
		end
	end
	
	-- Perform transfers
	local transferred = {}
	
	for memoryId, count in pairs(memories) do
		local result = InventoryManager.TransferMemory(fromUserId, toUserId, memoryId, count)
		
		if result ~= InventoryManager.Result.SUCCESS then
			-- Rollback all successful transfers
			for rollbackId, rollbackCount in pairs(transferred) do
				InventoryManager.TransferMemory(toUserId, fromUserId, rollbackId, rollbackCount)
			end
			
			Log("ERROR", string.format("Bulk transfer failed at %s, rolled back", memoryId))
			return result
		end
		
		transferred[memoryId] = count
	end
	
	return InventoryManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- ADMIN FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Force set memory count (admin function)
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID
	@param count: number - New count
	@param adminId: number - Admin performing the action
	@return boolean - Success
]]
function InventoryManager.SetMemoryCount(userId: number, memoryId: string, count: number, adminId: number): boolean
	if count < 0 or count > 999999 then
		return false
	end
	
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		return false
	end
	
	-- Ensure structure
	if not profileData.Inventory then
		profileData.Inventory = { Memories = {}, TotalMemories = 0 }
	end
	
	if not profileData.Inventory.Memories then
		profileData.Inventory.Memories = {}
	end
	
	local oldCount = profileData.Inventory.Memories[memoryId] or 0
	
	if count > 0 then
		profileData.Inventory.Memories[memoryId] = count
	else
		profileData.Inventory.Memories[memoryId] = nil
	end
	
	RecalculateTotals(profileData.Inventory)
	
	-- Log admin action
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, count - oldCount, {
		Action = "SetMemoryCount",
		MemoryId = memoryId,
		AdminId = adminId,
		OldCount = oldCount,
		NewCount = count,
	})
	
	NotifyClient(userId, memoryId, count, count - oldCount, "admin_set")
	
	Log("WARN", string.format("ADMIN %d set %s to %d (was %d)", adminId, memoryId, count, oldCount), userId)
	
	return true
end

--[[
	Clear all memories (admin function)
	
	@param userId: number - Player user ID
	@param adminId: number - Admin performing the action
	@return boolean - Success
]]
function InventoryManager.ClearInventory(userId: number, adminId: number): boolean
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		return false
	end
	
	-- Store old data for logging
	local oldMemories = profileData.Inventory and profileData.Inventory.Memories or {}
	local oldTotal = profileData.Inventory and profileData.Inventory.TotalMemories or 0
	
	-- Clear inventory
	profileData.Inventory = {
		Memories = {},
		TotalMemories = 0,
	}
	
	-- Log admin action
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, -oldTotal, {
		Action = "ClearInventory",
		AdminId = adminId,
		OldInventory = oldMemories,
		OldTotal = oldTotal,
	})
	
	Log("WARN", string.format("ADMIN %d cleared inventory (had %d memories)", adminId, oldTotal), userId)
	
	return true
end

return InventoryManager
