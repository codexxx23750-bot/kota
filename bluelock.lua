-- [kota] Blue Lock Career - Mission/Milestone Hunter v19
-- Foco: Encontrar remotes de "missão/marco" e tentar spammar.

local CONFIG = {
    default_interval = 0.1,
    -- Palavras-chave para o hook: qualquer coisa que cheire a "tarefa" ou "recompensa de progresso"
    keywords = {
        "mission", "task", "milestone", "achievement", "progress", 
        "claim", "reward", "complete", "finish", "goal"
    },
}

-- (A UI é a mesma da v18, apenas o título muda)
local UI = {}
UI.__index = UI
function UI.new(on_close_callback)
    local self = setmetatable({}, UI)
    self.gui = Instance.new("ScreenGui"); self.gui.Name = "kota_ui"; self.gui.ResetOnSpawn = false
    if gethui then self.gui.Parent = gethui() else self.gui.Parent = game:GetService("CoreGui") end
    local main = Instance.new("Frame"); main.Size = UDim2.new(0, 420, 0, 400); main.Position = UDim2.new(0.02, 0, 0.1, 0); main.BackgroundColor3 = Color3.fromRGB(10, 10, 10); main.BorderSizePixel = 0; main.Active = true; main.Parent = self.gui
    -- (código de arrastar omitido para brevidade, é o mesmo da v18)
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(31,31,31); stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = main
    local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,40); title.BackgroundColor3 = Color3.fromRGB(10,10,10); title.Text = "kota v19 (Mission Hunter)"; title.TextColor3 = Color3.fromRGB(255,255,255); title.Font = Enum.Font.Code; title.TextSize = 20; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 2; title.Parent = main
    local title_pad = Instance.new("UIPadding"); title_pad.PaddingLeft = UDim.new(0,12); title_pad.Parent = title
    local close = Instance.new("TextButton"); close.Size = UDim2.new(0,32,0,32); close.Position = UDim2.new(1,-40,0,4); close.BackgroundColor3 = Color3.fromRGB(10,10,10); close.Text = "×"; close.TextColor3 = Color3.fromRGB(255,255,255); close.Font = Enum.Font.Code; close.TextSize = 18; close.ZIndex = 2; close.Parent = main
    close.MouseButton1Click:Connect(function() if on_close_callback then on_close_callback() end; self.gui:Destroy() end)
    local log = Instance.new("ScrollingFrame"); log.Size = UDim2.new(1,-24,0,180); log.Position = UDim2.new(0,12,0,50); log.BackgroundColor3 = Color3.fromRGB(5,5,5); log.BorderSizePixel = 0; log.ScrollBarThickness = 4; log.CanvasSize = UDim2.new(0,0,0,0); log.AutomaticCanvasSize = Enum.AutomaticSize.Y; log.ZIndex = 2; log.Parent = main
    local log_layout = Instance.new("UIListLayout"); log_layout.Padding = UDim.new(0,2); log_layout.Parent = log
    local status = Instance.new("TextLabel"); status.Size = UDim2.new(1,-24,0,24); status.Position = UDim2.new(0,12,0,240); status.BackgroundColor3 = Color3.fromRGB(10,10,10); status.Text = "idle"; status.TextColor3 = Color3.fromRGB(180,180,180); status.Font = Enum.Font.Code; status.TextSize = 12; status.TextXAlignment = Enum.TextXAlignment.Left; status.ZIndex = 2; status.Parent = main
    local speed_lbl = Instance.new("TextLabel"); speed_lbl.Size = UDim2.new(0,80,0,24); speed_lbl.Position = UDim2.new(0,12,0,275); speed_lbl.BackgroundColor3 = Color3.fromRGB(10,10,10); speed_lbl.Text = "Speed (ms)"; speed_lbl.TextColor3 = Color3.fromRGB(160,160,160); speed_lbl.Font = Enum.Font.Code; speed_lbl.TextSize = 11; speed_lbl.TextXAlignment = Enum.TextXAlignment.Left; speed_lbl.ZIndex = 2; speed_lbl.Parent = main
    local speed_input = Instance.new("TextBox"); speed_input.Size = UDim2.new(0,60,0,24); speed_input.Position = UDim2.new(0,100,0,275); speed_input.BackgroundColor3 = Color3.fromRGB(5,5,5); speed_input.BorderSizePixel = 1; speed_input.BorderColor3 = Color3.fromRGB(31,31,31); speed_input.Text = tostring(CONFIG.default_interval * 1000); speed_input.TextColor3 = Color3.fromRGB(255,255,255); speed_input.Font = Enum.Font.Code; speed_input.TextSize = 12; speed_input.ZIndex = 2; speed_input.Parent = main
    local btn_capture = Instance.new("TextButton"); btn_capture.Size = UDim2.new(0,180,0,40); btn_capture.Position = UDim2.new(0,12,0,315); btn_capture.BackgroundColor3 = Color3.fromRGB(10,10,10); btn_capture.Text = "1. CAPTURE"; btn_capture.TextColor3 = Color3.fromRGB(255,255,255); btn_capture.Font = Enum.Font.Code; btn_capture.TextSize = 14; btn_capture.ZIndex = 2; btn_capture.Parent = main
    local btn_farm = Instance.new("TextButton"); btn_farm.Size = UDim2.new(0,180,0,40); btn_farm.Position = UDim2.new(0,204,0,315); btn_farm.BackgroundColor3 = Color3.fromRGB(10,10,10); btn_farm.Text = "2. AUTO SPAM: OFF"; btn_farm.TextColor3 = Color3.fromRGB(255,255,255); btn_farm.Font = Enum.Font.Code; btn_farm.TextSize = 14; btn_farm.ZIndex = 2; btn_farm.Parent = main
    self.main = main; self.log = log; self.status = status; self.btn_capture = btn_capture; self.btn_farm = btn_farm; self.speed_input = speed_input
    return self
