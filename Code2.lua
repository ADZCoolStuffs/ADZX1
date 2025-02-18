local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

local config = {
    FLY_SPEED = 55,
    REACH_DISTANCE = 50,
    ANTI_FALL_HEIGHT = 4,
    WALL_CLIMB_FORCE = 65,
    ANTI_VOID_CHECK_DISTANCE = 500,
    SAFE_GROUND_THRESHOLD = 4,
    ANTI_HIT_TP_HEIGHT = 1000,
    NUKE_RADIUS = 18,
    SWORD_TIERS = {"wood_sword", "stone_sword", "iron_sword", "diamond_sword", "emerald_sword"},
    PICKAXE_TIERS = {"wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "diamond_pickaxe"},
    AXE_TIERS = {"wood_axe", "stone_axe", "iron_axe", "diamond_axe"},
    ARMOR_TIERS = {"leather_armor", "iron_armor", "diamond_armor", "emerald_armor"},
    CIRCLE_COLOR = Color3.fromRGB(0, 170, 255)
}

local states = {
    flying = false,
    antiHitActive = false,
    lastSafePosition = root.Position,
    nukerActive = false,
    antiKnockback = true,
    wallClimbing = false,
    antiVoidEnabled = true,
    jumping = false
}

local function createESPBox(character)
    local highlight = Instance.new("BoxHandleAdornment")
    highlight.Name = "ESP"
    highlight.Adornee = character
    highlight.Size = character:GetExtentsSize()
    highlight.Color3 = Color3.fromRGB(255, 255, 255)
    highlight.Transparency = 0.5
    highlight.ZIndex = 10
    highlight.AlwaysOnTop = true
    highlight.Parent = character
end

local function initializeESP()
    for _, enemy in ipairs(Players:GetPlayers()) do
        if enemy ~= player and enemy.Team ~= player.Team then
            enemy.CharacterAdded:Connect(function(character)
                createESPBox(character)
            end)
            if enemy.Character then
                createESPBox(enemy.Character)
            end
        end
    end

    Players.PlayerAdded:Connect(function(newPlayer)
        if newPlayer.Team ~= player.Team then
            newPlayer.CharacterAdded:Connect(function(character)
                createESPBox(character)
            end)
        end
    end)
end

local function antiHit()
    local function findSafePosition()
        local offset = Vector3.new(0, config.ANTI_HIT_TP_HEIGHT, 0)
        return root.Position + offset
    end

    RunService.Heartbeat:Connect(function()
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= player and target.Team ~= player.Team then
                local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if tRoot and (root.Position - tRoot.Position).Magnitude < config.NUKE_RADIUS then
                    local safePosition = findSafePosition()
                    local originalCameraCFrame = Camera.CFrame

                    root.CFrame = CFrame.new(safePosition)
                    task.wait(0.1)
                    root.CFrame = CFrame.new(root.Position + Vector3.new(0, config.ANTI_HIT_TP_HEIGHT, 0))

                    Camera.CFrame = originalCameraCFrame
                    break
                end
            end
        end
    end)
end

local function antiVoid()
    RunService.Heartbeat:Connect(function()
        if states.antiVoidEnabled and not states.jumping then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character}
            local result = Workspace:Raycast(root.Position, Vector3.new(0, -config.ANTI_VOID_CHECK_DISTANCE, 0), raycastParams)
            
            if not result then
                root.CFrame = CFrame.new(states.lastSafePosition)
            else
                states.lastSafePosition = root.Position
            end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        states.jumping = true
        states.antiVoidEnabled = false
        task.wait(1)
        states.jumping = false
        states.antiVoidEnabled = true
    end)
end

local function wallClimb()
    RunService.Heartbeat:Connect(function()
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character}
        local result = Workspace:Raycast(root.Position, root.CFrame.LookVector * 3, raycastParams)
        
        if result and result.Instance.CanCollide then
            root.Velocity = Vector3.new(root.Velocity.X, config.WALL_CLIMB_FORCE, root.Velocity.Z)
            states.wallClimbing = true
            task.wait(0.05)
            root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
        else
            states.wallClimbing = false
        end
    end)
end

local function antiKnockback()
    RunService.Heartbeat:Connect(function()
        if states.antiKnockback then
            root.Velocity = Vector3.new(root.Velocity.X * 0.35, root.Velocity.Y, root.Velocity.Z * 0.35)
        end
    end)
end

local function getBestTool(toolType)
    local bestTool = nil
    local highestTier = 0
    local toolTiers = toolType == "pickaxe" and config.PICKAXE_TIERS or config.AXE_TIERS

    for i, toolName in ipairs(toolTiers) do
        local tool = player.Backpack:FindFirstChild(toolName)
        if tool and i > highestTier then
            highestTier = i
            bestTool = tool
        end
    end

    return bestTool
end

local function nuker()
    RunService.Heartbeat:Connect(function()
        if not states.nukerActive then
            states.nukerActive = true
            for _, target in ipairs(Workspace:GetPartsInPart(root, config.NUKE_RADIUS)) do
                local parent = target.Parent
                if parent then
                    if parent.Name == "bed" then
                        local bestPickaxe = getBestTool("pickaxe")
                        if bestPickaxe then
                            humanoid:EquipTool(bestPickaxe)
                            for _ = 1, 25 do
                                bestPickaxe:Activate()
                                task.wait(0.1)
                            end
                        end
                        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
                            config.TOXIC_RESPONSES.bedDestroyed,
                            "All"
                        )
                    elseif parent:FindFirstChild("Humanoid") and parent ~= character then
                        local bestAxe = getBestTool("axe")
                        if bestAxe then
                            humanoid:EquipTool(bestAxe)
                            for _ = 1, 25 do
                                bestAxe:Activate()
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
            states.nukerActive = false
        end
    end)
end

local function killAura()
    RunService.Heartbeat:Connect(function()
        local tool = character:FindFirstChildWhichIsA("Tool")
        if tool and table.find(config.SWORD_TIERS, tool.Name) then
            for _, target in ipairs(Players:GetPlayers()) do
                if target ~= player and target.Team ~= player.Team then
                    local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot and (root.Position - tRoot.Position).Magnitude <= config.REACH_DISTANCE then
                        tool:Activate()
                    end
                end
            end
        end
    end)
end

local function antiFall()
    RunService.Heartbeat:Connect(function()
        if humanoid.FloorMaterial == Enum.Material.Air and root.Velocity.Y < 0 then
            root.Velocity = Vector3.new(root.Velocity.X, config.ANTI_FALL_HEIGHT, root.Velocity.Z)
        end
    end)
end

initializeESP()
antiHit()
antiVoid()
wallClimb()
antiKnockback()
nuker()
killAura()
antiFall()
