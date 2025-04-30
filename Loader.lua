-- [ Aimbot + ESP + GUI Moderna (Revisado) ]
-- Compatível com Synapse X, KRNL, Fluxus, etc.

-- Serviços
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer= Players.LocalPlayer
local Camera     = workspace.CurrentCamera

-- Configurações
local AimbotAtivado = true
local ESPAtivado    = true
local FOV           = 300     -- pixels
local smoothing     = 0.2     -- 0 = instantâneo, 1 = sem movimento

-- GUI
local screenGui = Instance.new("ScreenGui", game.CoreGui)
screenGui.Name = "AimbotInterface"

local frame = Instance.new("Frame", screenGui)
frame.Size               = UDim2.new(0, 250, 0, 160)
frame.Position           = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3   = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel    = 0
frame.Active             = true
frame.Draggable          = true

local title = Instance.new("TextLabel", frame)
title.Size               = UDim2.new(1, 0, 0, 30)
title.Position           = UDim2.new(0, 0, 0, 0)
title.Text               = "Aimbot & ESP Pro"
title.Font               = Enum.Font.GothamBold
title.TextSize           = 20
title.TextColor3         = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1

local btnAimbot = Instance.new("TextButton", frame)
btnAimbot.Size           = UDim2.new(0, 220, 0, 40)
btnAimbot.Position       = UDim2.new(0, 15, 0, 40)
btnAimbot.Text           = "Desativar Aimbot"
btnAimbot.Font           = Enum.Font.Gotham
btnAimbot.TextSize       = 16
btnAimbot.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
btnAimbot.BorderSizePixel = 0
btnAimbot.TextColor3     = Color3.new(1, 1, 1)

local lblESP = Instance.new("TextLabel", frame)
lblESP.Size              = UDim2.new(1, 0, 0, 30)
lblESP.Position          = UDim2.new(0, 0, 0, 90)
lblESP.Text              = "ESP: Ativado"
lblESP.Font              = Enum.Font.Gotham
lblESP.TextSize          = 14
lblESP.TextColor3        = Color3.fromRGB(200, 200, 200)
lblESP.BackgroundTransparency = 1

btnAimbot.MouseButton1Click:Connect(function()
    AimbotAtivado = not AimbotAtivado
    btnAimbot.Text = AimbotAtivado and "Desativar Aimbot" or "Ativar Aimbot"
    btnAimbot.BackgroundColor3 = AimbotAtivado and Color3.fromRGB(0,170,0) or Color3.fromRGB(100,100,100)
end)

-- Tabela de ESP boxes
local espBoxes = {}

-- Cria um box de ESP para um jogador
local function criarBox(p)
    local box = Drawing.new("Square")
    box.Color       = Color3.fromRGB(255, 0, 0)
    box.Thickness   = 2
    box.Transparency= 1
    box.Filled      = false
    box.Visible     = false
    espBoxes[p]     = box
end

-- Remove o box de ESP de um jogador
local function removerBox(p)
    if espBoxes[p] then
        espBoxes[p]:Remove()
        espBoxes[p] = nil
    end
end

-- Inicializa boxes para jogadores já presentes
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then criarBox(p) end
end
-- Monitora jogadores entrando e saindo
Players.PlayerAdded:Connect(criarBox)
Players.PlayerRemoving:Connect(removerBox)

-- Checa se é inimigo válido e vivo
local function isEnemy(p)
    if p.Team == LocalPlayer.Team then return false end
    local c = p.Character
    local h = c and c:FindFirstChild("Humanoid")
    return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Obtém o inimigo mais próximo do centro
local function getClosestEnemy()
    local alvo, menorDist = nil, FOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for p, box in pairs(espBoxes) do
        if isEnemy(p) then
            local root = p.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if dist < menorDist then
                    menorDist = dist
                    alvo = p
                end
            end
        end
    end
    return alvo
end

-- Mira suavemente no alvo
local function aimAt(p)
    local root = p.Character.HumanoidRootPart
    local dir = (root.Position - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + dir)
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, smoothing)
end

-- Atualiza todas as caixas de ESP
local function updateESP()
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for p, box in pairs(espBoxes) do
        if ESPAtivado and isEnemy(p) then
            local root = p.Character.HumanoidRootPart
            local head = p.Character:FindFirstChild("Head")
            if head then
                local top, topVis = Camera:WorldToViewportPoint(head.Position)
                local bot, botVis = Camera:WorldToViewportPoint(root.Position)
                if topVis and botVis then
                    local height = math.abs(top.Y - bot.Y)
                    local width  = height / 2
                    box.Size     = Vector2.new(width, height)
                    box.Position = Vector2.new(bot.X - width/2, bot.Y - height/2)
                    box.Visible  = true
                    goto continue
                end
            end
        end
        box.Visible = false
        ::continue::
    end
end

-- Loop principal
RunService.RenderStepped:Connect(function()
    updateESP()
    if AimbotAtivado then
        local alvo = getClosestEnemy()
        if alvo then aimAt(alvo) end
    end
end)
