local machine = {}

machine.new = function()
	local StateMachine = {}

	StateMachine.WaitTime = .2
	StateMachine.CurrentState = nil
	StateMachine.SwitchState = function(newState)
		if StateMachine.CurrentState then
			StateMachine.CurrentState.Stop()
		end
		StateMachine.CurrentState = newState
		if newState then
			newState.Start()
		end
	end

	StateMachine.NewState = function()
		local state = {}
		state.Name = ""
		state.Conditions = {}
		state.isRunning = false
		state.Action = function() end
		state.Run = function()
			state.isRunning = true
			while state.isRunning do
				--check conditions
				--print("checking conditions")
				for _, condition in pairs(state.Conditions) do
					--print("Checking " .. condition.Name)
					if condition.Evaluate() then
						--print(condition.Name .. " is true. Switching states")
						StateMachine.SwitchState(condition.TransitionState)
						return
					end
				end

				--if no conditions satisfied, perform action
				state.Action()
				wait(StateMachine.WaitTime)
			end
		end
		state.Init = function()

		end
		state.Start = function()
			--print("Starting " .. state.Name)
			state.Init()
			local thread = coroutine.create(state.Run)
			coroutine.resume(thread)
		end
		state.Stop = function()
			--print("Stopping " .. state.Name)
			state.isRunning = false
		end
		return state
	end

	StateMachine.NewCondition = function()
		local condition = {}
		condition.Name = ""
		condition.Evaluate = function() print("replace me") return false end
		condition.TransitionState = {}
		return condition
	end

	return StateMachine
end

return machine