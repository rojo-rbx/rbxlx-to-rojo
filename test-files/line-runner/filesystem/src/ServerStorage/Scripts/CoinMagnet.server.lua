local character = script.Parent
local player = game.Players:GetPlayerFromCharacter(character)
script.Parent:WaitForChild("HumanoidRootPart")
local torso = script.Parent.HumanoidRootPart

game:GetService("RunService").Heartbeat:connect(function()
	local playersTrack = game.Workspace.Tracks:FindFirstChild(player.Name)
	if playersTrack then
		if playersTrack:FindFirstChild("Coins") then
			local coins = playersTrack.Coins:GetChildren()
			for i = 1, #coins do
				if (coins[i].Coin.Position - torso.Position).magnitude < 50 then
					coins[i].Coin.BodyPosition.maxForce = Vector3.new(500000000, 500000000, 500000000)
					if torso.Position.Z > coins[i].Coin.Position.Z then
						coins[i].Coin.BodyPosition.position = torso.Position
						coins[i].Coin.BodyPosition.P = 1500
					else
						--Needs to anticipate where the player is going
						coins[i].Coin.BodyPosition.position = Vector3.new(torso.Position.X, torso.Position.Y, torso.Position.Z - 10)
						coins[i].Coin.BodyPosition.P = 2500
					end
					coins[i].CoinBoundingBox.Position = coins[i].Coin.Position
					if (coins[i].Coin.Position - torso.Position).magnitude < 5 then
						coins[i].CoinBoundingBox.Position = Vector3.new(torso.Position.X, torso.Position.Y, torso.Position.Z - 3)
					end
				end
			end
		end
	end
end)


