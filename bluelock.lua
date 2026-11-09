-- [kota] Lucky Spin Automation — Black & White UI
-- Executor-agnostic. Fallback gracioso se APIs faltarem.
-- Anti-ban: jitter, backoff, sessão curta, honeypot blacklist, hook restore.

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    base_interval   = 1.2,     -- segundos entre spins (jitter ±40%)
    spins_per_session = 40,    -- pausa longa após N spins
    session_pause_min = 30,    -- pausa mínima (s)
    session_pause_max = 120,   -- pausa máxima (s)
    hook_observe_time = 10,    -- segundos de hook passivo
    test_timeout     = 2,      -- timeout do teste ativo (s)
    max_args_tests   = 2,      -- máximo de tentativas de args por remote
    backoff_cap      = 60,     -- cap do backoff (s)
    spin_keywords    = {"spin","lucky","giro","sorte","weapon","roll","case","crate","reward"},
}

-- ============================================================
-- ANTI-BAN: jitter, backoff, sessão
-- ============================================================
local AntiBan = {}
AntiBan.__index = AntiBan

function AntiBan.new()
    return setmetatable({
        consecutive_errors = 0,
        spins_this_session = 0,
        total_spins = 0,
        total_ok = 0,
        total_err = 0,
        blacklist = {},
        running = false,
    }, AntiBan)
end

function AntiBan:jitter(base)
    local v = base * (0.6 + math.random() * 0.8) -- ±40%
    return math.max(0.2, v)
end

function AntiBan:on_success()
    self.consecutive_errors = 0
    self.total_ok = self.total_ok + 1
end

function AntiBan:on_error()
    self.consecutive_errors = self.consecutive_errors + 1
    self.total_err = self.total_err + 1
    local mult = math.min(2 ^ self.consecutive_errors, self.backoff_cap / CONFIG.base_interval)
    return CONFIG.base_interval * mult
end

function AntiBan:needs_session_pause()
    return self.spins_this_session >= CONFIG.spins_per_session
end

function AntiBan:session_pause()
    local t = CONFIG.session_pause_min + math.random() * (CONFIG.session_pause_max - CONFIG.session_pause_min)
    self.spins_this_session = 0
    task.wait(t)
end

function AntiBan:is_blacklisted(name)
    return self.blacklist[name] == true
end

function AntiBan:blacklist_remote(name)
    self.blacklist[name] = true
end

