--[[
    Aimbot + ESP com Interface Moderna
    Compatível com exploits como Synapse X, KRNL, Fluxus, etc.
    Feito para jogos com TeamCheck e personagens com HumanoidRootPart
--]]

-- CONFIGURAÇÕES
local aimEnabled = true  -- Ativar/Desativar Aimbot
local aimFOV = 350       -- Campo de visão (FOV)
local smoothing = 0.1    -- Suavização do movimento do Aimbot
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

-- Função para alternar o Aimbot
toggle.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled
    toggle.Text = aimEnabled and "Desativar Aimbot" or "Ativar Aimbot"
    toggle.BackgroundColor3 = aimEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(100, 100, 100)
    status.Text = "Aimbot: " .. (aimEnabled and "Ativo" or "Inativo")
end)

-- FUNÇÕES AUXILIARES

-- Checa se o jogador é inimigo
local function isEnemy(player)
    return player.Team ~= localPlayer.Team and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
end

-- Cria e retorna o ESP do jogador
local function createESP(player)
    local box = Drawing.new("Square")
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Thickness = 2
    box.Transparency = 1
    box.Filled = false
    box.Visible = false
    return box
end

-- Função para calcular a distância entre dois pontos na tela
local function calculateDistanceFromCenter(x, y)
    local screenCenterX = camera.ViewportSize.X / 2
    local screenCenterY = camera.ViewportSize.Y / 2
    return math.sqrt((x - screenCenterX)^2 + (y - screenCenterY)^2)
end

-- Função para obter o inimigo mais próximo
local function getClosestEnemy()
    local closest = nil
    local minDist = aimFOV
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) then
            local pos, onScreen = camera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
            if onScreen then
                local dist = calculateDistanceFromCenter(pos.X, pos.Y)
                if dist < minDist then
                    minDist = dist
                    closest = p
                end
            end
        end
    end
    return closest
end

-- Função para mirar no inimigo
local function aimAt(player)
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local direction = (root.Position - camera.CFrame.Position).unit
    camera.CFrame = CFrame.new(camera.CFrame.Position, root.Position) * CFrame.new(direction * smoothing)
end

-- Atualiza o ESP na tela
local function updateESP()
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) then
            local box = createESP(p)
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local top, onTop = camera:WorldToViewportPoint(root.Position)
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
        end
    end
end

-- Lógica principal do Aimbot + ESP
runService.RenderStepped:Connect(function()
    -- Atualiza o ESP constantemente
    updateESP()

    -- Aimbot
    if aimEnabled then
        local target = getClosestEnemy()
        if target then
            aimAt(target)
        end
    end
end)
