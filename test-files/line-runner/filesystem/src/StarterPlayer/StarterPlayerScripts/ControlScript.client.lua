local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local doJump = false
local reviving = false
local characterWalkSpeed = 40

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

player:WaitForChild("PlayerGui")

local function jump()
	if player.Character ~= nil then
		if player.Character.Humanoid.WalkSpeed == 0 then
			-- Character is not yet moving, start screen was shown
			doJump = false
			if player.PlayerGui.StartScreen.StartInstructions.Visible == true then
				player.PlayerGui.StartScreen:Destroy()
				player.Character.Humanoid.WalkSpeed = characterWalkSpeed
				game.ReplicatedStorage.RemoteEvents.RunStarting:FireServer()
			end
		else
			player.Character.Humanoid.Jump = true
		end
	end
end

-- Handles behaviours
local function characterTouchedBrick(partTouched)
	local behaviours = partTouched:FindFirstChild("Behaviours")
	if behaviours ~= nil then
		behaviours = behaviours:GetChildren()
		for i = 1, #behaviours do
			if behaviours[i].Value == true then
				game.ReplicatedStorage.RemoteEvents.ExecuteBehaviour:FireServer(player.Character, partTouched, behaviours[i].Name)
			end
		end
	end
end

function characterAdded(newCharacter)
	local humanoid = newCharacter:WaitForChild("Humanoid")
	humanoid.WalkSpeed = 0
	humanoid.Touched:connect(characterTouchedBrick)

	local splashScreen = player.PlayerGui:WaitForChild("StartScreen")

	if UserInputService.TouchEnabled == false then
		if UserInputService.GamepadEnabled then
			splashScreen.StartInstructions.StartLabel.Text = "Press Space or Gamepad A Button to Start"
		else
			splashScreen.StartInstructions.StartLabel.Text = "Press Space to Start"
		end

	end
	if reviving == true then
		reviving = false
		splashScreen:Destroy()
		humanoid.WalkSpeed = characterWalkSpeed
	end

	humanoid.WalkSpeed = 0
end
player.CharacterAdded:connect(characterAdded)

if player.Character then
	characterAdded(player.Character)
end

function checkReviving(addedGui)
	if addedGui.Name == "RevivingGUI" then
		reviving = true
	end
end
player.PlayerGui.ChildAdded:connect(checkReviving)

if UserInputService.TouchEnabled then
	UserInputService.ModalEnabled = true
	UserInputService.TouchStarted:connect(function(inputObject, gameProcessedEvent) if gameProcessedEvent == false then doJump = true end end)
	UserInputService.TouchEnded:connect(function() doJump = false end)
else
	ContextActionService:BindAction("Jump", function(action, userInputState, inputObject) doJump = (userInputState == Enum.UserInputState.Begin) end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

game:GetService("RunService").RenderStepped:connect(function()
	if player.Character ~= nil then
		if player.Character:FindFirstChild("Humanoid") then
			if doJump == true then
				jump()
			end
			player.Character.Humanoid:Move(Vector3.new(0,0,-1), false)
		end
	end
end)