-- ============================================================
-- UI (preto e branco)
-- ============================================================
local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "kota_ui"
    self.gui.ResetOnSpawn = false
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if syn and syn.protect_gui then syn.protect_gui(self.gui) end
    if gethui then self.gui.Parent = gethui() else self.gui.Parent = game:GetService("CoreGui") end

    local main = Instance.new("Frame")
    main.Name = "main"
    main.Size = UDim2.new(0, 420, 0, 520)
    main.Position = UDim2.new(0.02, 0, 0.1, 0)
    main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = self.gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(31, 31, 31)
    stroke.Thickness = 1
    stroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Name = "title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    title.Text = "kota"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.Code
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.PaddingLeft = UDim.new(0, 12)
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Name = "close"
    close.Size = UDim2.new(0, 32, 0, 32)
    close.Position = UDim2.new(1, -40, 0, 4)
    close.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    close.Text = "×"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.Code
    close.TextSize = 18
    close.Parent = main
    close.MouseButton1Click:Connect(function() self.gui:Destroy() end)

    local status = Instance.new("TextLabel")
    status.Name = "status"
    status.Size = UDim2.new(1, -24, 0, 24)
    status.Position = UDim2.new(0, 12, 0, 44)
    status.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    status.Text = "idle — not scanning"
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Font = Enum.Font.Code
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = main

    local log = Instance.new("ScrollingFrame")
    log.Name = "log"
    log.Size = UDim2.new(1, -24, 0, 220)
    log.Position = UDim2.new(0, 12, 0, 72)
    log.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    log.BorderSizePixel = 0
    log.ScrollBarThickness = 4
    log.CanvasSize = UDim2.new(0, 0, 0, 0)
    log.AutomaticCanvasSize = Enum.AutomaticSize.Y
    log.Parent = main

    local log_layout = Instance.new("UIListLayout")
    log_layout.Padding = UDim.new(0, 2)
    log_layout.Parent = log

    local log_pad = Instance.new("UIPadding")
    log_pad.PaddingLeft = UDim.new(0, 6)
    log_pad.PaddingTop = UDim.new(0, 4)
    log_pad.Parent = log

    local counter = Instance.new("TextLabel")
    counter.Name = "counter"
    counter.Size = UDim2.new(1, -24, 0, 24)
    counter.Position = UDim2.new(0, 12, 0, 300)
    counter.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    counter.Text = "spins: 0  ok: 0  err: 0"
    counter.TextColor3 = Color3.fromRGB(200, 200, 200)
    counter.Font = Enum.Font.Code
    counter.TextSize = 12
    counter.TextXAlignment = Enum.TextXAlignment.Left
    counter.Parent = main

    local interval_label = Instance.new("TextLabel")
    interval_label.Size = UDim2.new(0, 90, 0, 24)
    interval_label.Position = UDim2.new(0, 12, 0, 332)
    interval_label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    interval_label.Text = "interval (s)"
    interval_label.TextColor3 = Color3.fromRGB(160, 160, 160)
    interval_label.Font = Enum.Font.Code
    interval_label.TextSize = 11
    interval_label.TextXAlignment = Enum.TextXAlignment.Left
    interval_label.Parent = main

    local interval = Instance.new("TextBox")
    interval.Name = "interval"
    interval.Size = UDim2.new(0, 80, 0, 24)
    interval.Position = UDim2.new(0, 110, 0, 332)
    interval.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    interval.BorderSizePixel = 1
    interval.BorderColor3 = Color3.fromRGB(31, 31, 31)
    interval.Text = tostring(CONFIG.base_interval)
    interval.TextColor3 = Color3.fromRGB(255, 255, 255)
    interval.Font = Enum.Font.Code
    interval.TextSize = 12
    interval.Parent = main

    local session_label = Instance.new("TextLabel")
    session_label.Size = UDim2.new(0, 110, 0, 24)
    session_label.Position = UDim2.new(0, 200, 0, 332)
    session_label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    session_label.Text = "spins/session"
    session_label.TextColor3 = Color3.fromRGB(160, 160, 160)
    session_label.Font = Enum.Font.Code
    session_label.TextSize = 11
    session_label.TextXAlignment = Enum.TextXAlignment.Left
    session_label.Parent = main

    local session = Instance.new("TextBox")
    session.Name = "session"
    session.Size = UDim2.new(0, 60, 0, 24)
    session.Position = UDim2.new(0, 312, 0, 332)
    session.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    session.BorderSizePixel = 1
    session.BorderColor3 = Color3.fromRGB(31, 31, 31)
    session.Text = tostring(CONFIG.spins_per_session)
    session.TextColor3 = Color3.fromRGB(255, 255, 255)
    session.Font = Enum.Font.Code
    session.TextSize = 12
    session.Parent = main

    local scan = Instance.new("TextButton")
    scan.Name = "scan"
    scan.Size = UDim2.new(0, 180, 0, 36)
    scan.Position = UDim2.new(0, 12, 0, 372)
    scan.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    scan.Text = "SCAN"
    scan.TextColor3 = Color3.fromRGB(255, 255, 255)
    scan.Font = Enum.Font.Code
    scan.TextSize = 14
    scan.Parent = main

    local auto = Instance.new("TextButton")
    auto.Name = "auto"
    auto.Size = UDim2.new(0, 180, 0, 36)
    auto.Position = UDim2.new(0, 204, 0, 372)
    auto.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    auto.Text = "AUTO SPIN: OFF"
    auto.TextColor3 = Color3.fromRGB(255, 255, 255)
    auto.Font = Enum.Font.Code
    auto.TextSize = 14
    auto.Parent = main

    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, -24, 0, 20)
    footer.Position = UDim2.new(0, 12, 1, -24)
    footer.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    footer.Text = "kota — low-footprint automation"
    footer.TextColor3 = Color3.fromRGB(80, 80, 80)
    footer.Font = Enum.Font.Code
    footer.TextSize = 10
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.Parent = main

    self.main = main
    self.log = log
    self.log_layout = log_layout
    self.status = status
    self.counter = counter
    self.interval = interval
    self.session = session
    self.scan_btn = scan
    self.auto_btn = auto
    return self
end

