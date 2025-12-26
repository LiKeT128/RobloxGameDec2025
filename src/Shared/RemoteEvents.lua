--[[
	RemoteEvents.lua
	Network communication setup for Memory Rush
	
	Creates and manages all RemoteEvents and RemoteFunctions
	used for client-server communication.
	
	Usage:
		-- On server:
		local Remotes = require(ReplicatedStorage.Shared.RemoteEvents)
		Remotes.CurrencyChanged:FireClient(player, data)
		
		-- On client:
		local Remotes = require(ReplicatedStorage.Shared.RemoteEvents)
		Remotes.CurrencyChanged.OnClientEvent:Connect(function(data) ... end)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.GameConfig)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local RemoteEvents = {}

-- Container for all remotes
local remotesFolder: Folder

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

local function createRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	
	return folder
end

local function createRemoteEvent(name: string): RemoteEvent
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	
	return remote
end

local function createRemoteFunction(name: string): RemoteFunction
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
	
	return remote
end

local function getRemote(name: string): RemoteEvent | RemoteFunction | nil
	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotesFolder then
			warn("[RemoteEvents] Failed to find Remotes folder")
			return nil
		end
	end
	
	return remotesFolder:WaitForChild(name, 5)
end

--------------------------------------------------------------------------------
-- SETUP BASED ON CONTEXT (SERVER/CLIENT)
--------------------------------------------------------------------------------

local function setupServer()
	remotesFolder = createRemotesFolder()
	
	-- Create all RemoteEvents from config
	for _, eventName in ipairs(GameConfig.RemoteEvents) do
		local remote = createRemoteEvent(eventName)
		RemoteEvents[eventName] = remote
	end
	
	-- Create all RemoteFunctions from config
	for _, funcName in ipairs(GameConfig.RemoteFunctions) do
		local remote = createRemoteFunction(funcName)
		RemoteEvents[funcName] = remote
	end
	
	print("[RemoteEvents] Server setup complete - Created", 
		#GameConfig.RemoteEvents, "events and", 
		#GameConfig.RemoteFunctions, "functions")
end

local function setupClient()
	remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 30)
	
	if not remotesFolder then
		error("[RemoteEvents] Failed to find Remotes folder after 30 seconds")
	end
	
	-- Get references to all RemoteEvents
	for _, eventName in ipairs(GameConfig.RemoteEvents) do
		local remote = getRemote(eventName)
		if remote then
			RemoteEvents[eventName] = remote
		else
			warn("[RemoteEvents] Failed to find RemoteEvent:", eventName)
		end
	end
	
	-- Get references to all RemoteFunctions
	for _, funcName in ipairs(GameConfig.RemoteFunctions) do
		local remote = getRemote(funcName)
		if remote then
			RemoteEvents[funcName] = remote
		else
			warn("[RemoteEvents] Failed to find RemoteFunction:", funcName)
		end
	end
	
	print("[RemoteEvents] Client setup complete")
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

-- Get a specific remote by name
function RemoteEvents.GetRemote(name: string): RemoteEvent | RemoteFunction | nil
	return RemoteEvents[name] or getRemote(name)
end

-- Check if all remotes are ready
function RemoteEvents.IsReady(): boolean
	if not remotesFolder then
		return false
	end
	
	for _, eventName in ipairs(GameConfig.RemoteEvents) do
		if not RemoteEvents[eventName] then
			return false
		end
	end
	
	for _, funcName in ipairs(GameConfig.RemoteFunctions) do
		if not RemoteEvents[funcName] then
			return false
		end
	end
	
	return true
end

-- Wait for remotes to be ready
function RemoteEvents.WaitForReady(timeout: number?): boolean
	local maxTime = timeout or 30
	local elapsed = 0
	
	while not RemoteEvents.IsReady() and elapsed < maxTime do
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end
	
	return RemoteEvents.IsReady()
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS FOR COMMON OPERATIONS
--------------------------------------------------------------------------------

-- Fire an event to a specific player (server only)
function RemoteEvents.FireClient(eventName: string, player: Player, ...: any)
	if not RunService:IsServer() then
		warn("[RemoteEvents] FireClient can only be called from server")
		return
	end
	
	local remote = RemoteEvents[eventName]
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, ...)
	else
		warn("[RemoteEvents] RemoteEvent not found:", eventName)
	end
end

-- Fire an event to all players (server only)
function RemoteEvents.FireAllClients(eventName: string, ...: any)
	if not RunService:IsServer() then
		warn("[RemoteEvents] FireAllClients can only be called from server")
		return
	end
	
	local remote = RemoteEvents[eventName]
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	else
		warn("[RemoteEvents] RemoteEvent not found:", eventName)
	end
end

-- Fire an event to server (client only)
function RemoteEvents.FireServer(eventName: string, ...: any)
	if not RunService:IsClient() then
		warn("[RemoteEvents] FireServer can only be called from client")
		return
	end
	
	local remote = RemoteEvents[eventName]
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(...)
	else
		warn("[RemoteEvents] RemoteEvent not found:", eventName)
	end
end

-- Invoke server function (client only)
function RemoteEvents.InvokeServer(funcName: string, ...: any): any
	if not RunService:IsClient() then
		warn("[RemoteEvents] InvokeServer can only be called from client")
		return nil
	end
	
	local remote = RemoteEvents[funcName]
	if remote and remote:IsA("RemoteFunction") then
		return remote:InvokeServer(...)
	else
		warn("[RemoteEvents] RemoteFunction not found:", funcName)
		return nil
	end
end

-- Set callback for remote function (server only)
function RemoteEvents.SetCallback(funcName: string, callback: (Player, ...any) -> ...any)
	if not RunService:IsServer() then
		warn("[RemoteEvents] SetCallback can only be called from server")
		return
	end
	
	local remote = RemoteEvents[funcName]
	if remote and remote:IsA("RemoteFunction") then
		remote.OnServerInvoke = callback
	else
		warn("[RemoteEvents] RemoteFunction not found:", funcName)
	end
end

-- Connect to client event (client only)
function RemoteEvents.OnClientEvent(eventName: string, callback: (...any) -> ()): RBXScriptConnection?
	if not RunService:IsClient() then
		warn("[RemoteEvents] OnClientEvent can only be called from client")
		return nil
	end
	
	local remote = RemoteEvents[eventName]
	if remote and remote:IsA("RemoteEvent") then
		return remote.OnClientEvent:Connect(callback)
	else
		warn("[RemoteEvents] RemoteEvent not found:", eventName)
		return nil
	end
end

-- Connect to server event (server only)
function RemoteEvents.OnServerEvent(eventName: string, callback: (Player, ...any) -> ()): RBXScriptConnection?
	if not RunService:IsServer() then
		warn("[RemoteEvents] OnServerEvent can only be called from server")
		return nil
	end
	
	local remote = RemoteEvents[eventName]
	if remote and remote:IsA("RemoteEvent") then
		return remote.OnServerEvent:Connect(callback)
	else
		warn("[RemoteEvents] RemoteEvent not found:", eventName)
		return nil
	end
end

--------------------------------------------------------------------------------
-- AUTO-INITIALIZATION
--------------------------------------------------------------------------------

if RunService:IsServer() then
	setupServer()
else
	-- Client setup happens when the module is required
	task.spawn(setupClient)
end

return RemoteEvents
