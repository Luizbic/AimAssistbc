-- Configurações
local aimKey = "mouse1" -- Botão para ativar o aim assist
local aimFOV = 100       -- Campo de visão para ativar o aim assist
local smoothing = 0.2    -- Suavização do movimento
local localPlayer = nil  -- Referência ao jogador local

-- Função para desenhar a interface
function drawInterface()
    draw.text(10, 10, "Aim Assist: Ativado", color.green)
    draw.text(10, 30, "Tecla: " .. aimKey, color.white)
    draw.text(10, 50, "FOV: " .. tostring(aimFOV), color.white)
end

-- Checa se o jogador é inimigo
function isEnemy(player)
    return player.team ~= localPlayer.team and player.health > 0
end

-- Calcula distância em tela entre jogador local e alvo
function screenDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Retorna o inimigo mais próximo do centro da tela dentro do FOV
function getClosestEnemy()
    local closest = nil
    local minDist = aimFOV
    local screenW, screenH = draw.getScreenSize()
    local screenX, screenY = screenW / 2, screenH / 2

    for _, player in pairs(game.getPlayers()) do
        if player ~= localPlayer and isEnemy(player) then
            local x, y = worldToScreen(player.position)
            if x and y then
                local dist = screenDistance(screenX, screenY, x, y)
                if dist < minDist then
                    minDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Função principal do Aim Assist
function aimAtTarget()
    if not input.isKeyDown(aimKey) then return end

    local target = getClosestEnemy()
    if target then
        local targetX, targetY = worldToScreen(target.position)
        local screenW, screenH = draw.getScreenSize()
        local deltaX = (targetX - screenW / 2) * smoothing
        local deltaY = (targetY - screenH / 2) * smoothing
        input.moveMouse(deltaX, deltaY)
    end
end

-- Inicialização
client.registerCallback("onCreateMove", function(cmd)
    if not localPlayer then
        localPlayer = game.getLocalPlayer()
    end
    aimAtTarget()
end)

client.registerCallback("onDraw", drawInterface)
