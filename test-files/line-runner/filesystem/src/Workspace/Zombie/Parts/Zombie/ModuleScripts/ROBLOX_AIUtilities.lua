local utility = {}

function utility:WideRayCast(start, target, offset, ignoreList)
	local parts = {}

	local ray = Ray.new(start, target - start)
	local part, point = game.Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
	if part then table.insert(parts, part) end

	local offsetVector = offset * (target - start):Cross(Vector3.FromNormalId(Enum.NormalId.Top)).unit
	local ray = Ray.new(start + offsetVector, target - start + offsetVector)
	local part, point = game.Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
	if part then table.insert(parts, part) end

	local ray = Ray.new(start - offsetVector, target - start - offsetVector)
	local part, point = game.Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
	if part then table.insert(parts, part) end

	return parts
end

function utility:FindNearestPathPoint(path, point, start, target, ignoreList)
	local occludePoint = path:CheckOcclusionAsync(point)
	if occludePoint > 0 then
		utility:WideRayCast(start)
	end
end

local maxForce = 75

function utility:GetRepulsionVector(unitPosition, otherUnitsPositions)
	local repulsionVector = Vector3.new(0,0,0)
	local count = 0
	for _, other in pairs(otherUnitsPositions) do
		local fromOther = unitPosition - other
		--fromOther = fromOther.unit * ((-maxForce / 5) * math.pow(fromOther.magnitude,2) + maxForce)
		fromOther = fromOther.unit * 1000 / math.pow((fromOther.magnitude + 1), 2)
		repulsionVector = repulsionVector + fromOther
	end
	return repulsionVector * maxForce
end

function utility:GetIdleState(StateMachine)
	local IdleState = StateMachine.NewState()
	IdleState.Name = "Idle"
	IdleState.Action = function() end
	IdleState.Init = function() end
	return IdleState
end

function utility:GetClosestVisibleTarget(npcModel, characters, ignoreList, fieldOfView)
	local closestTarget = nil
	local closestDistance = math.huge
	for _, character in pairs(characters) do
		local toTarget = character.HumanoidRootPart.Position - npcModel.HumanoidRootPart.Position
		local toTargetWedge = toTarget * Vector3.new(1,0,1)
		local angle = math.acos(toTargetWedge:Dot(npcModel.HumanoidRootPart.CFrame.lookVector)/toTargetWedge.magnitude)
		if math.deg(angle) < fieldOfView then
			local targetRay = Ray.new(npcModel.HumanoidRootPart.Position, toTarget)
			local part, position = game.Workspace:FindPartOnRayWithIgnoreList(targetRay, ignoreList)
			if part and part.Parent == character then
				if toTarget.magnitude < closestDistance then
					closestTarget = character
					closestDistance = toTarget.magnitude
				end
			end
		end
	end
	return closestTarget
end

local function isSpaceEmpty(position)
	local region = Region3.new(position - Vector3.new(2,2,2), position + Vector3.new(2,2,2))
	return game.Workspace:IsRegion3Empty(region)
end

function utility:FindCloseEmptySpace(model)
	local targetPos = Vector3.new(0,0,0)
	local count = 0
	math.randomseed(os.time())
	repeat
		local xoff = math.random(5,10)
		if math.random() > .5 then
			xoff = xoff * -1
		end
		local zoff = math.random(5, 10)
		if math.random() > .5 then
			zoff = zoff * -1
		end

		targetPos = Vector3.new(model.HumanoidRootPart.Position.X + xoff,model.HumanoidRootPart.Position.Y,model.HumanoidRootPart.Position.Z + zoff)
		if isSpaceEmpty(targetPos) then
			return targetPos
		else
			targetPos = targetPos + Vector3.new(0,4,0)
		end

		if isSpaceEmpty(targetPos) then
			return targetPos
		end
		count = count + 1
	until count > 10
	return nil
end

return utility