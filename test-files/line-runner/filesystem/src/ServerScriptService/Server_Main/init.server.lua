-- Line Runner
-- TheGamer101

local path = nil
coroutine.wrap(function() path = require(script.PathCreator) end)()

-- Handle remote functions/events
function runStarting(player)
	if player.Character then
		if player.Character:FindFirstChild("FastStartScript") then
			player.Character.FastStartScript.Disabled = false
		end
	end
end
game.ReplicatedStorage.RemoteEvents.RunStarting.OnServerEvent:connect(runStarting)

local behaviourModules = {}

coroutine.wrap(function()
	for _, behaviourScript in ipairs(script.Behaviours:GetChildren()) do
		local success, errMessage = pcall(function()
			behaviourModules[behaviourScript.Name] = require(behaviourScript)
		end)
		if not success then
			warn("Failed to load module" ..behaviourScript.Name.. ".\n" ..errMessage)
		end
	end
end)()

function executeBehaviour(player, character, brickTouched, behaviourName)
	if behaviourModules[behaviourName] ~= nil then
		behaviourModules[behaviourName]:ExecuteBehaviour(brickTouched, character)
	end
end
game.ReplicatedStorage.RemoteEvents.ExecuteBehaviour.OnServerEvent:connect(executeBehaviour)

-- Initialization
local lastActivePath = {}

if game.Workspace:FindFirstChild("BasePlate") then
	game.Workspace.BasePlate:Destroy()
end

local tracksModel = Instance.new("Model")
tracksModel.Name = "Tracks"
tracksModel.Parent = game.Workspace

function packagePathModels()
	local pathPackager = require(script.PathPackager)
	while true do
		local pathBase = game.Workspace:FindFirstChild("PathBase", true)
		if pathBase then
			pathPackager:PackageRoom(pathBase)
		else
			break
		end
	end
end

coroutine.wrap(function() packagePathModels() end)()

-- Leaderboard
function updateHighScorePlayerPoints(newValue, player)
	local pointsService = game:GetService("PointsService")
	local currentBalance = pointsService:GetGamePointBalance(player.userId)
	local amountToAward = newValue - currentBalance
	pcall(function() pointsService:AwardPoints(player.userId, amountToAward) end)
end

function checkNewHighScore(player)
	if player:FindFirstChild("leaderstats") then
		if player.userId > 0 then
			local storedScore = 0
			pcall(function() storedScore = game:GetService("PointsService"):GetGamePointBalance(player.userId) end)
			if storedScore < player.leaderstats["High Score"].Value then
				updateHighScorePlayerPoints(player.leaderstats["High Score"].Value, player)
			end
		end
	end
end

function loadLeaderstats(player)
	local stats = Instance.new("IntValue")
	stats.Name = "leaderstats"

	local highScore = Instance.new("IntValue")
	highScore.Name = "High Score"
	highScore.Parent = stats
	highScore.Value = 0

	coroutine.wrap(function()
		pcall(function()
			highScore.Value = game:GetService("PointsService"):GetGamePointBalance(player.userId)
		end)
	end)()

	local currentScore = Instance.new("IntValue")
	currentScore.Name = "Score"
	currentScore.Parent = stats

	stats.Parent = player
end

function initialiseRunStats(player)
	if player:FindFirstChild("RunStats") then
		player.RunStats.Distance.Value = 0
		player.RunStats.CoinsCollected.Value = 0
	end
end

function showResults(player)
	local resultsGUI = game.ServerStorage.GUIs.PostRunGUI:Clone()
	resultsGUI.Frame.DistanceValue.Text = player.RunStats.Distance.Value
	resultsGUI.Frame.CoinsValue.Text = player.RunStats.CoinsCollected.Value
	resultsGUI.Frame.ScoreValue.Text = player.leaderstats.Score.Value

	resultsGUI.Parent = player.PlayerGui
	return resultsGUI
end

function initialiseNewRun(player, delayTime, charExpected, showLastResults)
	if not path then
		while not path do
			wait()
		end
	end

	local lastResultsGUI = nil
	if showLastResults then
		lastResultsGUI = showResults(player)
	end

	if delayTime ~= 0 then
		wait(delayTime)
	end

	if lastResultsGUI ~= nil then
		lastResultsGUI:Destroy()
	end

	if player and player.Parent then
		-- charExpected is needed to avoid calling LoadCharacter on players leaving the game
		if player.Character or charExpected == false then
			player:LoadCharacter()

			initialiseRunStats(player)

			local playersPath = path()
			lastActivePath[player.Name] = playersPath
			playersPath:init(player.Name)
		end
	end
end

function setUpPostRunStats(player)
	local folder = Instance.new("Folder")
	folder.Name = "RunStats"
	folder.Parent = player
	local currentDistance = Instance.new("IntValue")
	currentDistance.Name = "Distance"
	currentDistance.Value = 0
	currentDistance.Parent = folder
	local coinsCollected = Instance.new("IntValue")
	coinsCollected.Name = "CoinsCollected"
	coinsCollected.Value = 0
	coinsCollected.Parent = folder
end

function onPlayerEntered(player)
	player.CharacterAdded:connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		if humanoid then
			humanoid.Died:connect(function()
				initialiseNewRun(player, 4, true, true)
				checkNewHighScore(player)
			end)
		end
	end)

	-- Initial loading
	loadLeaderstats(player)
	setUpPostRunStats(player)

	-- Start game
	initialiseNewRun(player, 0, false, false)
end
game.Players.PlayerAdded:connect(onPlayerEntered)

function onPlayerRemoving(player)
	local track = game.Workspace.Tracks:FindFirstChild(player.Name)
	if track ~= nil then
		track:Destroy()
	end
end
game.Players.PlayerRemoving:connect(onPlayerRemoving)

for _, player in pairs(game.Players:GetChildren()) do
	onPlayerEntered(player)
end


