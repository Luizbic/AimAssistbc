-- CONFIGS
local aimEnabled = true
local aimFOV = 350  -- Campo de visão em pixels
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", gui)
local title = Instance.new("TextLabel", frame)
local toggle = Instance.new("TextButton", frame)
local status = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 220, 0, 130)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "Aimbot & ESP PRO"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Parent = frame

toggle.Size = UDim2.new(0, 180, 0, 40)
toggle.Position = UDim2.new(0, 20, 0, 40)
toggle.Text = "Desativar Aimbot"
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 16
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
toggle.BorderSizePixel = 0
toggle.Parent = frame

status.Size = UDim2.new(1, 0, 0, 30)
status.Position = UDim2.new(0, 0, 0, 90)
status.Text = "Aimbot: Ativo"
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.BackgroundTransparency = 1
status.Parent = frame

toggle.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    toggle.Text = aimEnabled and "Desativar Aimbot" or "Ativar Aimbot"
    toggle.BackgroundColor3 = aimEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(100, 100, 100)
    status.Text = "Aimbot: " .. (aimEnabled and "Ativo" or "Inativo")
end)

-- ESP
local function createESP(player)
    local box = Drawing.new("Square")
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Thickness = 2
    box.Transparency = 1
    box.Filled = false
    box.Visible = false
    return box
end

local espBoxes = {}

for _, p in pairs(players:GetPlayers()) do
    if p ~= localPlayer then
        espBoxes[p] = createESP(p)
    end
end

players.PlayerAdded:Connect(function(p)
    if p ~= localPlayer then
        espBoxes[p] = createESP(p)
    end
end)

players.PlayerRemoving:Connect(function(p)
    if espBoxes[p] then
        espBoxes[p]:Remove()
        espBoxes[p] = nil
    end
end)

-- Aimbot: Encontra inimigo mais próximo do centro da tela
local function getClosestEnemy()
    local closest, minDist = nil, aimFOV
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= localPlayer and p.Team ~= localPlayer.Team and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local pos, visible = camera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
            if visible then
                local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = p
                end
            end
        end
    end
    return closest
end

-- Mira direto no inimigo
local function aimAt(player)
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    camera.CFrame = CFrame.new(camera.CFrame.Position, root.Position)
end

-- Loop principal
game:GetService("RunService").RenderStepped:Connect(function()
    -- Atualiza ESP
    for p, box in pairs(espBoxes) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Team ~= localPlayer.Team and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local root = p.Character.HumanoidRootPart
            local head = p.Character:FindFirstChild("Head")
            if root and head then
                local top, onTop = camera:WorldToViewportPoint(head.Position)
                local bottom, onBottom = camera:WorldToViewportPoint(root.Position)
                if onTop and onBottom then
                    local height = math.abs(top.Y - bottom.Y)
                    local width = height / 2
                    box.Size = Vector2.new(width, height)
                    box.Position = Vector2.new(bottom.X - width/2, bottom.Y - height/2)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end

    -- Aimbot
    if aimEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target)
        end
    end
end)
