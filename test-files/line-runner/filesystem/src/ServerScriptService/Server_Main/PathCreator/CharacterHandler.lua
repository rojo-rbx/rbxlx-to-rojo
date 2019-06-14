function makeCharacterHandler()
	local characterHandler = {}

	characterHandler.SpawnPoint	= nil

	characterHandler.newHighScore = false
	--characterHandler.newHighScore = characterHandler.player.leaderstats["High Score"].Value > 0
	characterHandler.player = nil
	characterHandler.character = nil

	--Updates the score based on how far from the SpawnPoint the character is
	function characterHandler:UpdateScore()
		local player = characterHandler.player
		local character = characterHandler.character
		local leaderstats = player and player:FindFirstChild("leaderstats") or nil
		if player and character and leaderstats then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or not (humanoid.Health > 0) then
				return
			end

			local torso = character:FindFirstChild("HumanoidRootPart")

			if not torso then
				return
			end

			-- Sanity check for large score increases
			if characterHandler.SpawnPoint.Z - torso.Position.Z > leaderstats.Score.Value + 100 then
				return
			end

			-- Update Score
			player.RunStats.Distance.Value = characterHandler.SpawnPoint.Z - torso.Position.Z
			leaderstats.Score.Value = player.RunStats.Distance.Value + player.RunStats.CoinsCollected.Value * 50

			-- Update High Score
			if leaderstats.Score.Value > leaderstats["High Score"].Value then
				-- First time player, don't show New High Score GUI
				if characterHandler.player.leaderstats["High Score"].Value == 0 then
					characterHandler.newHighScore = true
				end

				leaderstats["High Score"].Value = leaderstats.Score.Value

				-- Show New High Score GUI if they beat their High Score for the first time in this run
				if characterHandler.newHighScore == false then
					characterHandler.newHighScore = true
					game.ServerStorage.GUIs.HighScore:Clone().Parent = characterHandler.player.PlayerGui
				end
			end
		end
	end

	characterHandler.BodyPartPositions = {
		["Head"] = {},
		["Torso"] = {},
		["Right Arm"] = {},
		["Left Arm"] = {},
		["Right Leg"] = {},
		["Left Leg"] = {},
		["HumanoidRootPart"] = {}
	}


	function characterHandler:UpdateBodyPartPositions()
		if characterHandler.character then
			for _, part in pairs(characterHandler.character:GetChildren()) do
				if part:isA("BasePart") then
					if characterHandler.BodyPartPositions[part.Name] == nil then
						characterHandler.BodyPartPositions[part.Name] = {}
					end
					table.insert(characterHandler.BodyPartPositions[part.Name], 1, part.CFrame)
					if #characterHandler.BodyPartPositions[part.Name] > 120 then
						table.remove(characterHandler.BodyPartPositions[part.Name], 121)
					end
				end
			end
		end
	end

	--Can collide is false for the previously cloned handles of the hats
	local function canCollideParts(character)
		local parts = character:GetChildren()
		for i = 1, #parts do
			if parts[i]:isA("BasePart") then
				if parts[i].CanCollide == false then
					parts[i].CanCollide = true
				end
			end
		end
	end

	function characterHandler:init(startPathModel, playerName)
		characterHandler.player = game.Players:FindFirstChild(playerName)
		if characterHandler.player ~= nil then
			characterHandler.character = characterHandler.player.Character

			if not characterHandler.character then
				characterHandler.player.CharacterAdded:wait()
				characterHandler.character = characterHandler.player.Character
			end

			characterHandler.newHighScore = characterHandler.player.leaderstats["High Score"].Value > 0
			characterHandler.SpawnPoint = startPathModel.Start.Position + Vector3.new(0, 4, -3)
			characterHandler.character:MoveTo(characterHandler.SpawnPoint)
			local updateScoreConnection = game:GetService("RunService").Heartbeat:connect(function() self:UpdateScore() end)
			characterHandler.updatePositionsConnection = game:GetService("RunService").Heartbeat:connect(function() self:UpdateBodyPartPositions() end)
			characterHandler.character.Humanoid.Died:connect(function()
				updateScoreConnection:disconnect()
				canCollideParts(characterHandler.character)
			end)
			characterHandler.player.CharacterRemoving:connect(function() characterHandler.updatePositionsConnection:disconnect() end)
		end
	end

	return characterHandler
end

return makeCharacterHandler