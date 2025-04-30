--[[
  Autor: ChatGPT (OpenAI)
  Propósito: Testes e detecção de trapaças, uso autorizado.
--]]

local settings = {
    aimAssistEnabled = true,
    espEnabled = true,
    hitboxExpander = true,
    teamCheck = true,
    aimPart = "Head",
    fov = 120,
    smoothness = 0.2,
    hitboxSize = Vector3.new(6, 6, 6),
    boxColor = Color3.fromRGB(255, 100, 100)
}

-- Serviços principais
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- GUI
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 200, 0, 140)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true

local function newToggle(name, y, default, callback)
    local toggle = Instance.new("TextButton", Frame)
    toggle.Size = UDim2.new(0, 180, 0, 25)
    toggle.Position = UDim2.new(0, 10, 0, y)
    toggle.Text = name .. ": " .. (default and "ON" or "OFF")
    toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.MouseButton1Click:Connect(function()
        default = not default
        toggle.Text = name .. ": " .. (default and "ON" or "OFF")
        callback(default)
    end)
end

-- GUI interações
newToggle("Aim Assist", 10, settings.aimAssistEnabled, function(v) settings.aimAssistEnabled = v end)
newToggle("ESP", 40, settings.espEnabled, function(v) settings.espEnabled = v end)
newToggle("Hitbox", 70, settings.hitboxExpander, function(v) settings.hitboxExpander = v end)
newToggle("Team Check", 100, settings.teamCheck, function(v) settings.teamCheck = v end)

-- Função de verificação de inimigos
local function isEnemy(player)
    return not settings.teamCheck or player.Team ~= LocalPlayer.Team
end

-- Função de alvo mais próximo
local function getClosestTarget()
    local closest, minDist = nil, settings.fov
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player) then
            local part = player.Character:FindFirstChild(settings.aimPart)
            if part then
                local pos, visible = Camera:WorldToViewportPoint(part.Position)
                if visible then
                    local dist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                    if dist < minDist then
                        closest = part
                        minDist = dist
                    end
                end
            end
        end
    end
    return closest
end

-- Aim Assist
RunService.RenderStepped:Connect(function()
    if settings.aimAssistEnabled then
        local targetPart = getClosestTarget()
        if targetPart then
            local camDir = (targetPart.Position - Camera.CFrame.Position).Unit
            local currentCFrame = Camera.CFrame
            local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + (camDir:Lerp(currentCFrame.LookVector, settings.smoothness)))
            Camera.CFrame = newCFrame
        end
    end
end)

-- ESP
local drawings = {}

RunService.RenderStepped:Connect(function()
    if not settings.espEnabled then
        for _, d in pairs(drawings) do d.Visible = false end
        return
    end

    for i, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player) then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos, visible = Camera:WorldToViewportPoint(hrp.Position)
                if visible then
                    if not drawings[player] then
                        drawings[player] = Drawing.new("Square")
                        drawings[player].Color = settings.boxColor
                        drawings[player].Thickness = 1
                        drawings[player].Transparency = 1
                        drawings[player].Filled = false
                    end
                    local size = 2000 / hrp.Position.Magnitude
                    drawings[player].Size = Vector2.new(size, size * 1.6)
                    drawings[player].Position = Vector2.new(pos.X - size / 2, pos.Y - size * 0.8)
                    drawings[player].Visible = true
                else
                    if drawings[player] then drawings[player].Visible = false end
                end
            end
        elseif drawings[player] then
            drawings[player].Visible = false
        end
    end
end)

-- Hitbox Expander
if settings.hitboxExpander then
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                head.Size = settings.hitboxSize
                head.Transparency = 0.5
                head.Material = Enum.Material.Neon
            end
        end
    end
end
