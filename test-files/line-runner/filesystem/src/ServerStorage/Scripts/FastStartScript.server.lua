local character = script.Parent
local humanoid = character.Humanoid
local spawnLocation = character.HumanoidRootPart.Position
local player = game.Players:GetPlayerFromCharacter(character)

local started = false

--Casts a ray to find the height for the character to hover at even if the path is going up or down
function findHeight(distanceInFront)
	local torso = character.HumanoidRootPart
	local ray = Ray.new(
    Vector3.new(torso.Position.X, torso.Position.Y + 50, torso.Position.Z - distanceInFront), 	-- origin
    (Vector3.new(0, -1, 0)).unit * 300)	 														-- direction
	local ignore = character
	local hit, position = game.Workspace:FindPartOnRay(ray, ignore)
	return position.Y + 40
end

function highest(tableOfValues)
	local highestSoFar = tableOfValues[1]
	for i = 2, #tableOfValues do
		if tableOfValues[i] > highestSoFar then
			highestSoFar = tableOfValues[i]
		end
	end
	return highestSoFar
end

function fastStart()
	if started == false then
		started = true
		local fastStartPosition = Instance.new("BodyPosition")
		fastStartPosition.Name = "FastStart"
		fastStartPosition.maxForce = Vector3.new(0, 15000, 0)
		fastStartPosition.Parent = character.HumanoidRootPart
		local fastStartVelocity = Instance.new("BodyVelocity")
		fastStartVelocity.maxForce = Vector3.new(0, 0, 15000)
		fastStartVelocity.velocity = Vector3.new(0, 0, -150)
		fastStartVelocity.Parent = character.HumanoidRootPart
		fastStartPosition.position = Vector3.new(0, highest({findHeight(0), findHeight(10), findHeight(20), findHeight(30)}), 0)
		while character.HumanoidRootPart.Position.Z > spawnLocation.Z - 1000 do
			wait(1)
			if character:FindFirstChild("HumanoidRootPart") == nil then
				break
			end
			fastStartPosition.position = Vector3.new(0, highest({findHeight(0), findHeight(10), findHeight(20), findHeight(30)}), 0)
		end
		fastStartVelocity.velocity = Vector3.new(0, 0, 0)
		wait(2)
		if character:FindFirstChild("HumanoidRootPart") then
			fastStartPosition:Destroy()
			fastStartVelocity:Destroy()
			local shield = Instance.new("ForceField")
			shield.Name = "Shield"
			shield.Parent = character
			game:GetService("Debris"):AddItem(shield, 3)
		end
		fastStart:Destroy()
		script:Destroy()
	end
end

fastStart() --Script starts disabled, only enabled when a player starts running


