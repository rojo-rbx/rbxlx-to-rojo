local camera = game.Workspace.CurrentCamera
local player = game.Players.LocalPlayer

camera.CameraType = Enum.CameraType.Scriptable

local targetDistance = 30
local cameraDistance = -30
local cameraDirection = Vector3.new(-1,0,0)

local currentTarget = cameraDirection*targetDistance
local currentPosition = cameraDirection*cameraDistance

game:GetService("RunService").RenderStepped:connect(function()
	local character = player.Character
	if character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
		local torso = character.HumanoidRootPart
		camera.Focus = torso.CFrame
		if torso:FindFirstChild("FastStart") == nil then
			camera.CoordinateFrame = 	CFrame.new(Vector3.new(torso.Position.X, torso.Position.Y + 10, torso.Position.Z - 20) + currentPosition,
										Vector3.new(torso.Position.X,  torso.Position.Y, torso.Position.Z - 20) + currentTarget)
		else
			--Lower camera for fast start
			camera.CoordinateFrame = CFrame.new(Vector3.new(torso.Position.X, torso.Position.Y - 15, torso.Position.Z - 20) + currentPosition,
											    Vector3.new(torso.Position.X,  torso.Position.Y - 15, torso.Position.Z - 20) + currentTarget)
		end
	end
end)
