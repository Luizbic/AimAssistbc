-- Configurações
local aimEnabled = false
local aimFOV = 300
local smoothing = 0.05

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", gui)
local toggle = Instance.new("TextButton", frame)
local title = Instance.new("TextLabel", frame)

frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0

title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "AIM ASSIST + ESP"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.BackgroundTransparency = 1
title.TextSize = 18

toggle.Size = UDim2.new(0, 180, 0, 40)
toggle.Position = UDim2.new(0, 10, 0, 50)
toggle.Text = "Ativar Aim Assist"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 16
toggle.BorderSizePixel = 0

toggle.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    toggle.Text = aimEnabled and "Desativar Aim Assist" or "Ativar Aim Assist"
    toggle.BackgroundColor3 = aimEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60)
end)

-- ESP: desenhar caixas vermelhas
local function createESP(player)
    local box = Drawing.new("Square")
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Thickness = 2
    box.Transparency = 1
    box.Visible = false
    box.Filled = false
    return box
end

local espBoxes = {}
for _, player in pairs(game:GetService("Players"):GetPlayers()) do
    if player ~= game.Players.LocalPlayer then
        espBoxes[player] = createESP(player)
    end
end

game:GetService("Players").PlayerAdded:Connect(function(player)
    if player ~= game.Players.LocalPlayer then
        espBoxes[player] = createESP(player)
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if espBoxes[player] then
        espBoxes[player]:Remove()
        espBoxes[player] = nil
    end
end)

-- Buscar inimigo
local function getClosestEnemy()
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    local camera = workspace.CurrentCamera
    local closest = nil
    local minDist = aimFOV

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Team ~= localPlayer.Team and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local pos, visible = camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if visible then
                local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = player
                end
            end
        end
    end

    return closest
end

-- Mira automática
local function aimAt(target)
    local camera = workspace.CurrentCamera
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pos, visible = camera:WorldToViewportPoint(root.Position)
    if visible then
        local mouse = game:GetService("UserInputService"):GetMouseLocation()
        local delta = (Vector2.new(pos.X, pos.Y) - mouse) * smoothing
        mousemoverel(delta.X, delta.Y)
    end
end

-- Loop: ESP + Aim Assist
game:GetService("RunService").RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    local localPlayer = game.Players.LocalPlayer

    for player, box in pairs(espBoxes) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Team ~= localPlayer.Team then
            local rootPart = player.Character.HumanoidRootPart
            local head = player.Character:FindFirstChild("Head")
            if rootPart and head then
                local headPos, onScreen1 = camera:WorldToViewportPoint(head.Position)
                local rootPos, onScreen2 = camera:WorldToViewportPoint(rootPart.Position)

                if onScreen1 and onScreen2 then
                    local height = math.abs(headPos.Y - rootPos.Y)
                    local width = height / 2
                    box.Size = Vector2.new(width, height)
                    box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
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

    -- Aim Assist
    if aimEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target)
        end
    end
end)
