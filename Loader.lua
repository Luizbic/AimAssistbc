-- Configurações
local aimFOV = 100
local smoothing = 0.2
local aimEnabled = false

-- Criação da Interface
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Frame = Instance.new("Frame", ScreenGui)
local ToggleButton = Instance.new("TextButton", Frame)
local Title = Instance.new("TextLabel", Frame)

-- Estilo da Interface
Frame.Size = UDim2.new(0, 200, 0, 120)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0

Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "Aim Assist GUI"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.SourceSans
Title.TextSize = 20

ToggleButton.Size = UDim2.new(0, 180, 0, 40)
ToggleButton.Position = UDim2.new(0, 10, 0, 40)
ToggleButton.Text = "Ativar Aim Assist"
ToggleButton.TextColor3 = Color3.new(1, 1, 1)
ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ToggleButton.BorderSizePixel = 0
ToggleButton.Font = Enum.Font.SourceSans
ToggleButton.TextSize = 18

-- Alternar aim assist
ToggleButton.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    ToggleButton.Text = aimEnabled and "Desativar Aim Assist" or "Ativar Aim Assist"
    ToggleButton.BackgroundColor3 = aimEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60)
end)

-- Função para buscar inimigo mais próximo
local function getClosestEnemy()
    local players = game:GetService("Players")
    local localPlayer = players.LocalPlayer
    local camera = workspace.CurrentCamera
    local closest = nil
    local minDist = aimFOV

    for _, player in pairs(players:GetPlayers()) do
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

-- Mira no inimigo suavemente
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

-- Loop principal
game:GetService("RunService").RenderStepped:Connect(function()
    if aimEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target)
        end
    end
end)
