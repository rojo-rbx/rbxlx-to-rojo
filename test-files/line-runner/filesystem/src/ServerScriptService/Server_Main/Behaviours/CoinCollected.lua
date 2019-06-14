local module = {}

function module:ExecuteBehaviour(brickTouched, character)
	if character:FindFirstChild("Humanoid") ~= nil then
		if character.Humanoid.Health > 0 then
			if brickTouched ~= nil then
				if brickTouched.Parent ~= nil then
					local player = game.Players:GetPlayerFromCharacter(character)
					if player ~= nil then
						if brickTouched.Parent:FindFirstChild("Coin") then
							if brickTouched.Parent.Coin:FindFirstChild("Sound") then
								local sound = brickTouched.Parent.Coin.Sound:Clone()
								sound.Parent = player.PlayerGui
								sound:Play()
								game:GetService("Debris"):AddItem(sound, 1)
							end
						end
						brickTouched.Parent:Destroy()
						player.RunStats.CoinsCollected.Value = player.RunStats.CoinsCollected.Value + 1
					end
				end
			end
		end
	end
end

return module

