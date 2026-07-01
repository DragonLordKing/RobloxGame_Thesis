--[[
Name: AvatarAbilitiesInterface
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.ControlModule.AvatarAbilitiesInterface
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Services: Players
Requires:
  - local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
Functions: characterAdded, lazyInit, AvatarAbilitiesInterface.isEnabled, AvatarAbilitiesInterface.GetEnabledChangedSignal
Signal classes referenced: BindableEvent
Clean source lines: 67
]]
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local FFlagUserAllowAbilityControls = FlagUtil.getUserFlag("UserAllowAbilityControls")

if FFlagUserAllowAbilityControls then

    local Players = game:GetService("Players")

    local AvatarAbilitiesInterface = {}
    local AbilityManagerActor = nil
    local humanoid = nil
    local enabledChangedEvent = Instance.new("BindableEvent")
    local evaluateStateMachineChangedConnection = nil
    local initialized = false

    local function characterAdded(character)
        AbilityManagerActor = nil
        humanoid = nil
        if evaluateStateMachineChangedConnection then
            evaluateStateMachineChangedConnection:Disconnect()
            evaluateStateMachineChangedConnection = nil
        end

        if character then
            AbilityManagerActor = character:FindFirstChild("AbilityManagerActor")
            humanoid = character:FindFirstChildOfClass("Humanoid")
            while not humanoid do
                character.ChildAdded:wait()
                humanoid = character:FindFirstChildOfClass("Humanoid")
            end
            enabledChangedEvent:Fire()

            evaluateStateMachineChangedConnection = humanoid:GetPropertyChangedSignal("EvaluateStateMachine"):Connect(function()
                enabledChangedEvent:Fire()
            end)
        end
    end

    local function lazyInit()
        if initialized then
            return
        end
        initialized = true

        local player = Players.LocalPlayer
        if player then
            player.characterAdded:Connect(characterAdded)
            if player.Character then
                characterAdded(player.Character)
            end
        end
    end

    function AvatarAbilitiesInterface.isEnabled()
        lazyInit()
        return AbilityManagerActor ~= nil and humanoid and not humanoid.EvaluateStateMachine
    end

    function AvatarAbilitiesInterface.GetEnabledChangedSignal()
        lazyInit()
        return enabledChangedEvent.Event
    end

    return AvatarAbilitiesInterface

end
