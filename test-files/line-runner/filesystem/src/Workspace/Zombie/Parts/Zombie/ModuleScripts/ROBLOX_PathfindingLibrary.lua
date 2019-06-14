local PathfindingUtility = {}
local TargetOffsetMax = 10--5
local JumpThreshold = 1.5 --2.5
local NextPointThreshold = 4
local PathfindingService = game:GetService("PathfindingService")
PathfindingService.EmptyCutoff = .3

function PathfindingUtility.new()
	local this = {}

	local currentTargetPos = nil
	local lastTargetPos = Vector3.new(math.huge, math.huge, math.huge)
	local path = nil
	local currentPointIndex = 1

	function this:MoveToTarget(character, target)
		local targetOffset = (lastTargetPos - target).magnitude
--
--		local targetOffsetVector = (lastTargetPos - target)
--		if targetOffsetVector.magnitude < math.huge then
--			targetOffsetVector = (lastTargetPos - target) * Vector3.new(1,0,1)
--		end
		if targetOffset > TargetOffsetMax then
		--if targetOffsetVector.magnitude > TargetOffsetMax then
			--print("moveto")
			local startPoint = character.HumanoidRootPart.Position
			local humanoidState = character.Humanoid:GetState()
			if humanoidState == Enum.HumanoidStateType.Jumping or humanoidState == Enum.HumanoidStateType.Freefall then
				--print("this")
				local ray = Ray.new(character.HumanoidRootPart.Position, Vector3.new(0, -100, 0))
				local hitPart, hitPoint = game.Workspace:FindPartOnRay(ray, character)
				if hitPart then
					startPoint = hitPoint
				end
			end
			--print("making new path")
			local newTarget = target
			local ray = Ray.new(target + Vector3.new(0,-3,0), Vector3.new(0, -100, 0))
			local hitPart, hitPoint = game.Workspace:FindPartOnRay(ray, character)
			if hitPoint then
				if (hitPoint - target).magnitude > 4 then
					newTarget = newTarget * Vector3.new(1,0,1) + Vector3.new(0,3,0)
				end
			end

			--local newTarget = Vector3.new(1,0,1) * target + Vector3.new(0, 2, 0)
			path = PathfindingService:ComputeSmoothPathAsync(startPoint, newTarget, 500)
			if path.Status ~= Enum.PathStatus.Success then
				--print(tostring(path.Status))
			end
			--path = PathfindingService:ComputeRawPathAsync(startPoint, target, 500)

--			game.Workspace.Points:ClearAllChildren()
--			local ps = path:GetPointCoordinates()
--			for _, point in pairs(ps) do
--				local part = Instance.new("Part", game.Workspace.Points)
--				part.CanCollide = false
--				part.Anchored = true
--				part.FormFactor = Enum.FormFactor.Custom
--				part.Size = Vector3.new(1,1,1)
--				part.Position = point
--			end

			currentPointIndex = 1
			lastTargetPos = target
		end

		if path then
			local points = path:GetPointCoordinates()
			if currentPointIndex < #points then
				local currentPoint = points[currentPointIndex]
				if character:FindFirstChild("HumanoidRootPart") then
					local distance = (character.HumanoidRootPart.Position - currentPoint).magnitude
					if distance < NextPointThreshold then
						currentPointIndex = currentPointIndex + 1
					end

					character.Humanoid:MoveTo(points[currentPointIndex])
					if points[currentPointIndex].Y - character.HumanoidRootPart.Position.Y > JumpThreshold then
						character.Humanoid.Jump = true
					end
				end
			else
				if character:FindFirstChild("Humanoid") then
					character.Humanoid:MoveTo(target)
				end
			end
		end
	end

	return this
end
return PathfindingUtility 