function UI:add_log(text, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = self.log
    
    -- limpar o primeiro TextLabel se passar do limite (ignora Layout/Padding)
    local text_labels = {}
    for _, child in ipairs(self.log:GetChildren()) do
        if child:IsA("TextLabel") then
            table.insert(text_labels, child)
        end
    end
    if #text_labels > 100 then
        text_labels[1]:Destroy()
    end
end

function UI:set_status(text, color)
    self.status.Text = text
    self.status.TextColor3 = color or Color3.fromRGB(180, 180, 180)
end

function UI:update_counter(ab)
    self.counter.Text = string.format("spins: %d  ok: %d  err: %d", ab.total_spins, ab.total_ok, ab.total_err)
end

-- ============================================================
-- SCANNER (camadas 1-5)
-- ============================================================
local Scanner = {}
Scanner.__index = Scanner

local function has_keyword(s)
    if type(s) ~= "string" then return false end
    local low = s:lower()
    for _, kw in ipairs(CONFIG.spin_keywords) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

function Scanner.new(ui, antiban)
    return setmetatable({
        ui = ui,
        antiban = antiban,
        candidates = {},
        captured_args = nil,
        captured_remote = nil,
        captured_prompt = nil,
    }, Scanner)
end

-- camada 1: passiva
function Scanner:layer1_passive()
    self.ui:add_log("[L1] passive scan...", Color3.fromRGB(120, 200, 120))
    local roots = {game:GetService("ReplicatedStorage"), game:GetService("Workspace")}
    local ok_pg, pg = pcall(function() return game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") end)
    if ok_pg and pg then table.insert(roots, pg) end

    local count = 0
    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
                if has_keyword(obj.Name) then
                    count = count + 1
                    table.insert(self.candidates, {name = obj.Name, obj = obj, type = obj.ClassName, layer = 1})
                    self.ui:add_log("[L1] " .. obj.ClassName .. ": " .. obj:GetFullName(), Color3.fromRGB(255, 255, 255))
                end
            elseif obj:IsA("StringValue") or obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if has_keyword(obj.Name) then
                    table.insert(self.candidates, {name = obj.Name, obj = obj, type = obj.ClassName, layer = 1})
                end
            elseif obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                if has_keyword(obj.Name) or (obj.Parent and has_keyword(obj.Parent.Name)) then
                    count = count + 1
                    table.insert(self.candidates, {name = obj.Name, obj = obj, type = obj.ClassName, layer = 1})
                    self.ui:add_log("[L1] " .. obj.ClassName .. ": " .. obj:GetFullName(), Color3.fromRGB(255, 255, 255))
                end
            end
        end
    end
    self.ui:add_log("[L1] found " .. count .. " candidates", Color3.fromRGB(120, 200, 120))
    return count
end

-- camada 2: getgc/getreg
function Scanner:layer2_gc()
    self.ui:add_log("[L2] gc/reg scan...", Color3.fromRGB(120, 200, 120))
    local count = 0

    if getgc then
        local ok, gc = pcall(function() return getgc(true) end)
        if ok and type(gc) == "table" then
            for _, obj in pairs(gc) do
                if type(obj) == "table" then
                    pcall(function()
                        for k, v in pairs(obj) do
                            if type(k) == "string" and has_keyword(k) then
                                count = count + 1
                                table.insert(self.candidates, {name = k, obj = v, type = "gc_table", layer = 2})
                                if count <= 5 then self.ui:add_log("[L2] gc key: " .. k, Color3.fromRGB(255, 255, 255)) end
                            end
                        end
                    end)
                end
            end
        end
    else
        self.ui:add_log("[L2] getgc not available — skip", Color3.fromRGB(200, 160, 80))
    end

    if getreg then
        local ok, reg = pcall(function() return getreg() end)
        if ok and type(reg) == "table" then
            for _, fn in pairs(reg) do
                local ok2, info = pcall(debug.getinfo, fn)
                if ok2 and info and info.name and has_keyword(info.name) then
                    count = count + 1
                    table.insert(self.candidates, {name = info.name, obj = fn, type = "registry_fn", layer = 2})
                end
            end
        end
    else
        self.ui:add_log("[L2] getreg not available — skip", Color3.fromRGB(200, 160, 80))
    end

    self.ui:add_log("[L2] found " .. count .. " from gc/reg", Color3.fromRGB(120, 200, 120))
    return count
end

-- camada 3: bytecode
function Scanner:layer3_bytecode()
    self.ui:add_log("[L3] bytecode scan...", Color3.fromRGB(120, 200, 120))
    local count = 0
    if not getscriptbytecode then
        self.ui:add_log("[L3] getscriptbytecode not available — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end
    local roots = {game:GetService("ReplicatedStorage")}
    local ok_pg, pg = pcall(function() return game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") end)
    if ok_pg and pg then table.insert(roots, pg) end

    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                local ok, bc = pcall(getscriptbytecode, obj)
                if ok and type(bc) == "string" then
                    for _, kw in ipairs(CONFIG.spin_keywords) do
                        if bc:lower():find(kw, 1, true) then
                            count = count + 1
                            table.insert(self.candidates, {name = obj:GetFullName(), obj = obj, type = "bytecode_ref", layer = 3, keyword = kw})
                            self.ui:add_log("[L3] ref '" .. kw .. "' in " .. obj:GetFullName(), Color3.fromRGB(255, 255, 255))
                            break
                        end
                    end
                end
            end
        end
    end
    self.ui:add_log("[L3] found " .. count .. " bytecode refs", Color3.fromRGB(120, 200, 120))
    return count
end

-- camada 4: hook passivo
function Scanner:layer4_hook_passive()
    self.ui:add_log("[L4] passive hook (" .. CONFIG.hook_observe_time .. "s)...", Color3.fromRGB(120, 200, 120))
    if not hookmetamethod or not getnamecallmethod then
        self.ui:add_log("[L4] hookmetamethod not available — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end
    local captured = {}
    local real_namecall
    local ok = pcall(function()
        real_namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local ok_n, name = pcall(function() return self.Name end)
                if ok_n and has_keyword(name) then
                    captured[name] = {remote = self, method = method, args = {...}}
                end
            end
            return real_namecall(self, ...)
        end)
    end)
    if not ok then
        self.ui:add_log("[L4] hook failed — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end

    task.wait(CONFIG.hook_observe_time)

    pcall(function() hookmetamethod(game, "__namecall", real_namecall) end)

    local count = 0
    for name, info in pairs(captured) do
        count = count + 1
        table.insert(self.candidates, {name = name, obj = info.remote, type = "hooked_remote", layer = 4, args = info.args, method = info.method})
        self.ui:add_log("[L4] captured: " .. name .. " (" .. info.method .. ")", Color3.fromRGB(255, 255, 255))
    end
    self.ui:add_log("[L4] captured " .. count .. " remotes", Color3.fromRGB(120, 200, 120))
    return count
end

-- camada 5: teste ativo controlado (CORRIGIDO)
function Scanner:layer5_active_test()
    self.ui:add_log("[L5] active test...", Color3.fromRGB(120, 200, 120))
    local ordered = {}
    for _, c in ipairs(self.candidates) do
        if c.layer == 4 or c.layer == 2 then table.insert(ordered, c) end
    end
    for _, c in ipairs(self.candidates) do
        if c.layer == 1 or c.layer == 3 then table.insert(ordered, c) end
    end

    for _, c in ipairs(ordered) do
        if self.antiban:is_blacklisted(c.name) then
            self.ui:add_log("[L5] skip blacklisted: " .. c.name, Color3.fromRGB(200, 160, 80))
        elseif (c.type == "hooked_remote" or c.type == "RemoteEvent") and c.obj then
            local ok, err = pcall(function()
                if c.method == "InvokeServer" then
                    c.obj:InvokeServer(table.unpack(c.args or {}))
                else
                    c.obj:FireServer(table.unpack(c.args or {}))
                end
            end)
            if ok then
                self.captured_remote = c.obj
                self.captured_args = c.args or {}
                self.ui:add_log("[L5] SUCCESS (Remote): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
                self.ui:add_log("[L5] fail/blacklist: " .. c.name, Color3.fromRGB(255, 120, 120))
            end
        elseif (c.type == "ProximityPrompt" or c.type == "ClickDetector") and c.obj then
            local ok = pcall(function()
                if c.type == "ProximityPrompt" then
                    fireproximityprompt(c.obj)
                else
                    c.obj:FireServer()
                end
            end)
            if ok then
                self.captured_prompt = c.obj
                self.ui:add_log("[L5] SUCCESS (Prompt): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
                self.ui:add_log("[L5] fail/blacklist: " .. c.name, Color3.fromRGB(255, 120, 120))
            end
        end
    end

    self.ui:add_log("[L5] no remote confirmed", Color3.fromRGB(255, 120, 120))
    return false
end

function Scanner:run_all()
    self.candidates = {}
    self:layer1_passive()
    self:layer2_gc()
    self:layer3_bytecode()
    self:layer4_hook_passive()
    local ok = self:layer5_active_test()
    self.ui:add_log("scan done — " .. #self.candidates .. " total candidates", Color3.fromRGB(120, 200, 120))
    return ok
end

-- ============================================================
-- EXECUTOR (loop de spin)
-- ============================================================
local Executor = {}
Executor.__index = Executor

function Executor.new(ui, antiban, scanner)
    return setmetatable({
        ui = ui,
        antiban = antiban,
        scanner = scanner,
        active = false,
        thread = nil,
    }, Executor)
end

function Executor:start()
    if self.active then return end
    if not self.scanner.captured_remote and not self.scanner.captured_prompt then
        self.ui:add_log("no target — scan first", Color3.fromRGB(255, 120, 120))
        return
    end
    self.active = true
    self.ui:set_status("auto spin: ON", Color3.fromRGB(120, 255, 120))
    self.thread = task.spawn(function()
        while self.active do
            local ok, err = pcall(function()
                if self.scanner.captured_remote then
                    local remote = self.scanner.captured_remote
                    local args = self.scanner.captured_args or {}
                    remote:FireServer(table.unpack(args))
                elseif self.scanner.captured_prompt then
                    if self.scanner.captured_prompt:IsA("ProximityPrompt") then
                        fireproximityprompt(self.scanner.captured_prompt)
                    else
                        self.scanner.captured_prompt:FireServer()
                    end
                end
            end)
            
            self.antiban.total_spins = self.antiban.total_spins + 1
            self.antiban.spins_this_session = self.antiban.spins_this_session + 1
            if ok then
                self.antiban:on_success()
            else
                local backoff = self.antiban:on_error()
                self.ui:add_log("spin err: " .. tostring(err), Color3.fromRGB(255, 120, 120))
                task.wait(backoff)
            end
            self.ui:update_counter(self.antiban)
            if self.antiban:needs_session_pause() then
                self.ui:set_status("session pause...", Color3.fromRGB(200, 160, 80))
                self.antiban:session_pause()
                self.ui:set_status("auto spin: ON", Color3.fromRGB(120, 255, 120))
            end
            task.wait(self.antiban:jitter(CONFIG.base_interval))
        end
    end)
end

function Executor:stop()
    self.active = false
    self.ui:set_status("auto spin: OFF", Color3.fromRGB(180, 180, 180))
end

-- ============================================================
-- BOOT
-- ============================================================
local antiban = AntiBan.new()
local ui = UI.new()
antiban.ui = ui

local scanner = Scanner.new(ui, antiban)
local executor = Executor.new(ui, antiban, scanner)

ui.scan_btn.MouseButton1Click:Connect(function()
    if scanner.captured_remote or scanner.captured_prompt then
        ui:add_log("already have target — rescan anyway", Color3.fromRGB(200, 160, 80))
    end
    ui:set_status("scanning...", Color3.fromRGB(200, 160, 80))
    task.spawn(function()
        local ok = scanner:run_all()
        if ok then
            ui:set_status("target ready", Color3.fromRGB(120, 255, 120))
            ui:add_log("ready — press AUTO SPIN", Color3.fromRGB(120, 255, 120))
        else
            ui:set_status("no target found", Color3.fromRGB(255, 120, 120))
        end
    end)
end)

ui.auto_btn.MouseButton1Click:Connect(function()
    if executor.active then
        executor:stop()
        ui.auto_btn.Text = "AUTO SPIN: OFF"
    else
        executor:start()
        if executor.active then
            ui.auto_btn.Text = "AUTO SPIN: ON"
        end
    end
end)

ui.interval.FocusLost:Connect(function()
    local n = tonumber(ui.interval.Text)
    if n and n >= 0.3 then CONFIG.base_interval = n end
    ui.interval.Text = tostring(CONFIG.base_interval)
end)

ui.session.FocusLost:Connect(function()
    local n = tonumber(ui.session.Text)
    if n and n >= 5 then CONFIG.spins_per_session = n end
    ui.session.Text = tostring(CONFIG.spins_per_session)
end)

ui:add_log("kota loaded", Color3.fromRGB(255, 255, 255))
ui:add_log("press SCAN to discover spin target", Color3.fromRGB(180, 180, 180))
