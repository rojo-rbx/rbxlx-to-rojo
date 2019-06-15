--local PathLib = require(game.ServerStorage.PathfindingLibrary).new()
local HumanoidList = require(game.ServerStorage.ROBLOX_HumanoidList)
local AIUtilities = require(game.ServerStorage.ROBLOX_AIUtilities)

local ZombieAI = {}

function updateDisplay(display, state)
	local thread = coroutine.create(function()
		while true do
			wait()
			if state then
				display.Text = state.Name
			end
		end
	end)
	coroutine.resume(thread)
end

ZombieAI.new = function(model)
	local zombie = {}

	-- CONFIGURATION VARIABLES
--	local AttackRange, FieldOfView, AggroRange, ChanceOfBoredom, BoredomDuration,
--		Damage, DamageCooldown

	local configTable = model.Configurations
	local configs = {}
	local function loadConfig(configName, defaultValue)
		if configTable:FindFirstChild(configName) then
			configs[configName] = configTable:FindFirstChild(configName).Value
		else
			configs[configName] = defaultValue
		end
	end

	loadConfig("AttackRange", 3)
	loadConfig("FieldOfView", 180)
	loadConfig("AggroRange", 200)
	loadConfig("ChanceOfBoredom", .5)
	loadConfig("BoredomDuration", 10)
	loadConfig("Damage", 10)
	loadConfig("DamageCooldown", 1)

	local StateMachine = require(game.ServerStorage.ROBLOX_StateMachine).new()
	local PathLib = require(game.ServerStorage.ROBLOX_PathfindingLibrary).new()
	local ZombieTarget = nil
	local ZombieTargetLastLocation = nil

	local lastBored = os.time()

	-- STATE DEFINITIONS

	-- IdleState: NPC stays still. Refreshes bored timer when started to
	-- allow for random state change
	local IdleState = StateMachine.NewState()
	IdleState.Name = "Idle"
	IdleState.Action = function()
	end
	IdleState.Init = function()
		lastBored = os.time()
	end

	-- SearchState: NPC wanders randomly increasing chance of spotting
	-- enemy. Refreshed bored timer when started to allow for random state
	-- change
	local SearchState = StateMachine.NewState()
	SearchState.Name = "Search"
	local lastmoved = os.time()
	local searchTarget = nil
	SearchState.Action = function()
		-- move to random spot nearby
		if model then
			if model:FindFirstChild("HumanoidRootPart") then
				local now = os.time()
				if now - lastmoved > 2 then
					lastmoved = now
					local xoff = math.random(5, 10)
					if math.random() > .5 then
						xoff = xoff * -1
					end
					local zoff = math.random(5, 10)
					if math.random() > .5 then
						zoff = zoff * -1
					end

					local testtarg = AIUtilities:FindCloseEmptySpace(model)
					--if testtarg then print(testtarg) else print("could not find") end
					searchTarget = Vector3.new(model.HumanoidRootPart.Position.X + xoff,model.HumanoidRootPart.Position.Y,model.HumanoidRootPart.Position.Z + zoff)
					--local target = Vector3.new(model.HumanoidRootPart.Position.X + xoff,model.HumanoidRootPart.Position.Y,model.HumanoidRootPart.Position.Z + zoff)
					--model.Humanoid:MoveTo(target)
					searchTarget = testtarg
				end
				--PathLib:MoveToTarget(model, searchTarget) --Zombie will fall off path when searching
			end
		end
	end
	SearchState.Init = function()
		lastBored = os.time()
	end

	-- PursueState: Enemy has been spotted, need to give chase.
	local PursueState = StateMachine.NewState()
	PursueState.Name = "Pursue"
	PursueState.Action = function()
		-- Double check we still have target
		if ZombieTarget then
			if model:FindFirstChild("HumanoidRootPart") then
				if ZombieTarget:FindFirstChild("HumanoidRootPart") then
					-- Get distance to target
					local distance = (model.HumanoidRootPart.Position - ZombieTarget.HumanoidRootPart.Position).magnitude
					-- If we're far from target use pathfinding to move. Otherwise just MoveTo
					if distance > configs["AttackRange"] + 5 then
						PathLib:MoveToTarget(model, ZombieTarget.HumanoidRootPart.Position)
					else
						model.Humanoid:MoveTo(ZombieTarget.HumanoidRootPart.Position)
		--				if ZombieTarget.HumanoidRootPart.Position.Y > model.HumanoidRootPart.Position.Y + 2 then
		--					model.Humanoid.Jump = true
		--				end
					end
				end
			end
		end
	end
	PursueState.Init = function()
	end

	-- AttackState: Keep moving towards target and play attack animation.
	local AttackState = StateMachine.NewState()
	AttackState.Name = "Attack"
	local lastAttack = os.time()
	local attackTrack = model.Humanoid:LoadAnimation(model.Animations.Attack)
	AttackState.Action = function()
		model.Humanoid:MoveTo(ZombieTarget.HumanoidRootPart.Position)
		local now = os.time()
		if now - lastAttack > 3 then
			lastAttack = now
			attackTrack:Play()
		end
	end

	-- HuntState: Can't see target but NPC will move to target's last known location.
	-- Will eventually get bored and switch state.
	local HuntState = StateMachine.NewState()
	HuntState.Name = "Hunt"
	HuntState.Action = function()
		if ZombieTargetLastLocation then
			PathLib:MoveToTarget(model, ZombieTargetLastLocation)
		end
	end
	HuntState.Init = function()
		lastBored = os.time() + configs["BoredomDuration"] / 2
	end

	-- CONDITION DEFINITIONS

	-- CanSeeTarget: Determines if a target is visible. Returns true if target is visible and
	-- sets current target. A target is valid if it is nearby, visible, has a HumanoidRootPart and WalkSpeed
	-- greater than 0 (this is to ignore inanimate objects that happen to use humanoids)
	local CanSeeTarget = StateMachine.NewCondition()
	CanSeeTarget.Name = "CanSeeTarget"
	CanSeeTarget.Evaluate = function()
		if model then
			-- Get list of all nearby Zombies and non-Zombie humanoids
			-- Zombie list is used to ignore zombies during later raycast
			local humanoids = HumanoidList:GetCurrent()
			local zombies = {}
			local characters = {}
			for _, object in pairs(humanoids) do
				if object and object.Parent and object.Parent:FindFirstChild("HumanoidRootPart") and object.Health > 0 and object.WalkSpeed > 0 then
					local HumanoidRootPart = object.Parent:FindFirstChild("HumanoidRootPart")
					if HumanoidRootPart and model:FindFirstChild("HumanoidRootPart") then
						local distance = (model.HumanoidRootPart.Position - HumanoidRootPart.Position).magnitude
						if distance <= configs["AggroRange"] then
							if object.Parent.Name == "Zombie" then
								table.insert(zombies, object.Parent)
							else
								table.insert(characters, object.Parent)
							end
						end
					end
				end
			end

			local target = AIUtilities:GetClosestVisibleTarget(model, characters, zombies, configs["FieldOfView"])
			if target then
				ZombieTarget = target
				return true
			end