end
function UI:add_log(text, color) if not self.log or not self.log.Parent then return end; local label = Instance.new("TextLabel"); label.Size = UDim2.new(1,-12,0,16); label.BackgroundTransparency = 1; label.Text = text; label.TextColor3 = color or Color3.fromRGB(180,180,180); label.Font = Enum.Font.Code; label.TextSize = 11; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextWrapped = true; label.ZIndex = 3; label.Parent = self.log; local labels = {}; for _, c in ipairs(self.log:GetChildren()) do if c:IsA("TextLabel") then table.insert(labels, c) end end; if #labels > 50 then labels[1]:Destroy() end; self.log.CanvasPosition = Vector2.new(0, self.log.AbsoluteCanvasSize.Y) end
function UI:set_status(text, color) if self.status and self.status.Parent then self.status.Text = text; self.status.TextColor3 = color end end

-- Lógica (mesma da v18, mas com filtro de keywords expandido)
local target_remote = nil
local target_method = nil
local target_args = {}
local target_args_n = 0
local is_farming = false
local current_interval = CONFIG.default_interval
local function has_keyword(s) if type(s) ~= "string" then return false end; s = s:lower(); for _, kw in ipairs(CONFIG.keywords) do if s:find(kw, 1, true) then return true end end; return false end
local ui = UI.new(function() is_farming = false end)
ui.speed_input.FocusLost:Connect(function() local n = tonumber(ui.speed_input.Text); if n and n >= 10 then current_interval = n / 1000 else ui.speed_input.Text = tostring(CONFIG.default_interval * 1000); current_interval = CONFIG.default_interval end end)
ui.btn_capture.MouseButton1Click:Connect(function()
    if is_farming then ui:add_log("Desligue o Spam primeiro.", Color3.fromRGB(255,120,120)); return end
    if not hookmetamethod or not getnamecallmethod then ui:add_log("Executor sem suporte a hook.", Color3.fromRGB(255,120,120)); return end
    ui:set_status("Aguardando interação com missão/marco...", Color3.fromRGB(200,160,80))
    ui:add_log("VÁ NO MENU DE MISSÕES/MARCOS E CLIQUE EM 'RESGATAR'!", Color3.fromRGB(120,255,120))
    target_remote = nil; local real_namecall
    local function restore_hook() pcall(function() hookmetamethod(game, "__namecall", real_namecall) end) end
    local ok = pcall(function()
        real_namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local ok_n, name = pcall(function() return self.Name end)
                if ok_n and has_keyword(name) and not target_remote then
                    local packed = table.pack(...)
                    target_remote = self; target_method = method; target_args = packed; target_args_n = packed.n
                    ui:add_log("[!] CAPTURADO: " .. name .. " (" .. method .. ")", Color3.fromRGB(120,255,120))
                    ui:set_status("Alvo capturado! Ligue o Spam.", Color3.fromRGB(120,255,120))
                end
            end
            return real_namecall(self, ...)
        end)
    end)
    if not ok then ui:add_log("Falha ao instalar hook.", Color3.fromRGB(255,120,120)); return end
    task.delay(10, function()
        if not target_remote then ui:add_log("Tempo esgotado. Nenhum remote de missão capturado.", Color3.fromRGB(255,120,120)); ui:set_status("Falha na captura.", Color3.fromRGB(255,120,120)) end
        restore_hook()
    end)
end)
ui.btn_farm.MouseButton1Click:Connect(function()
    if is_farming then is_farming = false; ui.btn_farm.Text = "2. AUTO SPAM: OFF"; ui:set_status("Spam desligado.", Color3.fromRGB(180,180,180)); return end
    if not target_remote then ui:add_log("Nenhum alvo. Use o CAPTURE primeiro.", Color3.fromRGB(255,120,120)); return end
    is_farming = true; ui.btn_farm.Text = "2. AUTO SPAM: ON"; ui:set_status("Spammando missão/marco...", Color3.fromRGB(120,255,120))
    task.spawn(function()
        local count = 0
        while is_farming do
            task.spawn(function()
                pcall(function()
                    if target_method == "InvokeServer" then target_remote:InvokeServer(table.unpack(target_args, 1, target_args_n))
                    else target_remote:FireServer(table.unpack(target_args, 1, target_args_n)) end
                end)
            end)
            count = count + 1; if count % 50 == 0 then ui:set_status(string.format("Spam: %d pedidos", count), Color3.fromRGB(120,255,120)) end
            task.wait(current_interval)
        end
    end)
end)
ui:add_log("kota v19 (Mission Hunter) carregado.", Color3.fromRGB(255,255,255))