--			-- Go through each valid target to see if within field of view and if there is
--			-- clear line of sight. Field of view treated as wedge in front of character.
--			for _, character in pairs(characters) do
--				local toTarget = (character.HumanoidRootPart.Position - model.HumanoidRootPart.Position)
--				toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
--				local angle = math.acos(toTarget:Dot(model.HumanoidRootPart.CFrame.lookVector)/toTarget.magnitude)
--				if math.deg(angle) < configs["FieldOfView"]/2 then
--					ZombieTarget = character
--					-- raycast to see if target is actually visible
--					local toTarget = Ray.new(model.HumanoidRootPart.Position, (ZombieTarget.HumanoidRootPart.Position - model.HumanoidRootPart.Position))
--					local part, position = game.Workspace:FindPartOnRayWithIgnoreList(toTarget, zombies)
--					if part and part.Parent == ZombieTarget then
--						return true
--					end
--					ZombieTarget = nil
--				end
--			end
		end
		return false
	end
	CanSeeTarget.TransitionState = PursueState

	-- TargetDead: Check if target is dead.
	local TargetDead = StateMachine.NewCondition()
	TargetDead.Name = "TargetDead"
	TargetDead.Evaluate = function()
		if ZombieTarget and ZombieTarget.Humanoid then
			return ZombieTarget.Humanoid.Health <= 0
		end
		return true
	end
	TargetDead.TransitionState = IdleState

	-- GotDamaged: Check if NPC has taken damage
	local lastHealth = model.Humanoid.Health
	local GotDamaged = StateMachine.NewCondition()
	GotDamaged.Name = "GotDamaged"
	GotDamaged.Evaluate = function()
		if model then
			if lastHealth > model.Humanoid.Health then
				return true
			end
		end
		return false
	end
	GotDamaged.TransitionState = SearchState

	-- GotBored: Used to provide random state change.
	local GotBored = StateMachine.NewCondition()
	GotBored.Name = "GotBored"
	GotBored.Evaluate = function()
		local now = os.time()
		if now - lastBored > configs["BoredomDuration"] then
			local roll = math.random()
			if roll < configs["ChanceOfBoredom"] then
				lastBored = now
				if GotBored.TransitionState == SearchState then
					GotBored.TransitionState = IdleState
				else
					GotBored.TransitionState = SearchState
				end
				return true
			end
		end
		return false
	end
	GotBored.TransitionState = IdleState

	-- LostTarget: Checks clear line of sight
	local LostTarget = StateMachine.NewCondition()
	LostTarget.Name = "LostTarget"
	LostTarget.Evaluate = function()
		if true then return false end
		if ZombieTarget then
			if (ZombieTarget.HumanoidRootPart.Position - model.HumanoidRootPart.Position).magnitude > 10 then
				local toTarget = Ray.new(model.HumanoidRootPart.Position, (ZombieTarget.HumanoidRootPart.Position - model.HumanoidRootPart.Position))
				local part, position = game.Workspace:FindPartOnRay(toTarget, model)
				if not part or part.Parent ~= ZombieTarget  then
					--print("Lost target!")
					ZombieTargetLastLocation = ZombieTarget.HumanoidRootPart.Position
					ZombieTarget = nil
					return true
				end
			end
		end
		return false
	end
	LostTarget.TransitionState = HuntState

	local WithinRange = StateMachine.NewCondition()
	WithinRange.Name = "WithinRange"
	WithinRange.Evaluate = function()
		if ZombieTarget then
			if model:FindFirstChild("HumanoidRootPart") then
				local distance = (model.HumanoidRootPart.Position - ZombieTarget.HumanoidRootPart.Position).magnitude
				if distance < configs["AttackRange"] then
					--print("Within attack range!")
					return true
				end
			end
		end
		return false
	end
	WithinRange.TransitionState = AttackState

	local OutsideRange = StateMachine.NewCondition()
	OutsideRange.Name = "OutsideRange"
	OutsideRange.Evaluate = function()
		if ZombieTarget then
			if model:FindFirstChild("HumanoidRootPart") and ZombieTarget:FindFirstChild("HumanoidRootPart") then
				local distance = (model.HumanoidRootPart.Position - ZombieTarget.HumanoidRootPart.Position).magnitude
				if distance > configs["AttackRange"] then
					--print("Outside attack range!")
					return true
				end
			end
		end
		return false
	end
	OutsideRange.TransitionState = PursueState

	table.insert(IdleState.Conditions, CanSeeTarget)
	table.insert(IdleState.Conditions, GotDamaged)
	table.insert(IdleState.Conditions, GotBored)

	table.insert(SearchState.Conditions, GotBored)
	table.insert(SearchState.Conditions, CanSeeTarget)

	table.insert(PursueState.Conditions, LostTarget)
	table.insert(PursueState.Conditions, WithinRange)
	table.insert(PursueState.Conditions, TargetDead)

	table.insert(AttackState.Conditions, OutsideRange)
	table.insert(AttackState.Conditions, TargetDead)

	table.insert(HuntState.Conditions, GotBored)
	table.insert(HuntState.Conditions, CanSeeTarget)

	-- Setup arms damage
	local canHit = true
	local lastHit = os.time()
	local function handleHit(other, zombieArm)
		if canHit then
			if other and other.Parent and other.Parent.Name ~= "Zombie" and other.Parent:FindFirstChild("Humanoid") then
				local enemy = other.Parent
				if enemy.Humanoid.WalkSpeed > 0 then
					local shield = enemy:FindFirstChild("Shield")
					if shield then
						model:BreakJoints()
					end
					local killBehaviour = require(game.ServerScriptService.Server_Main.Behaviours.Kill)
					killBehaviour:ExecuteBehaviour(zombieArm, enemy)
				end
			end
		else
			local now = os.time()
			if now - lastHit > configs["DamageCooldown"] then
				lastHit = now
				canHit = true
			end
		end
	end
	local leftHitConnect, rightHitConnect
	leftHitConnect = model:FindFirstChild("Left Arm").Touched:connect(function(other) handleHit(other, model:FindFirstChild("Left Arm")) end)
	rightHitConnect = model:FindFirstChild("Right Arm").Touched:connect(function(other) handleHit(other, model:FindFirstChild("Right Arm")) end)

	--ZombieAI.Animate(model)
	--updateDisplay()
	--updateDisplay(model.BillboardGui.TextLabel, StateMachine.CurrentState)
	local thread = coroutine.create(function()
		while true do
			wait()
			-- calculate repulsion force
			if model == nil then
				break
			end

			if model:FindFirstChild("HumanoidRootPart") == nil then
				break
			end

			local humanoids = HumanoidList:GetCurrent()
			local localZombies = {}
			for _, humanoid in pairs(humanoids) do
				if humanoid and humanoid ~= model.Humanoid and humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart") then
					local HumanoidRootPart = humanoid.Parent:FindFirstChild("HumanoidRootPart")
					if HumanoidRootPart ~= nil and model ~= nil then
						if model:FindFirstChild("HumanoidRootPart") then
							local distance = (model.HumanoidRootPart.Position - HumanoidRootPart.Position).magnitude
							if distance <= 2.5 then
								table.insert(localZombies, HumanoidRootPart.Position)
							end
						end
					end
				end
			end
			local repulsionDirection = AIUtilities:GetRepulsionVector(model.HumanoidRootPart.Position, localZombies)
			if repulsionDirection.magnitude > 0 then
				--print("replusion direction: " .. tostring(repulsionDirection))
			end
			model.HumanoidRootPart.RepulsionForce.force = repulsionDirection

			if StateMachine.CurrentState and model.Configurations.Debug.Value then
				model.BillboardGui.TextLabel.Visible = true
				model.BillboardGui.TextLabel.Text = StateMachine.CurrentState.Name
			end
			if not model.Configurations.Debug.Value then
				model.BillboardGui.TextLabel.Visible = false
			end
		end
	end)
	coroutine.resume(thread)

	StateMachine.SwitchState(IdleState)

	zombie.Stop = function()
		StateMachine.SwitchState(nil)
	end

	return zombie
end

return ZombieAI