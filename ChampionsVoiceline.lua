local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local getasset = getcustomasset or getsynasset

-- ==========================================
-- CONFIGURACIÓN GLOBAL Y PALETA DE COLORES
-- ==========================================
local SAVE_FILE = "OmegaVoicelines_V6.json"
local VolumeData = {}
local VoicelinesActivas = true
local VfxActivos = true

-- URLs de emblema estrella y raya de energía
local STAR_EMBLEM_URL = "https://i.postimg.cc/brck1DN4/1000331975-Photoroom.png"
local ENERGY_BEAM_URL = "https://i.postimg.cc/Y2RQv9wp/1000331989-Photoroom.png"

-- Valores por defecto y estado de posición/tamaño de la raya
local DEFAULT_BEAM_POS_X = 0.6375
local DEFAULT_BEAM_POS_Y = 0.8600
local DEFAULT_BEAM_SIZE_X = 0.6850
local DEFAULT_BEAM_SIZE_Y = 0.8500

local BeamPosX = DEFAULT_BEAM_POS_X
local BeamPosY = DEFAULT_BEAM_POS_Y
local BeamSizeX = DEFAULT_BEAM_SIZE_X
local BeamSizeY = DEFAULT_BEAM_SIZE_Y

-- Colores para el borde luminoso, puntos y texto (Celeste bajito, Rojo y Violeta cristalino)
local COLOR_CELESTE = Color3.fromRGB(142, 228, 255) -- Celeste bajito
local COLOR_ROJO    = Color3.fromRGB(240, 36, 56)   -- Rojo intenso
local COLOR_VIOLETA = Color3.fromRGB(185, 125, 255) -- Violeta cristalino luminoso

-- Colores translúcidos profundos para el interior estilo Force Shield
local SHIELD_DEEP_CYAN = Color3.fromRGB(12, 36, 62)
local SHIELD_MID_BLUE  = Color3.fromRGB(24, 68, 102)
local SHIELD_CRIMSON   = Color3.fromRGB(58, 14, 30)
local SHIELD_SEPARATOR = Color3.fromRGB(22, 56, 110)  -- Separador en azul zafiro profundo

local GLOBAL_PALETTE = {COLOR_CELESTE, COLOR_ROJO, COLOR_VIOLETA}

-- ==========================================
-- CARGADOR SEGURO DE IMÁGENES (MÉTODO V23.5 SAFE)
-- ==========================================
local loadedImageCache = {}

local function isValidImageBody(body)
    if type(body) ~= "string" or #body < 500 then
        return false
    end
    local head = body:sub(1, 32):lower()
    if head:find("<html") or head:find("<!doctype") then
        return false
    end
    return true
end

local function applySafeWebImage(imageLabel, url, fileName)
    if not imageLabel then return end

    if loadedImageCache[fileName] then
        pcall(function()
            imageLabel.Image = loadedImageCache[fileName]
        end)
        return
    end

    task.spawn(function()
        local assetPath = nil

        pcall(function()
            if isfile and isfile(fileName) and readfile and getasset then
                local existingData = readfile(fileName)
                if isValidImageBody(existingData) then
                    assetPath = getasset(fileName)
                end
            end
        end)

        if not assetPath then
            local success = false
            local reqHeaders = {["User-Agent"] = "Mozilla/5.0"}

            pcall(function()
                if http_request and writefile and getasset then
                    local res = http_request({Url = url, Method = "GET", Headers = reqHeaders})
                    if res and isValidImageBody(res.Body) then
                        writefile(fileName, res.Body)
                        assetPath = getasset(fileName)
                        success = true
                    end
                end
            end)

            if not success then
                pcall(function()
                    if syn and syn.request and writefile and getasset then
                        local res = syn.request({Url = url, Method = "GET", Headers = reqHeaders})
                        if res and isValidImageBody(res.Body) then
                            writefile(fileName, res.Body)
                            assetPath = getasset(fileName)
                            success = true
                        end
                    end
                end)
            end

            if not success then
                pcall(function()
                    if request and writefile and getasset then
                        local res = request({Url = url, Method = "GET", Headers = reqHeaders})
                        if res and isValidImageBody(res.Body) then
                            writefile(fileName, res.Body)
                            assetPath = getasset(fileName)
                            success = true
                        end
                    end
                end)
            end

            if not success then
                pcall(function()
                    if writefile and getasset then
                        local body = game:HttpGet(url)
                        if isValidImageBody(body) then
                            writefile(fileName, body)
                            assetPath = getasset(fileName)
                            success = true
                        end
                    end
                end)
            end
        end

        if assetPath then
            loadedImageCache[fileName] = assetPath
            pcall(function()
                if imageLabel and imageLabel.Parent then
                    imageLabel.Image = assetPath
                end
            end)
        end
    end)
end

-- Estado personalizado del interior del globo (persistente)
local CustomGlobeHex = nil
local CustomGlobeName = "Color Personalizado"
local CustomGlobeColor = nil
local SavedGlobeColors = {}

local function parseHexColor(hexStr)
    if type(hexStr) ~= "string" then return nil, nil end
    local cleaned = hexStr:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^#", "")
    if #cleaned == 3 then
        cleaned = cleaned:sub(1, 1):rep(2) .. cleaned:sub(2, 2):rep(2) .. cleaned:sub(3, 3):rep(2)
    end
    if #cleaned ~= 6 or not cleaned:match("^[0-9a-fA-F]+$") then
        return nil, nil
    end
    local r = tonumber(cleaned:sub(1, 2), 16)
    local g = tonumber(cleaned:sub(3, 4), 16)
    local b = tonumber(cleaned:sub(5, 6), 16)
    return Color3.fromRGB(r, g, b), "#" .. cleaned:upper()
end

local function getDefaultInnerColorSequence()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, SHIELD_DEEP_CYAN),
        ColorSequenceKeypoint.new(0.35, SHIELD_MID_BLUE),
        ColorSequenceKeypoint.new(0.68, SHIELD_CRIMSON),
        ColorSequenceKeypoint.new(1.00, SHIELD_DEEP_CYAN)
    })
end

local function applyInnerColorToLayer(innerLayer)
    if innerLayer then
        local innerGrad = innerLayer:FindFirstChild("InnerGrad")
        if CustomGlobeColor then
            if innerGrad then
                innerGrad.Enabled = false
            end
            for _, child in ipairs(innerLayer:GetChildren()) do
                if child:IsA("Frame") then
                    child.BackgroundColor3 = CustomGlobeColor
                end
            end
        else
            if innerGrad then
                innerGrad.Color = getDefaultInnerColorSequence()
                innerGrad.Enabled = true
            end
            for _, child in ipairs(innerLayer:GetChildren()) do
                if child:IsA("Frame") then
                    child.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end
end

-- ==========================================
-- DETECCIÓN DE SPIDER-MAN DEFAULT (PARA MUERTE / RESET)
-- ==========================================
local function getSpideyDefaultModel()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local chars = assets and assets:FindFirstChild("Characters")
    local spidey = chars and chars:FindFirstChild("Spider-Man")
    return spidey and spidey:FindFirstChild("Default")
end

local function isSpiderManDefault(char)
    if not char then return false end
    local defaultModel = getSpideyDefaultModel()

    if defaultModel then
        for _, obj in ipairs(player:GetDescendants()) do
            if obj:IsA("ObjectValue") and obj.Value == defaultModel then
                return true
            end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("ObjectValue") and obj.Value == defaultModel then
                return true
            end
        end
    end

    local charAttr = char:GetAttribute("Character") or char:GetAttribute("CharacterName") or char:GetAttribute("Hero")
    local skinAttr = char:GetAttribute("Skin") or char:GetAttribute("Form") or char:GetAttribute("Variant")
    if type(charAttr) == "string" and charAttr:lower():find("spider") then
        if skinAttr == nil or tostring(skinAttr):lower() == "default" or tostring(skinAttr) == "" then
            return true
        end
    end

    if defaultModel then
        local refShirt = defaultModel:FindFirstChildOfClass("Shirt")
        local refPants = defaultModel:FindFirstChildOfClass("Pants")
        local charShirt = char:FindFirstChildOfClass("Shirt")
        local charPants = char:FindFirstChildOfClass("Pants")

        if refShirt and refPants and charShirt and charPants then
            if refShirt.ShirtTemplate ~= "" and charShirt.ShirtTemplate == refShirt.ShirtTemplate
                and refPants.PantsTemplate ~= "" and charPants.PantsTemplate == refPants.PantsTemplate then
                return true
            end
        end

        local refMeshes = {}
        local countRef = 0
        for _, d in ipairs(defaultModel:GetDescendants()) do
            if (d:IsA("SpecialMesh") or d:IsA("MeshPart")) and d.MeshId ~= "" then
                refMeshes[d.MeshId] = true
                countRef = countRef + 1
            end
        end

        if countRef > 0 then
            local matches = 0
            for _, d in ipairs(char:GetDescendants()) do
                if (d:IsA("SpecialMesh") or d:IsA("MeshPart")) and refMeshes[d.MeshId] then
                    matches = matches + 1
                end
            end
            if matches >= math.max(1, math.floor(countRef * 0.6)) then
                return true
            end
        end
    end

    return false
end

-- ==========================================
-- VOICELINES DE SPIDER-MAN
-- ==========================================
local STOP_SONG_ANIM = "105976246289294"

local SONG_DATA = {
    key = "Cancion", type = "url",
    src = "https://github.com/billierxz/Champions-rise-Vcs/blob/c75b87b155db10d3579ce95d906baa5df51deb53/mix_Bad_Bunny___EoO__Video_Lyrics__1080P_HD_.mp3",
    defVol = 5, cd = 1.5, hero = "Spider-Man", order = 6,
    isSong = true,
    fade = true,
    stopAnimId = STOP_SONG_ANIM,
    vfxType = "random",
    quote = "🎧"
}

local DEATH_VOICELINE = {
    key = "Death (Im Okay)", type = "url",
    src = "https://github.com/billierxz/Champions-rise-Vcs/blob/94052a84f7ee0889465961679bec76cddaa32569/separated_vocal_im_ek_fix__FA95189_.mp3",
    defVol = 6.5, cd = 1, hero = "Spider-Man", order = 7,
    vfxType = "death",
    isSadDeath = true,
    quote = "im okay im okay"
}

local TRACKED = {
    ["126744091497158"] = {
        key = "Spider Trap", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/7206d4f1a6c0fab3aa364820af50e62123e199ee/separated_vocal_laugh__505D0B6_.mp3",
        nextSrc = "https://github.com/billierxz/Champions-rise-Vcs/blob/4cb1a0ed1efa85097ace32922dff72020cf56191/separated_vocal_im_in_control_bubby__350370B_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 2,
        vfxType = "response",
        quote = "Hahah",
        nextQuote = "Im in control bubby"
    },
    ["114696600161120"] = {
        key = "Spider Trap Mass", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/8d641f30a8fb6bfe825c4dc001eb3344631a2cb4/separated_vocal_you_can_t_trick_me_anymore__6E3008F_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 3,
        vfxType = "damage",
        quote = "You can't trick me anymore."
    },
    ["110771864835896"] = {
        key = "Spider Stun Bring", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/441db525530eadbf74fea5b445d3084de39e6daa/separated_vocal_you_ready____11D2A6A_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 4,
        vfxType = "response",
        quote = "You ready?"
    },
    ["99079784262381"] = {
        key = "Spider Kick", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/d248b52cd145be82101c4553ca55b5d551701f4f/separated_vocal_im_both__9ED1F80_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 5,
        vfxType = "damage",
        quote = "Im both."
    },
    ["117318923209438"] = SONG_DATA,
    ["81821563682239"]  = SONG_DATA
}

local SOUND_TRACKED = {
    ["71182782447096"] = {
        key = "Spider Sense", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/609257568b3adafa6e7265f4f634e64fef40c4a4/mix_sense__CE9A314_.mp3",
        primaryVolFactor = 1.25,
        extraUrl = "https://github.com/billierxz/Champions-rise-Vcs/blob/9a1fc7e4e3610d083c28806846c8687f06bfb329/separated_vocal_give_a_sec__74333BB_.mp3",
        extraVolFactor = 0.78,
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 1,
        replaceSoundId = "71182782447096",
        vfxType = "response",
        quote = "Alright, just give a sec",
        afterDelayQuote = "...",
        afterDelayTime = 3
    }
}

if isfile and isfile(SAVE_FILE) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(SAVE_FILE))
        if type(decoded) == "table" then
            VolumeData = decoded
            if VolumeData._vfxEnabled ~= nil then
                VfxActivos = VolumeData._vfxEnabled
            end
            if type(VolumeData._globeInnerHex) == "string" then
                local col, norm = parseHexColor(VolumeData._globeInnerHex)
                if col then
                    CustomGlobeColor = col
                    CustomGlobeHex = norm
                end
            end
            if type(VolumeData._globeInnerName) == "string" and VolumeData._globeInnerName ~= "" then
                CustomGlobeName = VolumeData._globeInnerName
            end
            if type(VolumeData._savedGlobeColors) == "table" then
                SavedGlobeColors = VolumeData._savedGlobeColors
            end
            if type(VolumeData._beamConfig) == "table" then
                if type(VolumeData._beamConfig.px) == "number" then BeamPosX = VolumeData._beamConfig.px end
                if type(VolumeData._beamConfig.py) == "number" then BeamPosY = VolumeData._beamConfig.py end
                if type(VolumeData._beamConfig.sx) == "number" then BeamSizeX = VolumeData._beamConfig.sx end
                if type(VolumeData._beamConfig.sy) == "number" then BeamSizeY = VolumeData._beamConfig.sy end
            end
        end
    end)
end

local function saveConfig()
    VolumeData._vfxEnabled = VfxActivos
    VolumeData._globeInnerHex = CustomGlobeHex
    VolumeData._globeInnerName = CustomGlobeName
    VolumeData._savedGlobeColors = SavedGlobeColors
    VolumeData._beamConfig = {
        px = BeamPosX,
        py = BeamPosY,
        sx = BeamSizeX,
        sy = BeamSizeY
    }
    if writefile then
        pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(VolumeData)) end)
    end
end

-- ==========================================
-- SISTEMA DE NUBE FORCE-SHIELD + ESTRELLA Y RAYA LIMPIAS + SEPARACIÓN
-- ==========================================
local activeBillboards = {}
local activeCaptionLoops = {}
local charBillboards = setmetatable({}, {__mode = "k"})

local function applyBeamTransformToAll()
    local newPos = UDim2.new(BeamPosX, 0, BeamPosY, 0)
    local newSize = UDim2.new(BeamSizeX, 0, BeamSizeY, 0)

    for _, bb in pairs(charBillboards) do
        if bb and bb.Parent then
            local cloudRoot = bb:FindFirstChild("CloudRoot")
            local headerSig = cloudRoot and cloudRoot:FindFirstChild("HeaderSignature")
            local underlineBeam = headerSig and headerSig:FindFirstChild("UnderlineBeam")
            if underlineBeam then
                underlineBeam.Position = newPos
                underlineBeam.Size = newSize
            end
        end
    end

    local playerGui = player:FindFirstChild("PlayerGui")
    local directBb = playerGui and playerGui:FindFirstChild("NewFenderForceShieldBB")
    if directBb then
        local cloudRoot = directBb:FindFirstChild("CloudRoot")
        local headerSig = cloudRoot and cloudRoot:FindFirstChild("HeaderSignature")
        local underlineBeam = headerSig and headerSig:FindFirstChild("UnderlineBeam")
        if underlineBeam then
            underlineBeam.Position = newPos
            underlineBeam.Size = newSize
        end
    end
end

local LOBE_SPECS = {
    {x = 0.31, y = 0.35, w = 0.23, h = 0.32, side = -1},
    {x = 0.45, y = 0.24, w = 0.28, h = 0.36, side = -1},
    {x = 0.62, y = 0.23, w = 0.30, h = 0.38, side = 1},
    {x = 0.79, y = 0.31, w = 0.26, h = 0.35, side = 1},
    {x = 0.83, y = 0.46, w = 0.24, h = 0.33, side = 1},
    {x = 0.69, y = 0.53, w = 0.30, h = 0.34, side = 1},
    {x = 0.49, y = 0.54, w = 0.29, h = 0.34, side = -1},
    {x = 0.34, y = 0.47, w = 0.24, h = 0.31, side = -1}
}

local DRIP_SPECS = {
    {x = 0.42, y = 0.625, w = 0.020, baseH = 0.072, dropColor = COLOR_ROJO,    side = -1},
    {x = 0.50, y = 0.645, w = 0.024, baseH = 0.112, dropColor = COLOR_VIOLETA, side = -1},
    {x = 0.58, y = 0.650, w = 0.026, baseH = 0.132, dropColor = COLOR_ROJO,    side = 1},
    {x = 0.66, y = 0.642, w = 0.022, baseH = 0.105, dropColor = COLOR_CELESTE, side = 1},
    {x = 0.74, y = 0.622, w = 0.019, baseH = 0.068, dropColor = COLOR_ROJO,    side = 1}
}

local function resetBubbleGeometry(cloudRoot)
    if not cloudRoot then return end
    local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
    if shieldGroup then
        local borderLayer = shieldGroup:FindFirstChild("BorderLayer")
        local separatorLayer = shieldGroup:FindFirstChild("SeparatorLayer")
        local innerLayer = shieldGroup:FindFirstChild("InnerLayer")

        for i, sp in ipairs(LOBE_SPECS) do
            local outerLobe = borderLayer and borderLayer:FindFirstChild("OuterLobe_" .. i)
            local sepLobe = separatorLayer and separatorLayer:FindFirstChild("SepLobe_" .. i)
            local innerLobe = innerLayer and innerLayer:FindFirstChild("InnerLobe_" .. i)
            if outerLobe then outerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
            if sepLobe then sepLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
            if innerLobe then innerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
        end

        for i, d in ipairs(DRIP_SPECS) do
            local collarOut = borderLayer and borderLayer:FindFirstChild("DripCollarOut_" .. i)
            local taperOut = borderLayer and borderLayer:FindFirstChild("DripTaperOut_" .. i)
            local neckOut = borderLayer and borderLayer:FindFirstChild("DripNeckOut_" .. i)
            local bulbOut = borderLayer and borderLayer:FindFirstChild("DripBulbOut_" .. i)
            if collarOut then collarOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperOut then taperOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckOut then neckOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbOut then bulbOut.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end

            local collarSep = separatorLayer and separatorLayer:FindFirstChild("DripCollarSep_" .. i)
            local taperSep = separatorLayer and separatorLayer:FindFirstChild("DripTaperSep_" .. i)
            local neckSep = separatorLayer and separatorLayer:FindFirstChild("DripNeckSep_" .. i)
            local bulbSep = separatorLayer and separatorLayer:FindFirstChild("DripBulbSep_" .. i)
            if collarSep then collarSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperSep then taperSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckSep then neckSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbSep then bulbSep.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end

            local collarIn = innerLayer and innerLayer:FindFirstChild("DripCollarIn_" .. i)
            local taperIn = innerLayer and innerLayer:FindFirstChild("DripTaperIn_" .. i)
            local neckIn = innerLayer and innerLayer:FindFirstChild("DripNeckIn_" .. i)
            local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. i)
            if collarIn then collarIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperIn then taperIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckIn then neckIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbIn then bulbIn.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end
        end

        local centerCore = innerLayer and innerLayer:FindFirstChild("CenterCore")
        if centerCore then
            centerCore.Position = UDim2.new(0.57, 0, 0.39, 0)
            centerCore.Size = UDim2.new(0.50, 0, 0.32, 0)
            centerCore.BackgroundTransparency = 0
        end
    end

    local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
    if headerSig then
        headerSig.Position = UDim2.new(0.54, 0, 0.145, 0)
        headerSig.Rotation = -3
        local underlineBeam = headerSig:FindFirstChild("UnderlineBeam")
        if underlineBeam then
            underlineBeam.Position = UDim2.new(BeamPosX, 0, BeamPosY, 0)
            underlineBeam.Size = UDim2.new(BeamSizeX, 0, BeamSizeY, 0)
        end
    end

    local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    if quoteLbl then
        quoteLbl.Rotation = 0
    end

    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if breachLayer then
        breachLayer.Visible = false
        for _, child in ipairs(breachLayer:GetChildren()) do
            if child.Name == "DynamicPlasmaDrop" then
                child:Destroy()
            end
        end
    end
end

local function refreshAllBillboardInnerColors()
    for _, bb in pairs(charBillboards) do
        if bb and bb.Parent then
            local cloudRoot = bb:FindFirstChild("CloudRoot")
            local shieldGroup = cloudRoot and cloudRoot:FindFirstChild("ShieldGroup")
            local innerLayer = shieldGroup and shieldGroup:FindFirstChild("InnerLayer")
            applyInnerColorToLayer(innerLayer)
        end
    end
end

local function setHeadParticles(char, enabled, isSad)
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local att = head:FindFirstChild("OmegaVoiceVFXAttachment")
    if not enabled or not VfxActivos then
        if att then
            for _, p in ipairs(att:GetChildren()) do
                if p:IsA("ParticleEmitter") then
                    p.Enabled = false
                end
            end
        end
        return
    end

    if not att then
        att = Instance.new("Attachment")
        att.Name = "OmegaVoiceVFXAttachment"
        att.Position = Vector3.new(0.45, 0.55, 0)
        att.Parent = head

        local sparks = Instance.new("ParticleEmitter")
        sparks.Name = "VoiceSparks"
        sparks.Texture = "rbxassetid://243098098"
        sparks.Rate = 16
        sparks.Lifetime = NumberRange.new(0.55, 1.0)
        sparks.Speed = NumberRange.new(1.1, 2.4)
        sparks.SpreadAngle = Vector2.new(360, 360)
        sparks.LightEmission = 1
        sparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.14),
            NumberSequenceKeypoint.new(0.6, 0.22),
            NumberSequenceKeypoint.new(1, 0)
        })
        sparks.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(0.8, 0.4),
            NumberSequenceKeypoint.new(1, 1)
        })
        sparks.Parent = att

        local glow = Instance.new("ParticleEmitter")
        glow.Name = "VoiceGlow"
        glow.Texture = "rbxassetid://243098098"
        glow.Rate = 6
        glow.Lifetime = NumberRange.new(0.65, 0.95)
        glow.Speed = NumberRange.new(0.2, 0.5)
        glow.SpreadAngle = Vector2.new(180, 180)
        glow.LightEmission = 0.85
        glow.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.65),
            NumberSequenceKeypoint.new(0.5, 1.1),
            NumberSequenceKeypoint.new(1, 1.35)
        })
        glow.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.70),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(1, 1)
        })
        glow.Parent = att
    end

    local colorSeq = isSad and ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(115, 185, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 115, 205)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(80, 130, 200))
    }) or ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.0, COLOR_VIOLETA)
    })

    for _, p in ipairs(att:GetChildren()) do
        if p:IsA("ParticleEmitter") then
            p.Color = colorSeq
            p.Enabled = true
        end
    end
end

local function getBillboard(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return nil end

    local existing = charBillboards[char]
    if existing and existing.Parent then
        existing.Adornee = head
        local cloudRoot = existing:FindFirstChild("CloudRoot")
        local shieldGroup = cloudRoot and cloudRoot:FindFirstChild("ShieldGroup")
        local innerLayer = shieldGroup and shieldGroup:FindFirstChild("InnerLayer")
        applyInnerColorToLayer(innerLayer)
        applyBeamTransformToAll()
        return existing
    end

    local playerGui = player:WaitForChild("PlayerGui")
    local oldGui = playerGui:FindFirstChild("NewFenderForceShieldBB")
    if oldGui then oldGui:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "NewFenderForceShieldBB"
    bb.Adornee = head
    bb.Size = UDim2.new(4.15, 0, 2.75, 0)
    bb.StudsOffset = Vector3.new(2.55, 2.15, 0)
    bb.AlwaysOnTop = false
    bb.LightInfluence = 0
    bb.MaxDistance = 120
    bb.ResetOnSpawn = false
    bb.Enabled = false
    bb.Parent = playerGui

    charBillboards[char] = bb

    local cloudRoot = Instance.new("Frame")
    cloudRoot.Name = "CloudRoot"
    cloudRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    cloudRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
    cloudRoot.Size = UDim2.new(1, 0, 1, 0)
    cloudRoot.Rotation = -3
    cloudRoot.BackgroundTransparency = 1
    cloudRoot.ClipsDescendants = false
    cloudRoot.Visible = false
    cloudRoot.Parent = bb

    -- 1. TRAMA DE PUNTOS COMPLETA ALREDEDOR DE TODA LA NUBE
    local halftoneHolder = Instance.new("Frame")
    halftoneHolder.Name = "HalftoneHolder"
    halftoneHolder.Size = UDim2.new(1, 0, 1, 0)
    halftoneHolder.BackgroundTransparency = 1
    halftoneHolder.ZIndex = 1
    halftoneHolder.Parent = cloudRoot

    for row = 0, 14 do
        for col = 0, 19 do
            local stagger = (row % 2 == 0) and 0.020 or 0
            local px = 0.05 + (col / 19) * 0.90 + stagger
            local py = 0.01 + (row / 14) * 0.82

            local minNormDist = 999
            for _, sp in ipairs(LOBE_SPECS) do
                local dx = (px - sp.x) / (sp.w * 0.52)
                local dy = (py - sp.y) / (sp.h * 0.52)
                local d = math.sqrt(dx * dx + dy * dy)
                if d < minNormDist then
                    minNormDist = d
                end
            end

            if minNormDist >= 1.02 and minNormDist <= 1.50 then
                local dot = Instance.new("Frame")
                dot.Name = "Dot"
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.Position = UDim2.new(px, 0, py, 0)
                local tEdge = 1 - ((minNormDist - 1.02) / 0.48)
                local scaleSz = math.clamp(0.007 + tEdge * 0.011, 0.007, 0.018)
                dot.Size = UDim2.new(scaleSz, 0, scaleSz * 1.55, 0)
                local dotColorIdx = ((row + col) % 3) + 1
                dot.BackgroundColor3 = GLOBAL_PALETTE[dotColorIdx]
                dot.BackgroundTransparency = math.clamp(0.80 - tEdge * 0.44, 0.28, 0.84)
                dot.BorderSizePixel = 0
                dot.ZIndex = 1
                dot.Parent = halftoneHolder
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            end
        end
    end

    -- 2. FORCE SHIELD UNIFICADO
    local shieldGroup = Instance.new("CanvasGroup")
    shieldGroup.Name = "ShieldGroup"
    shieldGroup.Size = UDim2.new(1, 0, 1, 0)
    shieldGroup.BackgroundTransparency = 1
    shieldGroup.GroupTransparency = 0.24
    shieldGroup.ZIndex = 2
    shieldGroup.Parent = cloudRoot

    local borderLayer = Instance.new("CanvasGroup")
    borderLayer.Name = "BorderLayer"
    borderLayer.Size = UDim2.new(1, 0, 1, 0)
    borderLayer.BackgroundTransparency = 1
    borderLayer.ZIndex = 2
    borderLayer.Parent = shieldGroup

    local borderGrad = Instance.new("UIGradient", borderLayer)
    borderGrad.Name = "BorderGrad"
    borderGrad.Rotation = 18
    borderGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.28, COLOR_ROJO),
        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
        ColorSequenceKeypoint.new(0.72, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
    })

    local separatorLayer = Instance.new("CanvasGroup")
    separatorLayer.Name = "SeparatorLayer"
    separatorLayer.Size = UDim2.new(1, 0, 1, 0)
    separatorLayer.BackgroundTransparency = 1
    separatorLayer.ZIndex = 3
    separatorLayer.Parent = shieldGroup

    local innerLayer = Instance.new("CanvasGroup")
    innerLayer.Name = "InnerLayer"
    innerLayer.Size = UDim2.new(1, 0, 1, 0)
    innerLayer.BackgroundTransparency = 1
    innerLayer.ZIndex = 4
    innerLayer.Parent = shieldGroup

    local innerGrad = Instance.new("UIGradient", innerLayer)
    innerGrad.Name = "InnerGrad"
    innerGrad.Rotation = 30
    innerGrad.Color = getDefaultInnerColorSequence()

    for i, sp in ipairs(LOBE_SPECS) do
        local outerLobe = Instance.new("Frame")
        outerLobe.Name = "OuterLobe_" .. i
        outerLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        outerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        outerLobe.Size = UDim2.new(sp.w + 0.032, 0, sp.h + 0.048, 0)
        outerLobe.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        outerLobe.BorderSizePixel = 0
        outerLobe.Parent = borderLayer
        Instance.new("UICorner", outerLobe).CornerRadius = UDim.new(1, 0)

        local sepLobe = Instance.new("Frame")
        sepLobe.Name = "SepLobe_" .. i
        sepLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        sepLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        sepLobe.Size = UDim2.new(sp.w + 0.010, 0, sp.h + 0.015, 0)
        sepLobe.BackgroundColor3 = SHIELD_SEPARATOR
        sepLobe.BorderSizePixel = 0
        sepLobe.Parent = separatorLayer
        Instance.new("UICorner", sepLobe).CornerRadius = UDim.new(1, 0)

        local innerLobe = Instance.new("Frame")
        innerLobe.Name = "InnerLobe_" .. i
        innerLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        innerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        innerLobe.Size = UDim2.new(sp.w, 0, sp.h, 0)
        innerLobe.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        innerLobe.BorderSizePixel = 0
        innerLobe.Parent = innerLayer
        Instance.new("UICorner", innerLobe).CornerRadius = UDim.new(1, 0)
    end

    local centerCore = Instance.new("Frame")
    centerCore.Name = "CenterCore"
    centerCore.AnchorPoint = Vector2.new(0.5, 0.5)
    centerCore.Position = UDim2.new(0.57, 0, 0.39, 0)
    centerCore.Size = UDim2.new(0.50, 0, 0.32, 0)
    centerCore.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerCore.BorderSizePixel = 0
    centerCore.Parent = innerLayer
    Instance.new("UICorner", centerCore).CornerRadius = UDim.new(0.45, 0)

    -- 3. ESCURRIDO FUSIONADO AL GLOBO
    local dripEffectsLayer = Instance.new("Frame")
    dripEffectsLayer.Name = "DripEffectsLayer"
    dripEffectsLayer.Size = UDim2.new(1, 0, 1, 0)
    dripEffectsLayer.BackgroundTransparency = 1
    dripEffectsLayer.ZIndex = 5
    dripEffectsLayer.Parent = cloudRoot

    for i, d in ipairs(DRIP_SPECS) do
        local collarOut = Instance.new("Frame")
        collarOut.Name = "DripCollarOut_" .. i
        collarOut.AnchorPoint = Vector2.new(0.5, 0.5)
        collarOut.Position = UDim2.new(d.x, 0, d.y, 0)
        collarOut.Size = UDim2.new(d.w * 2.85 + 0.026, 0, 0.066, 0)
        collarOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        collarOut.BorderSizePixel = 0
        collarOut.Parent = borderLayer
        Instance.new("UICorner", collarOut).CornerRadius = UDim.new(1, 0)

        local taperOut = Instance.new("Frame")
        taperOut.Name = "DripTaperOut_" .. i
        taperOut.AnchorPoint = Vector2.new(0.5, 0)
        taperOut.Position = UDim2.new(d.x, 0, d.y, 0)
        taperOut.Size = UDim2.new(d.w * 1.80 + 0.026, 0, d.baseH * 0.45 + 0.024, 0)
        taperOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        taperOut.BorderSizePixel = 0
        taperOut.Parent = borderLayer
        Instance.new("UICorner", taperOut).CornerRadius = UDim.new(1, 0)

        local neckOut = Instance.new("Frame")
        neckOut.Name = "DripNeckOut_" .. i
        neckOut.AnchorPoint = Vector2.new(0.5, 0)
        neckOut.Position = UDim2.new(d.x, 0, d.y, 0)
        neckOut.Size = UDim2.new(d.w * 0.85 + 0.024, 0, d.baseH + 0.024, 0)
        neckOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        neckOut.BorderSizePixel = 0
        neckOut.Parent = borderLayer
        Instance.new("UICorner", neckOut).CornerRadius = UDim.new(1, 0)

        local bulbOut = Instance.new("Frame")
        bulbOut.Name = "DripBulbOut_" .. i
        bulbOut.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbOut.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbOut.Size = UDim2.new(d.w * 1.65 + 0.026, 0, (d.w * 1.65) * 1.72 + 0.038, 0)
        bulbOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bulbOut.BorderSizePixel = 0
        bulbOut.Parent = borderLayer
        Instance.new("UICorner", bulbOut).CornerRadius = UDim.new(1, 0)

        local collarSep = Instance.new("Frame")
        collarSep.Name = "DripCollarSep_" .. i
        collarSep.AnchorPoint = Vector2.new(0.5, 0.5)
        collarSep.Position = UDim2.new(d.x, 0, d.y, 0)
        collarSep.Size = UDim2.new(d.w * 2.85 + 0.010, 0, 0.044, 0)
        collarSep.BackgroundColor3 = SHIELD_SEPARATOR
        collarSep.BorderSizePixel = 0
        collarSep.Parent = separatorLayer
        Instance.new("UICorner", collarSep).CornerRadius = UDim.new(1, 0)

        local taperSep = Instance.new("Frame")
        taperSep.Name = "DripTaperSep_" .. i
        taperSep.AnchorPoint = Vector2.new(0.5, 0)
        taperSep.Position = UDim2.new(d.x, 0, d.y, 0)
        taperSep.Size = UDim2.new(d.w * 1.80 + 0.010, 0, d.baseH * 0.45 + 0.010, 0)
        taperSep.BackgroundColor3 = SHIELD_SEPARATOR
        taperSep.BorderSizePixel = 0
        taperSep.Parent = separatorLayer
        Instance.new("UICorner", taperSep).CornerRadius = UDim.new(1, 0)

        local neckSep = Instance.new("Frame")
        neckSep.Name = "DripNeckSep_" .. i
        neckSep.AnchorPoint = Vector2.new(0.5, 0)
        neckSep.Position = UDim2.new(d.x, 0, d.y, 0)
        neckSep.Size = UDim2.new(d.w * 0.85 + 0.008, 0, d.baseH + 0.010, 0)
        neckSep.BackgroundColor3 = SHIELD_SEPARATOR
        neckSep.BorderSizePixel = 0
        neckSep.Parent = separatorLayer
        Instance.new("UICorner", neckSep).CornerRadius = UDim.new(1, 0)

        local bulbSep = Instance.new("Frame")
        bulbSep.Name = "DripBulbSep_" .. i
        bulbSep.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbSep.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbSep.Size = UDim2.new(d.w * 1.65 + 0.010, 0, (d.w * 1.65) * 1.72 + 0.014, 0)
        bulbSep.BackgroundColor3 = SHIELD_SEPARATOR
        bulbSep.BorderSizePixel = 0
        bulbSep.Parent = separatorLayer
        Instance.new("UICorner", bulbSep).CornerRadius = UDim.new(1, 0)

        local collarIn = Instance.new("Frame")
        collarIn.Name = "DripCollarIn_" .. i
        collarIn.AnchorPoint = Vector2.new(0.5, 0.5)
        collarIn.Position = UDim2.new(d.x, 0, d.y, 0)
        collarIn.Size = UDim2.new(d.w * 2.85, 0, 0.032, 0)
        collarIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        collarIn.BorderSizePixel = 0
        collarIn.Parent = innerLayer
        Instance.new("UICorner", collarIn).CornerRadius = UDim.new(1, 0)

        local taperIn = Instance.new("Frame")
        taperIn.Name = "DripTaperIn_" .. i
        taperIn.AnchorPoint = Vector2.new(0.5, 0)
        taperIn.Position = UDim2.new(d.x, 0, d.y, 0)
        taperIn.Size = UDim2.new(d.w * 1.80, 0, d.baseH * 0.45, 0)
        taperIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        taperIn.BorderSizePixel = 0
        taperIn.Parent = innerLayer
        Instance.new("UICorner", taperIn).CornerRadius = UDim.new(1, 0)

        local neckIn = Instance.new("Frame")
        neckIn.Name = "DripNeckIn_" .. i
        neckIn.AnchorPoint = Vector2.new(0.5, 0)
        neckIn.Position = UDim2.new(d.x, 0, d.y, 0)
        neckIn.Size = UDim2.new(d.w * 0.85, 0, d.baseH, 0)
        neckIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        neckIn.BorderSizePixel = 0
        neckIn.Parent = innerLayer
        Instance.new("UICorner", neckIn).CornerRadius = UDim.new(1, 0)

        local bulbIn = Instance.new("Frame")
        bulbIn.Name = "DripBulbIn_" .. i
        bulbIn.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbIn.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbIn.Size = UDim2.new(d.w * 1.65, 0, (d.w * 1.65) * 1.72, 0)
        bulbIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bulbIn.BorderSizePixel = 0
        bulbIn.Parent = innerLayer
        Instance.new("UICorner", bulbIn).CornerRadius = UDim.new(1, 0)

        local gloss = Instance.new("Frame")
        gloss.Name = "DripGloss_" .. i
        gloss.AnchorPoint = Vector2.new(0.5, 0.5)
        gloss.Position = UDim2.new(d.x - d.w * 0.35, 0, d.y + d.baseH - 0.004, 0)
        gloss.Size = UDim2.new(d.w * 0.42, 0, d.w * 0.85, 0)
        gloss.BackgroundColor3 = COLOR_CELESTE
        gloss.BackgroundTransparency = 0.25
        gloss.BorderSizePixel = 0
        gloss.Parent = dripEffectsLayer
        Instance.new("UICorner", gloss).CornerRadius = UDim.new(1, 0)
    end

    -- 4. LOS 3 ORBES DE ENERGÍA
    local thoughtCircles = {
        {x = 0.24, y = 0.68, w = 0.068, h = 0.104},
        {x = 0.14, y = 0.78, w = 0.046, h = 0.070},
        {x = 0.06, y = 0.87, w = 0.028, h = 0.043}
    }

    for i, tc in ipairs(thoughtCircles) do
        local orbOuter = Instance.new("Frame")
        orbOuter.Name = "OrbOuter_" .. i
        orbOuter.AnchorPoint = Vector2.new(0.5, 0.5)
        orbOuter.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbOuter.Size = UDim2.new(tc.w + 0.022, 0, tc.h + 0.034, 0)
        orbOuter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        orbOuter.BorderSizePixel = 0
        orbOuter.Parent = borderLayer
        Instance.new("UICorner", orbOuter).CornerRadius = UDim.new(1, 0)

        local orbSep = Instance.new("Frame")
        orbSep.Name = "OrbSep_" .. i
        orbSep.AnchorPoint = Vector2.new(0.5, 0.5)
        orbSep.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbSep.Size = UDim2.new(tc.w + 0.008, 0, tc.h + 0.012, 0)
        orbSep.BackgroundColor3 = SHIELD_SEPARATOR
        orbSep.BorderSizePixel = 0
        orbSep.Parent = separatorLayer
        Instance.new("UICorner", orbSep).CornerRadius = UDim.new(1, 0)

        local orbInner = Instance.new("Frame")
        orbInner.Name = "OrbInner_" .. i
        orbInner.AnchorPoint = Vector2.new(0.5, 0.5)
        orbInner.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbInner.Size = UDim2.new(tc.w, 0, tc.h, 0)
        orbInner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        orbInner.BorderSizePixel = 0
        orbInner.Parent = innerLayer
        Instance.new("UICorner", orbInner).CornerRadius = UDim.new(1, 0)
    end

    -- 5. FIRMA SPIDER-MAN CON ESTRELLA MÁS GRANDE Y RAYA SIN EFECTOS NI CORTES
    local headerSig = Instance.new("Frame")
    headerSig.Name = "HeaderSignature"
    headerSig.AnchorPoint = Vector2.new(0.5, 0.5)
    headerSig.Position = UDim2.new(0.54, 0, 0.145, 0)
    headerSig.Size = UDim2.new(0.62, 0, 0.165, 0)
    headerSig.Rotation = -3
    headerSig.BackgroundTransparency = 1
    headerSig.ClipsDescendants = false
    headerSig.ZIndex = 14
    headerSig.Parent = cloudRoot

    local starEmblem = Instance.new("ImageLabel")
    starEmblem.Name = "StarEmblem"
    starEmblem.AnchorPoint = Vector2.new(0.5, 0.5)
    starEmblem.Position = UDim2.new(0.115, 0, 0.43, 0)
    starEmblem.Size = UDim2.new(0.325, 0, 1.76, 0)
    starEmblem.BackgroundTransparency = 1
    starEmblem.ImageTransparency = 0
    starEmblem.BorderSizePixel = 0
    starEmblem.Image = ""
    starEmblem.ScaleType = Enum.ScaleType.Fit
    starEmblem.ZIndex = 17
    starEmblem.Parent = headerSig
    applySafeWebImage(starEmblem, STAR_EMBLEM_URL, "omega_spidey_star_v2.png")

    local nameTextGroup = Instance.new("Frame")
    nameTextGroup.Name = "NameTextGroup"
    nameTextGroup.AnchorPoint = Vector2.new(0, 0.5)
    nameTextGroup.Position = UDim2.new(0.295, 0, 0.36, 0)
    nameTextGroup.Size = UDim2.new(0.685, 0, 0.68, 0)
    nameTextGroup.BackgroundTransparency = 1
    nameTextGroup.ZIndex = 15
    nameTextGroup.Parent = headerSig

    local shadowCyan = Instance.new("TextLabel")
    shadowCyan.Name = "ShadowCyan"
    shadowCyan.Position = UDim2.new(-0.016, 0, -0.022, 0)
    shadowCyan.Size = UDim2.new(1, 0, 1, 0)
    shadowCyan.BackgroundTransparency = 1
    shadowCyan.Font = Enum.Font.Bangers
    shadowCyan.TextScaled = true
    shadowCyan.TextXAlignment = Enum.TextXAlignment.Left
    shadowCyan.TextColor3 = COLOR_CELESTE
    shadowCyan.TextTransparency = 0.22
    shadowCyan.Text = "SPIDER-MAN"
    shadowCyan.ZIndex = 15
    shadowCyan.Parent = nameTextGroup

    local shadowRed = Instance.new("TextLabel")
    shadowRed.Name = "ShadowRed"
    shadowRed.Position = UDim2.new(0.016, 0, 0.022, 0)
    shadowRed.Size = UDim2.new(1, 0, 1, 0)
    shadowRed.BackgroundTransparency = 1
    shadowRed.Font = Enum.Font.Bangers
    shadowRed.TextScaled = true
    shadowRed.TextXAlignment = Enum.TextXAlignment.Left
    shadowRed.TextColor3 = COLOR_ROJO
    shadowRed.TextTransparency = 0.22
    shadowRed.Text = "SPIDER-MAN"
    shadowRed.ZIndex = 15
    shadowRed.Parent = nameTextGroup

    local headerLbl = Instance.new("TextLabel")
    headerLbl.Name = "HeaderLbl"
    headerLbl.Size = UDim2.new(1, 0, 1, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.Font = Enum.Font.Bangers
    headerLbl.TextScaled = true
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    headerLbl.Text = "SPIDER-MAN"
    headerLbl.ZIndex = 16
    headerLbl.Parent = nameTextGroup

    local headerGrad = Instance.new("UIGradient", headerLbl)
    headerGrad.Name = "HeaderGrad"
    headerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.45, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1.00, COLOR_VIOLETA)
    })

    local headerStroke = Instance.new("UIStroke", headerLbl)
    headerStroke.Color = Color3.fromRGB(10, 20, 46)
    headerStroke.Thickness = 2.2

    -- Foto de la raya 100% limpia y controlada por BeamPosX/Y y BeamSizeX/Y
    local underlineBeam = Instance.new("ImageLabel")
    underlineBeam.Name = "UnderlineBeam"
    underlineBeam.AnchorPoint = Vector2.new(0.5, 0.5)
    underlineBeam.Position = UDim2.new(BeamPosX, 0, BeamPosY, 0)
    underlineBeam.Size = UDim2.new(BeamSizeX, 0, BeamSizeY, 0)
    underlineBeam.BackgroundTransparency = 1
    underlineBeam.ImageTransparency = 0
    underlineBeam.BorderSizePixel = 0
    underlineBeam.Image = ""
    underlineBeam.ScaleType = Enum.ScaleType.Fit
    underlineBeam.ZIndex = 16
    underlineBeam.Parent = headerSig
    applySafeWebImage(underlineBeam, ENERGY_BEAM_URL, "omega_spidey_beam_v3.png")

    applyInnerColorToLayer(innerLayer)

    -- 6. CAPA DE DESTELLO INICIAL DE SEPARACIÓN
    local breachLayer = Instance.new("Frame")
    breachLayer.Name = "EnergyBreachLayer"
    breachLayer.Size = UDim2.new(1, 0, 1, 0)
    breachLayer.BackgroundTransparency = 1
    breachLayer.Visible = false
    breachLayer.ZIndex = 12
    breachLayer.Parent = cloudRoot

    local breachOrigin = Instance.new("Frame")
    breachOrigin.Name = "BreachOrigin"
    breachOrigin.AnchorPoint = Vector2.new(0.5, 0.5)
    breachOrigin.Position = UDim2.new(0.550, 0, 0.195, 0)
    breachOrigin.Size = UDim2.new(0, 0, 0, 0)
    breachOrigin.BackgroundColor3 = Color3.fromRGB(225, 250, 255)
    breachOrigin.BackgroundTransparency = 1
    breachOrigin.BorderSizePixel = 0
    breachOrigin.ZIndex = 13
    breachOrigin.Parent = breachLayer
    Instance.new("UICorner", breachOrigin).CornerRadius = UDim.new(1, 0)

    local originRing = Instance.new("Frame")
    originRing.Name = "OriginRing"
    originRing.AnchorPoint = Vector2.new(0.5, 0.5)
    originRing.Position = UDim2.new(0.550, 0, 0.195, 0)
    originRing.Size = UDim2.new(0, 0, 0, 0)
    originRing.BackgroundTransparency = 1
    originRing.ZIndex = 13
    originRing.Parent = breachLayer
    Instance.new("UICorner", originRing).CornerRadius = UDim.new(1, 0)

    local originRingStroke = Instance.new("UIStroke", originRing)
    originRingStroke.Name = "OriginRingStroke"
    originRingStroke.Color = COLOR_CELESTE
    originRingStroke.Thickness = 2.0
    originRingStroke.Transparency = 1

    -- 7. ZONA SEGURA DE TEXTO + ONDAS DE MÚSICA ANIMADAS
    local safeTextZone = Instance.new("Frame")
    safeTextZone.Name = "SafeTextZone"
    safeTextZone.AnchorPoint = Vector2.new(0.5, 0.5)
    safeTextZone.Position = UDim2.new(0.57, 0, 0.415, 0)
    safeTextZone.Size = UDim2.new(0.55, 0, 0.33, 0)
    safeTextZone.ClipsDescendants = true
    safeTextZone.BackgroundTransparency = 1
    safeTextZone.ZIndex = 9
    safeTextZone.Parent = cloudRoot

    local quoteBox = Instance.new("Frame")
    quoteBox.Name = "QuoteBox"
    quoteBox.Size = UDim2.new(1, 0, 1, 0)
    quoteBox.ClipsDescendants = true
    quoteBox.BackgroundTransparency = 1
    quoteBox.ZIndex = 9
    quoteBox.Parent = safeTextZone

    local quoteLbl = Instance.new("TextLabel")
    quoteLbl.Name = "QuoteLbl"
    quoteLbl.Size = UDim2.new(1, 0, 1, 0)
    quoteLbl.BackgroundTransparency = 1
    quoteLbl.Font = Enum.Font.Bangers
    quoteLbl.TextWrapped = true
    quoteLbl.TextScaled = true
    quoteLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    quoteLbl.Text = ""
    quoteLbl.ZIndex = 10
    quoteLbl.Parent = quoteBox

    local quoteStroke = Instance.new("UIStroke", quoteLbl)
    quoteStroke.Name = "QuoteStroke"
    quoteStroke.Color = Color3.fromRGB(12, 26, 54)
    quoteStroke.Thickness = 2.0

    local textGrad = Instance.new("UIGradient", quoteLbl)
    textGrad.Name = "TextLightGrad"
    textGrad.Rotation = 12
    textGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.32, COLOR_ROJO),
        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
        ColorSequenceKeypoint.new(0.68, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
    })

    local musicWavesHolder = Instance.new("Frame")
    musicWavesHolder.Name = "MusicWavesHolder"
    musicWavesHolder.Size = UDim2.new(1, 0, 1, 0)
    musicWavesHolder.BackgroundTransparency = 1
    musicWavesHolder.Visible = false
    musicWavesHolder.ZIndex = 10
    musicWavesHolder.Parent = quoteBox

    local songIconLbl = Instance.new("TextLabel")
    songIconLbl.Name = "SongIconLbl"
    songIconLbl.AnchorPoint = Vector2.new(0.5, 0)
    songIconLbl.Position = UDim2.new(0.5, 0, 0.0, 0)
    songIconLbl.Size = UDim2.new(0.34, 0, 0.36, 0)
    songIconLbl.BackgroundTransparency = 1
    songIconLbl.Font = Enum.Font.GothamBlack
    songIconLbl.TextScaled = true
    songIconLbl.TextColor3 = COLOR_CELESTE
    songIconLbl.Text = "🎧"
    songIconLbl.ZIndex = 11
    songIconLbl.Parent = musicWavesHolder

    local barsFrame = Instance.new("Frame")
    barsFrame.Name = "BarsFrame"
    barsFrame.AnchorPoint = Vector2.new(0.5, 1)
    barsFrame.Position = UDim2.new(0.5, 0, 0.96, 0)
    barsFrame.Size = UDim2.new(0.84, 0, 0.56, 0)
    barsFrame.BackgroundTransparency = 1
    barsFrame.ZIndex = 11
    barsFrame.Parent = musicWavesHolder

    local numBars = 9
    for b = 1, numBars do
        local bar = Instance.new("Frame")
        bar.Name = "WaveBar_" .. b
        bar.AnchorPoint = Vector2.new(0.5, 0.5)
        local xPos = (b - 0.5) / numBars
        bar.Position = UDim2.new(xPos, 0, 0.5, 0)
        bar.Size = UDim2.new(0.068, 0, 0.35, 0)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BorderSizePixel = 0
        bar.ZIndex = 11
        bar.Parent = barsFrame
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local bGrad = Instance.new("UIGradient", bar)
        bGrad.Rotation = 90
        bGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, COLOR_CELESTE),
            ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
            ColorSequenceKeypoint.new(1.0, COLOR_VIOLETA)
        })
    end

    return bb
end

local function spawnPlasmaLeakDrop(parentLayer, originX, originY)
    if not parentLayer or not parentLayer.Parent then return end
    local drop = Instance.new("Frame")
    drop.Name = "DynamicPlasmaDrop"
    drop.AnchorPoint = Vector2.new(0.5, 0.5)
    drop.Position = UDim2.new(originX, 0, originY, 0)
    drop.Size = UDim2.new(0.015, 0, 0.024, 0)
    local colors = {COLOR_CELESTE, COLOR_VIOLETA, Color3.fromRGB(210, 245, 255)}
    drop.BackgroundColor3 = colors[math.random(1, #colors)]
    drop.BackgroundTransparency = 0.1
    drop.BorderSizePixel = 0
    drop.ZIndex = 13
    drop.Parent = parentLayer
    Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

    local dStroke = Instance.new("UIStroke", drop)
    dStroke.Color = SHIELD_SEPARATOR
    dStroke.Thickness = 1

    local driftX = (math.random() - 0.5) * 0.12
    local fallY = math.min(originY + 0.18 + math.random() * 0.16, 0.97)
    local dur = 0.65 + math.random() * 0.30

    local tw = TweenService:Create(drop, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(math.clamp(originX + driftX, 0.05, 0.95), 0, fallY, 0),
        Size = UDim2.new(0.008, 0, 0.036, 0),
        BackgroundTransparency = 1
    })
    TweenService:Create(dStroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Transparency = 1
    }):Play()
    tw:Play()
    tw.Completed:Connect(function()
        if drop then drop:Destroy() end
    end)
end

local function startProgressiveEnergyBreach(cloudRoot, sessionId, char)
    if not cloudRoot then return end
    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if not breachLayer then return end

    breachLayer.Visible = true

    local breachOrigin = breachLayer:FindFirstChild("BreachOrigin")
    local originRing = breachLayer:FindFirstChild("OriginRing")
    local originRingStroke = originRing and originRing:FindFirstChild("OriginRingStroke")

    if breachOrigin then
        breachOrigin.Size = UDim2.new(0, 0, 0, 0)
        breachOrigin.BackgroundTransparency = 1
    end
    if originRing then
        originRing.Size = UDim2.new(0, 0, 0, 0)
        if originRingStroke then originRingStroke.Transparency = 1 end
    end

    task.delay(0.24, function()
        if not breachLayer or not breachLayer.Parent then return end
        if char and char:GetAttribute("VoiceSession") ~= sessionId then return end

        if breachOrigin then
            breachOrigin.BackgroundTransparency = 0.05
            TweenService:Create(breachOrigin, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0.032, 0, 0.048, 0)
            }):Play()
            task.delay(0.35, function()
                if breachOrigin and breachOrigin.Parent then
                    TweenService:Create(breachOrigin, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
                end
            end)
        end

        if originRing and originRingStroke then
            originRingStroke.Transparency = 0.1
            TweenService:Create(originRing, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0.18, 0, 0.26, 0)
            }):Play()
            TweenService:Create(originRingStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Transparency = 1
            }):Play()
        end
    end)

    for step = 1, 5 do
        local openDelay = 0.45 + (step - 1) * 0.10
        task.delay(openDelay, function()
            if not breachLayer or not breachLayer.Parent then return end
            if char and char:GetAttribute("VoiceSession") ~= sessionId then return end
            spawnPlasmaLeakDrop(breachLayer, 0.548 + (math.random() - 0.5) * 0.02, 0.20 + (step - 1) * 0.075)
        end)
    end
end

local function startCaptionEffectsLoop(char, sessionId, vfxType, isSong, isSadDeath)
    activeCaptionLoops[char] = sessionId
    local startTime = tick()
    local nextDropTime = 0
    local nextLeakTime = 0.85

    task.spawn(function()
        while activeCaptionLoops[char] == sessionId and char and char.Parent do
            local bb = charBillboards[char]
            if not bb or not bb.Parent or not bb.Enabled then break end

            local cloudRoot = bb:FindFirstChild("CloudRoot")
            if not cloudRoot or not cloudRoot.Visible then break end

            local elapsed = tick() - startTime

            -- 1. Movimientos de la estrella y del texto (sin efectos encima de las imágenes)
            local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
            local starEmblem = headerSig and headerSig:FindFirstChild("StarEmblem")
            local nameTextGroup = headerSig and headerSig:FindFirstChild("NameTextGroup")
            local shadowCyan = nameTextGroup and nameTextGroup:FindFirstChild("ShadowCyan")
            local shadowRed = nameTextGroup and nameTextGroup:FindFirstChild("ShadowRed")
            local headerLbl = nameTextGroup and nameTextGroup:FindFirstChild("HeaderLbl")
            local headerGrad = headerLbl and headerLbl:FindFirstChild("HeaderGrad")

            if starEmblem then
                starEmblem.Rotation = (elapsed * 32) % 360
                local starPulse = 1 + math.sin(elapsed * 3.4) * 0.07
                starEmblem.Size = UDim2.new(0.325 * starPulse, 0, 1.76 * starPulse, 0)
            end

            if shadowCyan and shadowRed then
                local glitchOff = math.sin(elapsed * 3.8) * 0.005
                shadowCyan.Position = UDim2.new(-0.016 - glitchOff, 0, -0.022, 0)
                shadowRed.Position = UDim2.new(0.016 + glitchOff, 0, 0.022, 0)
            end

            if headerGrad then
                headerGrad.Offset = Vector2.new(math.sin(elapsed * 2.1) * 0.70, 0)
            end

            local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
            local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
            local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
            local textGrad = quoteLbl and quoteLbl:FindFirstChild("TextLightGrad")
            if textGrad then
                local sweep = math.sin(elapsed * (isSadDeath and 1.1 or 2.5)) * 0.85
                textGrad.Offset = Vector2.new(sweep, 0)
            end

            -- 2. Animación de las ondas de música (cuando suena la canción)
            if isSong and quoteBox then
                local musicWavesHolder = quoteBox:FindFirstChild("MusicWavesHolder")
                local barsFrame = musicWavesHolder and musicWavesHolder:FindFirstChild("BarsFrame")
                local songIconLbl = musicWavesHolder and musicWavesHolder:FindFirstChild("SongIconLbl")
                if songIconLbl then
                    local pulseIcon = 0.36 + math.sin(elapsed * 6.0) * 0.045
                    songIconLbl.Size = UDim2.new(0.34, 0, pulseIcon, 0)
                end
                if barsFrame then
                    for b = 1, 9 do
                        local bar = barsFrame:FindFirstChild("WaveBar_" .. b)
                        if bar then
                            local w1 = math.abs(math.sin(elapsed * 6.5 + b * 0.85))
                            local w2 = math.abs(math.cos(elapsed * 4.2 - b * 0.55))
                            local hScale = math.clamp(0.20 + (w1 * 0.55 + w2 * 0.30), 0.18, 0.98)
                            bar.Size = UDim2.new(0.068, 0, hScale, 0)
                        end
                    end
                end
            end

            -- 3. Borde luminoso, separación de mitades y escurrido
            local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
            local dripEffectsLayer = cloudRoot:FindFirstChild("DripEffectsLayer")

            local splitProgress = 0
            if isSadDeath and elapsed > 0.45 then
                local rawT = math.clamp((elapsed - 0.45) / 0.85, 0, 1)
                splitProgress = rawT * rawT * (3 - 2 * rawT)
            end

            if shieldGroup then
                local holoFlicker = (isSadDeath and elapsed > 0.40) and (math.sin(elapsed * 22) * 0.03) or 0
                shieldGroup.GroupTransparency = math.clamp((isSadDeath and 0.26 or 0.22) + math.sin(elapsed * 2.8) * 0.04 + holoFlicker, 0.15, 0.45)

                local borderLayer = shieldGroup:FindFirstChild("BorderLayer")
                local separatorLayer = shieldGroup:FindFirstChild("SeparatorLayer")
                local innerLayer = shieldGroup:FindFirstChild("InnerLayer")

                if isSadDeath then
                    local breatheSplit = math.sin(elapsed * 3.0) * 0.005 * splitProgress

                    for i, sp in ipairs(LOBE_SPECS) do
                        local dx = (sp.side == -1) and (-0.052 * splitProgress - breatheSplit) or (0.066 * splitProgress + breatheSplit)
                        local dy = (sp.side == -1) and (0.012 * splitProgress) or (0.062 * splitProgress)

                        local outerLobe = borderLayer and borderLayer:FindFirstChild("OuterLobe_" .. i)
                        local sepLobe = separatorLayer and separatorLayer:FindFirstChild("SepLobe_" .. i)
                        local innerLobe = innerLayer and innerLayer:FindFirstChild("InnerLobe_" .. i)

                        if outerLobe then outerLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                        if sepLobe then sepLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                        if innerLobe then innerLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                    end

                    local centerCore = innerLayer and innerLayer:FindFirstChild("CenterCore")
                    if centerCore then
                        centerCore.Size = UDim2.new(0.50 * (1 - splitProgress * 0.76), 0, 0.32 * (1 - splitProgress * 0.28), 0)
                        centerCore.Position = UDim2.new(0.57, 0, 0.39 + 0.03 * splitProgress, 0)
                        centerCore.BackgroundTransparency = splitProgress * 0.65
                    end

                    if headerSig then
                        headerSig.Position = UDim2.new(0.54 - 0.030 * splitProgress, 0, 0.145 + 0.012 * splitProgress, 0)
                        headerSig.Rotation = -3 - 5.0 * splitProgress + math.sin(elapsed * 2.2) * 0.7
                    end

                    if quoteLbl then
                        quoteLbl.Rotation = 3.0 * splitProgress
                    end

                    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
                    if breachLayer and elapsed > 0.55 then
                        if elapsed >= nextLeakTime then
                            nextLeakTime = elapsed + 0.34
                            spawnPlasmaLeakDrop(breachLayer, 0.548 + (math.random() - 0.5) * 0.02, 0.22 + math.random() * 0.34)
                        end
                    end
                end

                local borderGrad = borderLayer and borderLayer:FindFirstChild("BorderGrad")
                local innerGrad = innerLayer and innerLayer:FindFirstChild("InnerGrad")

                if borderGrad then
                    borderGrad.Offset = Vector2.new(math.sin(elapsed * (isSadDeath and 0.9 or 2.2)) * 0.88, 0)
                    borderGrad.Rotation = 18 + math.cos(elapsed * 1.4) * 28
                end

                if innerGrad and innerGrad.Enabled then
                    innerGrad.Offset = Vector2.new(math.cos(elapsed * 1.6) * 0.45, 0)
                    innerGrad.Rotation = (elapsed * 25) % 360
                end

                for i, d in ipairs(DRIP_SPECS) do
                    local speedMult = isSadDeath and 0.65 or 1.0
                    local wave = (math.sin(elapsed * (2.1 + i * 0.35) * speedMult + i * 1.5) + 1) * 0.5
                    local curH = d.baseH + wave * (isSadDeath and 0.125 or 0.082)
                    local bulbScale = 0.92 + wave * 0.32
                    local neckThin = 1.0 - wave * 0.25

                    local dOffX = isSadDeath and ((d.side == -1) and (-0.048 * splitProgress) or (0.062 * splitProgress)) or 0
                    local dOffY = isSadDeath and ((d.side == -1) and (0.012 * splitProgress) or (0.060 * splitProgress)) or 0
                    local dxPos = d.x + dOffX
                    local dyPos = d.y + dOffY

                    local collarOut = borderLayer and borderLayer:FindFirstChild("DripCollarOut_" .. i)
                    local taperOut = borderLayer and borderLayer:FindFirstChild("DripTaperOut_" .. i)
                    local neckOut = borderLayer and borderLayer:FindFirstChild("DripNeckOut_" .. i)
                    local bulbOut = borderLayer and borderLayer:FindFirstChild("DripBulbOut_" .. i)
                    if collarOut then collarOut.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperOut then
                        taperOut.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperOut.Size = UDim2.new(d.w * 1.80 + 0.026, 0, curH * 0.45 + 0.024, 0)
                    end
                    if neckOut then
                        neckOut.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckOut.Size = UDim2.new((d.w * 0.85 * neckThin) + 0.024, 0, curH + 0.024, 0)
                    end
                    if bulbOut then
                        bulbOut.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbOut.Size = UDim2.new((d.w * 1.65) * bulbScale + 0.026, 0, ((d.w * 1.65) * 1.72) * bulbScale + 0.038, 0)
                    end

                    local collarSep = separatorLayer and separatorLayer:FindFirstChild("DripCollarSep_" .. i)
                    local taperSep = separatorLayer and separatorLayer:FindFirstChild("DripTaperSep_" .. i)
                    local neckSep = separatorLayer and separatorLayer:FindFirstChild("DripNeckSep_" .. i)
                    local bulbSep = separatorLayer and separatorLayer:FindFirstChild("DripBulbSep_" .. i)
                    if collarSep then collarSep.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperSep then
                        taperSep.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperSep.Size = UDim2.new(d.w * 1.80 + 0.010, 0, curH * 0.45 + 0.010, 0)
                    end
                    if neckSep then
                        neckSep.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckSep.Size = UDim2.new((d.w * 0.85 * neckThin) + 0.008, 0, curH + 0.010, 0)
                    end
                    if bulbSep then
                        bulbSep.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbSep.Size = UDim2.new((d.w * 1.65) * bulbScale + 0.010, 0, ((d.w * 1.65) * 1.72) * bulbScale + 0.014, 0)
                    end

                    local collarIn = innerLayer and innerLayer:FindFirstChild("DripCollarIn_" .. i)
                    local taperIn = innerLayer and innerLayer:FindFirstChild("DripTaperIn_" .. i)
                    local neckIn = innerLayer and innerLayer:FindFirstChild("DripNeckIn_" .. i)
                    local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. i)
                    if collarIn then collarIn.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperIn then
                        taperIn.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperIn.Size = UDim2.new(d.w * 1.80, 0, curH * 0.45, 0)
                    end
                    if neckIn then
                        neckIn.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckIn.Size = UDim2.new(d.w * 0.85 * neckThin, 0, curH, 0)
                    end
                    if bulbIn then
                        bulbIn.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbIn.Size = UDim2.new((d.w * 1.65) * bulbScale, 0, ((d.w * 1.65) * 1.72) * bulbScale, 0)
                    end

                    local gloss = dripEffectsLayer and dripEffectsLayer:FindFirstChild("DripGloss_" .. i)
                    if gloss then
                        gloss.Position = UDim2.new(dxPos - (d.w * 0.35 * bulbScale), 0, dyPos + curH - 0.004, 0)
                        gloss.Size = UDim2.new(d.w * 0.42 * bulbScale, 0, d.w * 0.85 * bulbScale, 0)
                    end
                end

                if dripEffectsLayer and tick() >= nextDropTime then
                    nextDropTime = tick() + (isSadDeath and 0.32 or 0.48)
                    local pick = math.random(1, #DRIP_SPECS)
                    local d = DRIP_SPECS[pick]
                    local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. pick)
                    if bulbIn then
                        local drop = Instance.new("Frame")
                        drop.AnchorPoint = Vector2.new(0.5, 0.5)
                        drop.Position = bulbIn.Position
                        drop.Size = UDim2.new(0.020, 0, 0.036, 0)
                        drop.BackgroundColor3 = isSadDeath and COLOR_CELESTE or d.dropColor
                        drop.BorderSizePixel = 0
                        drop.Parent = dripEffectsLayer
                        Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

                        local dStroke = Instance.new("UIStroke", drop)
                        dStroke.Color = SHIELD_SEPARATOR
                        dStroke.Thickness = 1.2

                        local dropGloss = Instance.new("Frame")
                        dropGloss.AnchorPoint = Vector2.new(0.5, 0.5)
                        dropGloss.Position = UDim2.new(0.32, 0, 0.38, 0)
                        dropGloss.Size = UDim2.new(0.28, 0, 0.34, 0)
                        dropGloss.BackgroundColor3 = COLOR_CELESTE
                        dropGloss.BackgroundTransparency = 0.2
                        dropGloss.BorderSizePixel = 0
                        dropGloss.Parent = drop
                        Instance.new("UICorner", dropGloss).CornerRadius = UDim.new(1, 0)

                        local startDropX = bulbIn.Position.X.Scale
                        local startDropY = bulbIn.Position.Y.Scale
                        local fallTw = TweenService:Create(drop, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                            Position = UDim2.new(startDropX, 0, math.min(startDropY + 0.22, 0.98), 0),
                            Size = UDim2.new(0.011, 0, 0.048, 0),
                            BackgroundTransparency = 1
                        })
                        TweenService:Create(dStroke, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                            Transparency = 1
                        }):Play()
                        fallTw:Play()
                        fallTw.Completed:Connect(function()
                            if drop then drop:Destroy() end
                        end)
                    end
                end

                local baseOrbs = {
                    {w = 0.068, h = 0.104},
                    {w = 0.046, h = 0.070},
                    {w = 0.028, h = 0.043}
                }
                for i = 1, 3 do
                    local orbOuter = borderLayer and borderLayer:FindFirstChild("OrbOuter_" .. i)
                    local orbSep = separatorLayer and separatorLayer:FindFirstChild("OrbSep_" .. i)
                    local orbInner = innerLayer and innerLayer:FindFirstChild("OrbInner_" .. i)
                    local pulse = 1 + math.sin(elapsed * 4.2 - i * 0.7) * 0.12
                    if orbOuter then
                        orbOuter.Size = UDim2.new((baseOrbs[i].w + 0.022) * pulse, 0, (baseOrbs[i].h + 0.034) * pulse, 0)
                    end
                    if orbSep then
                        orbSep.Size = UDim2.new((baseOrbs[i].w + 0.008) * pulse, 0, (baseOrbs[i].h + 0.012) * pulse, 0)
                    end
                    if orbInner then
                        orbInner.Size = UDim2.new(baseOrbs[i].w * pulse, 0, baseOrbs[i].h * pulse, 0)
                    end
                end
            end

            -- 4. Movimiento y vibración progresiva cuando empieza a separarse
            local panX = math.sin(elapsed * (isSadDeath and 1.2 or 2.1)) * 0.022
            local panY = math.cos(elapsed * (isSadDeath and 1.4 or 2.7)) * 0.016 + (isSadDeath and 0.050 * splitProgress or 0)

            local shakeX, shakeY, shakeRot = 0, 0, 0
            if vfxType == "damage" and elapsed < 0.35 then
                local power = 1 - (elapsed / 0.35)
                shakeX = math.sin(elapsed * 62) * 0.018 * power
                shakeY = math.cos(elapsed * 68) * 0.014 * power
                shakeRot = math.sin(elapsed * 54) * 2.8 * power
            elseif isSadDeath and elapsed >= 0.24 and elapsed < 1.15 then
                local pTime = elapsed - 0.24
                local envelope = math.sin(math.clamp(pTime / 0.91, 0, 1) * math.pi)
                shakeX = math.sin(elapsed * 64) * 0.024 * envelope
                shakeY = math.cos(elapsed * 70) * 0.018 * envelope
                shakeRot = math.sin(elapsed * 56) * 3.8 * envelope
            end

            local baseRot = isSadDeath and (-3 + 9.5 * splitProgress) or -3
            cloudRoot.Position = UDim2.new(0.5 + panX + shakeX, 0, 0.5 + panY + shakeY, 0)
            cloudRoot.Rotation = baseRot + math.sin(elapsed * 1.9) * 1.6 + shakeRot

            RunService.RenderStepped:Wait()
        end
    end)
end

local function transitionBubbleQuote(char, sessionId, newText)
    if not char or not newText then return end
    local bb = charBillboards[char]
    if not bb or not bb.Parent then return end

    local cloudRoot = bb:FindFirstChild("CloudRoot")
    local safeTextZone = cloudRoot and cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    if not quoteLbl then return end

    local quoteStroke = quoteLbl:FindFirstChild("QuoteStroke") or quoteLbl:FindFirstChildOfClass("UIStroke")

    task.spawn(function()
        if char:GetAttribute("VoiceSession") ~= sessionId then return end

        local fadeOut = TweenService:Create(quoteLbl, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            TextTransparency = 1
        })
        if quoteStroke then
            TweenService:Create(quoteStroke, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Transparency = 1
            }):Play()
        end
        fadeOut:Play()
        fadeOut.Completed:Wait()

        if char:GetAttribute("VoiceSession") ~= sessionId then return end

        quoteLbl.Text = ""
        quoteLbl.TextTransparency = 0
        if quoteStroke then
            quoteStroke.Transparency = 0
        end

        local isLongText = (#newText > 35)
        local charDelay = isLongText and 0.032 or 0.016

        for i = 1, #newText do
            if char:GetAttribute("VoiceSession") ~= sessionId then return end
            quoteLbl.Text = string.sub(newText, 1, i)
            task.wait(charDelay)
        end
    end)
end

local function showThoughtBubble(char, data, sessionId)
    local bb = getBillboard(char)
    if not bb then return end

    local vfxType = (data and data.vfxType) or "random"
    local isSong = (data and data.isSong) == true
    local isSadDeath = (data and data.isSadDeath) == true
    local isPreviewBeam = (data and data.isPreviewBeam) == true

    setHeadParticles(char, true, isSadDeath)

    if not VfxActivos and not isPreviewBeam then
        bb.Enabled = false
        return
    end

    local cloudRoot = bb:FindFirstChild("CloudRoot")
    if not cloudRoot then return end

    resetBubbleGeometry(cloudRoot)
    applyBeamTransformToAll()

    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if breachLayer then
        if isSadDeath then
            startProgressiveEnergyBreach(cloudRoot, sessionId, char)
        else
            breachLayer.Visible = false
        end
    end

    local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
    local borderLayer = shieldGroup and shieldGroup:FindFirstChild("BorderLayer")
    local borderGrad = borderLayer and borderLayer:FindFirstChild("BorderGrad")
    if borderGrad then
        if isSadDeath then
            borderGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(115, 185, 250)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(130, 110, 200)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(85, 135, 205))
            })
        else
            borderGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
                ColorSequenceKeypoint.new(0.28, COLOR_ROJO),
                ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
                ColorSequenceKeypoint.new(0.72, COLOR_ROJO),
                ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
            })
        end
    end

    local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
    local nameTextGroup = headerSig and headerSig:FindFirstChild("NameTextGroup")
    local shadowCyan = nameTextGroup and nameTextGroup:FindFirstChild("ShadowCyan")
    local shadowRed = nameTextGroup and nameTextGroup:FindFirstChild("ShadowRed")
    local headerLbl = nameTextGroup and nameTextGroup:FindFirstChild("HeaderLbl")

    local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    local musicWavesHolder = quoteBox and quoteBox:FindFirstChild("MusicWavesHolder")

    local fullText = (data and (data.quote or data.key)) or ""
    local heroName = ((data and data.hero) or "SPIDER-MAN"):upper()

    if headerLbl then headerLbl.Text = heroName end
    if shadowCyan then shadowCyan.Text = heroName end
    if shadowRed then shadowRed.Text = heroName end

    if activeBillboards[char] then
        for _, tw in ipairs(activeBillboards[char]) do
            if tw then tw:Cancel() end
        end
    end
    activeBillboards[char] = {}

    bb.Enabled = true
    bb.StudsOffset = Vector3.new(2.15, 1.90, 0)
    cloudRoot.Visible = true
    cloudRoot.Size = UDim2.new(0.12, 0, 0.12, 0)

    local targetOffset = isSadDeath and Vector3.new(2.55, 1.72, 0) or Vector3.new(2.55, 2.15, 0)

    local tOffset = TweenService:Create(bb, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        StudsOffset = targetOffset
    })
    local tPop = TweenService:Create(cloudRoot, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0)
    })

    table.insert(activeBillboards[char], tOffset)
    table.insert(activeBillboards[char], tPop)

    tOffset:Play()
    tPop:Play()

    if sessionId then
        startCaptionEffectsLoop(char, sessionId, vfxType, isSong, isSadDeath)
    end

    if quoteLbl and sessionId then
        local quoteStroke = quoteLbl:FindFirstChild("QuoteStroke") or quoteLbl:FindFirstChildOfClass("UIStroke")
        local textGrad = quoteLbl:FindFirstChild("TextLightGrad")

        if isSong then
            quoteLbl.Visible = false
            if musicWavesHolder then
                musicWavesHolder.Visible = true
            end
        else
            if musicWavesHolder then
                musicWavesHolder.Visible = false
            end
            quoteLbl.Visible = true
            quoteLbl.TextTransparency = 0
            if quoteStroke then
                quoteStroke.Transparency = 0
            end

            if isSadDeath then
                quoteLbl.Font = Enum.Font.SpecialElite
                if textGrad then
                    textGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(185, 225, 255)),
                        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(160, 145, 215)),
                        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 190, 245))
                    })
                end
            else
                quoteLbl.Font = Enum.Font.Bangers
                if textGrad then
                    textGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
                        ColorSequenceKeypoint.new(0.32, COLOR_ROJO),
                        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
                        ColorSequenceKeypoint.new(0.68, COLOR_ROJO),
                        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
                    })
                end
            end

            quoteLbl.Text = ""
            local isLongText = (#fullText > 35)
            local charDelay = isSadDeath and 0.045 or (isLongText and 0.032 or 0.015)

            task.spawn(function()
                for i = 1, #fullText do
                    if char:GetAttribute("VoiceSession") ~= sessionId then return end
                    if data and data.afterDelayQuote and quoteLbl.Text == data.afterDelayQuote then return end
                    quoteLbl.Text = string.sub(fullText, 1, i)
                    task.wait(charDelay)
                end
            end)
        end
    end
end

local function endVoicelineEffect(char, sessionId, forceHide)
    if not char then return end
    if not forceHide and char:GetAttribute("VoiceSession") ~= sessionId then return end

    activeCaptionLoops[char] = nil
    setHeadParticles(char, false)

    local bb = charBillboards[char]
    if bb and bb.Parent then
        local cloudRoot = bb:FindFirstChild("CloudRoot")
        if cloudRoot and cloudRoot.Visible then
            local shrink = TweenService:Create(cloudRoot, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0)
            })
            shrink:Play()
            shrink.Completed:Connect(function()
                if (forceHide or char:GetAttribute("VoiceSession") == sessionId) and bb and bb.Parent then
                    cloudRoot.Visible = false
                    bb.Enabled = false
                    resetBubbleGeometry(cloudRoot)
                end
            end)
        else
            bb.Enabled = false
        end
    end
end

-- ==========================================
-- SISTEMA DE AUDIO + GESTIÓN DE CANCIÓN E INTERFERENCIA
-- ==========================================
local cachedAudio = {}
local activeSong = nil

local function sanitizeUrl(url)
    if type(url) ~= "string" then return url end
    url = url:gsub("github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)", "raw.githubusercontent.com/%1/%2/%3/%4")
    return url
end

local function getAudioSource(rawSrc, cacheKey, srcType)
    if not rawSrc or rawSrc == "" then
        return nil
    end

    if srcType == "id" or tonumber(rawSrc) then
        return "rbxassetid://" .. tostring(rawSrc)
    end

    if cachedAudio[cacheKey] then
        return cachedAudio[cacheKey]
    end

    local finalUrl = sanitizeUrl(rawSrc)
    if not finalUrl:match("^https?://") then
        return nil
    end

    local hash = 0
    for i = 1, #finalUrl do
        hash = (hash * 31 + string.byte(finalUrl, i)) % 1000000007
    end

    local safeKey = tostring(cacheKey):gsub("[^%w_]", "")
    local fileName = "v6_spidey_" .. safeKey .. "_" .. tostring(hash) .. ".mp3"

    if not isfile(fileName) then
        local success, err = pcall(function()
            writefile(fileName, game:HttpGet(finalUrl))
        end)
        if not success then
            warn("Error descargando audio: " .. tostring(err))
            return finalUrl
        end
    end

    local asset = getasset(fileName)
    cachedAudio[cacheKey] = asset
    return asset
end

local function stopActiveSong(withFade)
    if not activeSong then return end
    local songObj = activeSong
    activeSong = nil
    songObj.stopping = true

    local s = songObj.sound
    if s and s.Parent then
        if withFade then
            TweenService:Create(s, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = 0}):Play()
            task.delay(0.7, function()
                if s and s.Parent then s:Destroy() end
            end)
        else
            s:Destroy()
        end
    end

    if songObj.char and songObj.sessionId then
        endVoicelineEffect(songObj.char, songObj.sessionId)
    end
end

local function beginSongInterference()
    if not activeSong or activeSong.stopping then return end
    local songObj = activeSong
    songObj.interrupts = (songObj.interrupts or 0) + 1
    if songObj.interrupts > 1 then return end

    local s = songObj.sound
    if not s or not s.Parent then return end

    task.spawn(function()
        local baseVol = VolumeData[songObj.data.key] or songObj.data.defVol
        local flickers = {baseVol * 0.25, 0, baseVol * 0.4, 0}
        for _, v in ipairs(flickers) do
            if not activeSong or activeSong ~= songObj or songObj.stopping or (songObj.interrupts or 0) <= 0 then
                return
            end
            if s and s.Parent then
                s.Volume = v
            end
            task.wait(0.045)
        end
        if activeSong == songObj and not songObj.stopping and (songObj.interrupts or 0) > 0 and s and s.Parent then
            pcall(function() s:Pause() end)
        end
    end)
end

local function endSongInterference()
    if not activeSong or activeSong.stopping then return end
    local songObj = activeSong
    songObj.interrupts = math.max(0, (songObj.interrupts or 1) - 1)
    if songObj.interrupts > 0 then return end

    local s = songObj.sound
    if not s or not s.Parent then return end

    if songObj.char and songObj.sessionId then
        songObj.char:SetAttribute("VoiceSession", songObj.sessionId)
        showThoughtBubble(songObj.char, songObj.data, songObj.sessionId)
    end

    task.spawn(function()
        local targetVol = VolumeData[songObj.data.key] or songObj.data.defVol
        pcall(function() s:Resume() end)
        local flickers = {0, targetVol * 0.35, targetVol * 0.1, targetVol * 0.65}
        for _, v in ipairs(flickers) do
            if activeSong ~= songObj or songObj.stopping or (songObj.interrupts or 0) > 0 then
                return
            end
            if s and s.Parent then
                s.Volume = v
            end
            task.wait(0.045)
        end
        if activeSong == songObj and not songObj.stopping and (songObj.interrupts or 0) == 0 and s and s.Parent then
            TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Volume = targetVol}):Play()
        end
    end)
end

local function playSound(data, preview, char, track)
    if not VoicelinesActivas and not preview then return end

    if data.isSong then
        if activeSong then
            if preview then
                stopActiveSong(true)
            end
            return
        end

        local src = getAudioSource(data.src, data.key .. "_song", data.type)
        if not src then return end

        local targetVol = VolumeData[data.key] or data.defVol
        local s = Instance.new("Sound")
        s.SoundId = src
        s.Volume = 0
        s.Looped = true
        s:SetAttribute("IsCustomVoice", true)
        s.Parent = preview and CoreGui or player:WaitForChild("PlayerGui")

        local sessionId = tick()
        local songObj = {
            sound = s,
            data = data,
            char = char,
            sessionId = sessionId,
            interrupts = 0,
            stopping = false
        }
        activeSong = songObj

        if char then
            char:SetAttribute("VoiceSession", sessionId)
            showThoughtBubble(char, data, sessionId)
        end

        s:Play()
        TweenService:Create(s, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = targetVol
        }):Play()

        s.Ended:Connect(function()
            if activeSong == songObj then
                stopActiveSong(false)
            end
        end)
        return
    end

    if data.isSadDeath and activeSong then
        stopActiveSong(false)
    end

    local src1 = getAudioSource(data.src, data.key .. "_1", data.type)
    if not src1 then return end

    local targetVol = VolumeData[data.key] or data.defVol
    local primaryVol = targetVol * (data.primaryVolFactor or 1)

    local causedInterference = false
    if not data.isSadDeath and activeSong and not activeSong.stopping then
        causedInterference = true
        beginSongInterference()
    end

    local parentContainer = (preview or data.isSadDeath) and CoreGui or player:WaitForChild("PlayerGui")

    local s1 = Instance.new("Sound")
    s1.SoundId = src1
    s1.Volume = data.fade and 0 or primaryVol
    s1:SetAttribute("IsCustomVoice", true)
    s1.Parent = parentContainer

    local sessionId = tick()
    if char then
        char:SetAttribute("VoiceSession", sessionId)
        showThoughtBubble(char, data, sessionId)
    end

    s1:Play()
    if data.fade then
        TweenService:Create(s1, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Volume = primaryVol}):Play()
    end

    local sExtra = nil
    if data.extraUrl then
        local srcExtra = getAudioSource(data.extraUrl, data.key .. "_extra", "url")
        if srcExtra then
            sExtra = Instance.new("Sound")
            sExtra.SoundId = srcExtra
            sExtra.Volume = targetVol * (data.extraVolFactor or 0.8)
            sExtra:SetAttribute("IsCustomVoice", true)
            sExtra.Parent = parentContainer
            sExtra:Play()
        end
    end

    local s2 = nil
    local cleaned = false

    if data.afterDelayQuote and char then
        local delaySec = data.afterDelayTime or 3
        task.delay(delaySec, function()
            if cleaned or not char or not char.Parent then return end
            if char:GetAttribute("VoiceSession") ~= sessionId then return end
            local bb = charBillboards[char]
            local cloudRoot = bb and bb:FindFirstChild("CloudRoot")
            local safeTextZone = cloudRoot and cloudRoot:FindFirstChild("SafeTextZone")
            local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
            local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
            if quoteLbl then
                quoteLbl.TextTransparency = 0
                quoteLbl.Text = data.afterDelayQuote
            end
        end)
    end

    local function cleanup()
        if cleaned then return end
        cleaned = true

        if s1 and s1.Parent then s1:Destroy() end
        if s2 and s2.Parent then s2:Destroy() end
        if sExtra and sExtra.Parent then sExtra:Destroy() end

        if causedInterference then
            endSongInterference()
        elseif char then
            endVoicelineEffect(char, sessionId)
        end
    end

    if data.nextSrc then
        local src2 = getAudioSource(data.nextSrc, data.key .. "_2", "url")
        s1.Ended:Connect(function()
            if cleaned then return end
            if s1 and s1.Parent then s1:Destroy() end

            if data.nextQuote and char then
                transitionBubbleQuote(char, sessionId, data.nextQuote)
            end

            if src2 then
                s2 = Instance.new("Sound")
                s2.SoundId = src2
                s2.Volume = targetVol
                s2:SetAttribute("IsCustomVoice", true)
                s2.Parent = parentContainer
                s2:Play()
                s2.Ended:Connect(cleanup)
            else
                cleanup()
            end
        end)
    else
        s1.Ended:Connect(cleanup)
    end

    task.delay(25, cleanup)
end

-- ==========================================
-- GUI PREMIUM CON 3 PESTAÑAS (SPIDER-MAN / COLOR GLOB / AJUSTAR RAYA)
-- ==========================================
if CoreGui:FindFirstChild("OmegaPremiumUI") then CoreGui.OmegaPremiumUI:Destroy() end

local ui = Instance.new("ScreenGui")
ui.Name = "OmegaPremiumUI"
ui.Parent = CoreGui
ui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 615)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -307)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = ui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = COLOR_CELESTE
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

mainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 480, 0, 615)
}):Play()

task.spawn(function()
    while task.wait() do
        if not mainFrame or not mainFrame.Parent then break end
        local idx = (math.floor(tick() * 1.2) % #GLOBAL_PALETTE) + 1
        mainStroke.Color = GLOBAL_PALETTE[idx]
    end
end)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.Active = true
topBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 236, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "SPIDER-MAN VOICELINES"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local titleGrad = Instance.new("UIGradient", title)
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLOR_CELESTE),
    ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
    ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
})

local vfxBtn = Instance.new("TextButton")
vfxBtn.Size = UDim2.new(0, 58, 0, 24)
vfxBtn.Position = UDim2.new(1, -216, 0.5, -12)
vfxBtn.BackgroundColor3 = VfxActivos and Color3.fromRGB(70, 110, 240) or Color3.fromRGB(45, 45, 55)
vfxBtn.Text = VfxActivos and "VFX: ON" or "VFX: OFF"
vfxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
vfxBtn.Font = Enum.Font.GothamBold
vfxBtn.TextSize = 10
vfxBtn.Parent = topBar
Instance.new("UICorner", vfxBtn).CornerRadius = UDim.new(1, 0)

vfxBtn.MouseButton1Click:Connect(function()
    VfxActivos = not VfxActivos
    vfxBtn.Text = VfxActivos and "VFX: ON" or "VFX: OFF"
    TweenService:Create(vfxBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = VfxActivos and Color3.fromRGB(70, 110, 240) or Color3.fromRGB(45, 45, 55)
    }):Play()
    if not VfxActivos and player.Character then
        setHeadParticles(player.Character, false)
        local bb = charBillboards[player.Character]
        if bb then bb.Enabled = false end
    end
    saveConfig()
end)

local switchBg = Instance.new("Frame")
switchBg.Size = UDim2.new(0, 46, 0, 24)
switchBg.Position = UDim2.new(1, -148, 0.5, -12)
switchBg.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
switchBg.Parent = topBar
Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

local switchKnob = Instance.new("Frame")
switchKnob.Size = UDim2.new(0, 20, 0, 20)
switchKnob.Position = UDim2.new(1, -22, 0.5, -10)
switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
switchKnob.Parent = switchBg
Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)
local knobStroke = Instance.new("UIStroke", switchKnob)
knobStroke.Color = Color3.fromRGB(0, 0, 0)
knobStroke.Transparency = 0.8

local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.new(1, 0, 1, 0)
switchBtn.BackgroundTransparency = 1
switchBtn.Text = ""
switchBtn.Parent = switchBg

switchBtn.MouseButton1Click:Connect(function()
    VoicelinesActivas = not VoicelinesActivas
    if VoicelinesActivas then
        TweenService:Create(switchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 220, 120)}):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(1, -22, 0.5, -10)}):Play()
    else
        TweenService:Create(switchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 2, 0.5, -10)}):Play()
        stopActiveSong(false)
    end
end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 40, 1, 0)
minBtn.Position = UDim2.new(1, -90, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 1, 0)
closeBtn.Position = UDim2.new(1, -45, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 24
closeBtn.Parent = topBar

local dragToggle, dragInput, dragStart, startPos
local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

topBar.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragToggle = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragToggle = false end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragToggle then updateInput(input) end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = minimized and UDim2.new(0, 480, 0, 52) or UDim2.new(0, 480, 0, 615)
    }):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    stopActiveSong(false)
    local tw = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
    tw:Play()
    tw.Completed:Connect(function() ui:Destroy() end)
end)

-- ==========================================
-- BARRA DE PESTAÑAS (SPIDER-MAN / COLOR GLOB / AJUSTAR RAYA)
-- ==========================================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -30, 0, 38)
tabBar.Position = UDim2.new(0, 15, 0, 54)
tabBar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
tabBar.Parent = mainFrame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 10)

local tabStroke = Instance.new("UIStroke", tabBar)
tabStroke.Color = Color3.fromRGB(45, 45, 60)
tabStroke.Thickness = 1

local function createTabButton(text, posScale, widthScale, textSize)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(widthScale, -4, 1, -6)
    btn.Position = UDim2.new(posScale, 2, 0, 3)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = textSize or 11
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local spideyTabBtn = createTabButton("SPIDER-MAN", 0, 0.32, 11)
local colorGlobTabBtn = createTabButton("COLOR GLOB", 0.32, 0.34, 11)
local beamAdjustTabBtn = createTabButton("AJUSTAR RAYA", 0.66, 0.34, 11)

local function createScrollContainer()
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, -30, 1, -108)
    sc.Position = UDim2.new(0, 15, 0, 100)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 4
    sc.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
    sc.Parent = mainFrame

    local ly = Instance.new("UIListLayout", sc)
    ly.Padding = UDim.new(0, 12)
    ly.SortOrder = Enum.SortOrder.LayoutOrder

    RunService.RenderStepped:Connect(function()
        if sc and sc.Parent then
            sc.CanvasSize = UDim2.new(0, 0, 0, ly.AbsoluteContentSize.Y + 20)
        end
    end)
    return sc
end

local spideyScroll = createScrollContainer()

local colorGlobContainer = Instance.new("Frame")
colorGlobContainer.Name = "ColorGlobChangerTab"
colorGlobContainer.Size = UDim2.new(1, -30, 1, -108)
colorGlobContainer.Position = UDim2.new(0, 15, 0, 100)
colorGlobContainer.BackgroundTransparency = 1
colorGlobContainer.Visible = false
colorGlobContainer.Parent = mainFrame

local beamAdjustContainer = Instance.new("Frame")
beamAdjustContainer.Name = "BeamAdjustTab"
beamAdjustContainer.Size = UDim2.new(1, -30, 1, -108)
beamAdjustContainer.Position = UDim2.new(0, 15, 0, 100)
beamAdjustContainer.BackgroundTransparency = 1
beamAdjustContainer.Visible = false
beamAdjustContainer.Parent = mainFrame

local function selectTab(tabName)
    local isSpidey = (tabName == "Spidey")
    local isColorGlob = (tabName == "ColorGlob")
    local isBeamAdjust = (tabName == "BeamAdjust")

    spideyScroll.Visible = isSpidey
    colorGlobContainer.Visible = isColorGlob
    beamAdjustContainer.Visible = isBeamAdjust

    TweenService:Create(spideyTabBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = isSpidey and Color3.fromRGB(215, 45, 65) or Color3.fromRGB(18, 18, 25),
        TextColor3 = isSpidey and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 175)
    }):Play()

    TweenService:Create(colorGlobTabBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = isColorGlob and Color3.fromRGB(65, 155, 235) or Color3.fromRGB(18, 18, 25),
        TextColor3 = isColorGlob and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 175)
    }):Play()

    TweenService:Create(beamAdjustTabBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = isBeamAdjust and Color3.fromRGB(145, 85, 235) or Color3.fromRGB(18, 18, 25),
        TextColor3 = isBeamAdjust and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 175)
    }):Play()
end

spideyTabBtn.MouseButton1Click:Connect(function() selectTab("Spidey") end)
colorGlobTabBtn.MouseButton1Click:Connect(function() selectTab("ColorGlob") end)
beamAdjustTabBtn.MouseButton1Click:Connect(function() selectTab("BeamAdjust") end)
selectTab("Spidey")

local copyToClipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)

-- ==========================================
-- CONTENIDO DE LA PESTAÑA: AJUSTAR RAYA
-- ==========================================
local beamPreviewActive = false
local beamPreviewSessionId = nil
local moveStep = 0.015

local topActionCard = Instance.new("Frame")
topActionCard.Size = UDim2.new(1, -6, 0, 74)
topActionCard.Position = UDim2.new(0, 3, 0, 2)
topActionCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
topActionCard.Parent = beamAdjustContainer
Instance.new("UICorner", topActionCard).CornerRadius = UDim.new(0, 12)

local topActionStroke = Instance.new("UIStroke", topActionCard)
topActionStroke.Color = Color3.fromRGB(45, 48, 66)
topActionStroke.Thickness = 1

local topActionHeader = Instance.new("TextLabel")
topActionHeader.Size = UDim2.new(1, -24, 0, 18)
topActionHeader.Position = UDim2.new(0, 12, 0, 7)
topActionHeader.BackgroundTransparency = 1
topActionHeader.Text = "VISTA PREVIA DEL GLOBO Y EXPORTAR"
topActionHeader.TextColor3 = Color3.fromRGB(185, 195, 220)
topActionHeader.Font = Enum.Font.GothamBlack
topActionHeader.TextSize = 11
topActionHeader.TextXAlignment = Enum.TextXAlignment.Left
topActionHeader.Parent = topActionCard

local toggleGlobeBtn = Instance.new("TextButton")
toggleGlobeBtn.Size = UDim2.new(0.56, -16, 0, 34)
toggleGlobeBtn.Position = UDim2.new(0, 12, 0, 30)
toggleGlobeBtn.BackgroundColor3 = Color3.fromRGB(55, 130, 230)
toggleGlobeBtn.Text = "VER GLOBO"
toggleGlobeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGlobeBtn.Font = Enum.Font.GothamBlack
toggleGlobeBtn.TextSize = 12
toggleGlobeBtn.Parent = topActionCard
Instance.new("UICorner", toggleGlobeBtn).CornerRadius = UDim.new(0, 8)

local copyBeamBtn = Instance.new("TextButton")
copyBeamBtn.Size = UDim2.new(0.44, -16, 0, 34)
copyBeamBtn.Position = UDim2.new(0.56, 4, 0, 30)
copyBeamBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
copyBeamBtn.Text = "COPIAR"
copyBeamBtn.TextColor3 = Color3.fromRGB(220, 230, 255)
copyBeamBtn.Font = Enum.Font.GothamBlack
copyBeamBtn.TextSize = 12
copyBeamBtn.Parent = topActionCard
Instance.new("UICorner", copyBeamBtn).CornerRadius = UDim.new(0, 8)

local copyBeamStroke = Instance.new("UIStroke", copyBeamBtn)
copyBeamStroke.Color = COLOR_CELESTE
copyBeamStroke.Thickness = 1
copyBeamStroke.Transparency = 0.55

local function setPreviewState(active)
    local char = player.Character
    if active and char then
        beamPreviewActive = true
        beamPreviewSessionId = tick()
        char:SetAttribute("VoiceSession", beamPreviewSessionId)
        toggleGlobeBtn.Text = "QUITAR GLOBO"
        TweenService:Create(toggleGlobeBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(215, 45, 65)
        }):Play()
        showThoughtBubble(char, {
            hero = "Spider-Man",
            quote = "Ajustando la raya...",
            vfxType = "response",
            isPreviewBeam = true
        }, beamPreviewSessionId)
    else
        beamPreviewActive = false
        toggleGlobeBtn.Text = "VER GLOBO"
        TweenService:Create(toggleGlobeBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(55, 130, 230)
        }):Play()
        if char then
            endVoicelineEffect(char, beamPreviewSessionId, true)
        end
        beamPreviewSessionId = nil
    end
end

toggleGlobeBtn.MouseButton1Click:Connect(function()
    setPreviewState(not beamPreviewActive)
end)

copyBeamBtn.MouseButton1Click:Connect(function()
    local exportText = string.format(
        "underlineBeam.Position = UDim2.new(%.4f, 0, %.4f, 0)\nunderlineBeam.Size = UDim2.new(%.4f, 0, %.4f, 0)",
        BeamPosX, BeamPosY, BeamSizeX, BeamSizeY
    )
    if copyToClipboard then
        pcall(copyToClipboard, exportText)
    end
    copyBeamBtn.Text = "¡COPIADO!"
    TweenService:Create(copyBeamBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(45, 155, 95)
    }):Play()
    task.delay(1.2, function()
        if copyBeamBtn and copyBeamBtn.Parent then
            copyBeamBtn.Text = "COPIAR"
            TweenService:Create(copyBeamBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(36, 38, 52)
            }):Play()
        end
    end)
end)

-- Tarjeta de coordenadas en vivo + selector de velocidad/paso
local statusStepCard = Instance.new("Frame")
statusStepCard.Size = UDim2.new(1, -6, 0, 68)
statusStepCard.Position = UDim2.new(0, 3, 0, 84)
statusStepCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
statusStepCard.Parent = beamAdjustContainer
Instance.new("UICorner", statusStepCard).CornerRadius = UDim.new(0, 12)

local statusStepStroke = Instance.new("UIStroke", statusStepCard)
statusStepStroke.Color = Color3.fromRGB(40, 42, 56)
statusStepStroke.Thickness = 1

local coordsReadoutLbl = Instance.new("TextLabel")
coordsReadoutLbl.Size = UDim2.new(1, -20, 0, 20)
coordsReadoutLbl.Position = UDim2.new(0, 10, 0, 8)
coordsReadoutLbl.BackgroundTransparency = 1
coordsReadoutLbl.TextColor3 = COLOR_CELESTE
coordsReadoutLbl.Font = Enum.Font.GothamBold
coordsReadoutLbl.TextSize = 11
coordsReadoutLbl.TextXAlignment = Enum.TextXAlignment.Center
coordsReadoutLbl.Parent = statusStepCard

local stepTitleLbl = Instance.new("TextLabel")
stepTitleLbl.Size = UDim2.new(0, 95, 0, 24)
stepTitleLbl.Position = UDim2.new(0, 12, 0, 34)
stepTitleLbl.BackgroundTransparency = 1
stepTitleLbl.Text = "PRECISIÓN:"
stepTitleLbl.TextColor3 = Color3.fromRGB(165, 175, 200)
stepTitleLbl.Font = Enum.Font.GothamBlack
stepTitleLbl.TextSize = 10
stepTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
stepTitleLbl.Parent = statusStepCard

local stepOptions = {
    {label = "FINO (0.005)", val = 0.005},
    {label = "MEDIO (0.015)", val = 0.015},
    {label = "RÁPIDO (0.04)", val = 0.040}
}
local stepBtns = {}

local function updateStepButtonsUI()
    for _, item in ipairs(stepOptions) do
        local b = stepBtns[item.val]
        if b then
            local active = (math.abs(moveStep - item.val) < 0.0001)
            b.BackgroundColor3 = active and Color3.fromRGB(145, 85, 235) or Color3.fromRGB(30, 30, 42)
            b.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(165, 175, 200)
        end
    end
end

for idx, item in ipairs(stepOptions) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(0, 104, 0, 24)
    sBtn.Position = UDim2.new(0, 106 + (idx - 1) * 110, 0, 34)
    sBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    sBtn.Text = item.label
    sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 10
    sBtn.Parent = statusStepCard
    Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 7)

    stepBtns[item.val] = sBtn
    sBtn.MouseButton1Click:Connect(function()
        moveStep = item.val
        updateStepButtonsUI()
    end)
end
updateStepButtonsUI()

-- Tarjeta de cruceta con flechas para mover la raya
local dpadCard = Instance.new("Frame")
dpadCard.Size = UDim2.new(1, -6, 0, 154)
dpadCard.Position = UDim2.new(0, 3, 0, 160)
dpadCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
dpadCard.Parent = beamAdjustContainer
Instance.new("UICorner", dpadCard).CornerRadius = UDim.new(0, 12)

local dpadStroke = Instance.new("UIStroke", dpadCard)
dpadStroke.Color = Color3.fromRGB(40, 42, 56)
dpadStroke.Thickness = 1

local dpadHeader = Instance.new("TextLabel")
dpadHeader.Size = UDim2.new(1, -24, 0, 18)
dpadHeader.Position = UDim2.new(0, 12, 0, 8)
dpadHeader.BackgroundTransparency = 1
dpadHeader.Text = "MOVER POSICIÓN CON FLECHAS"
dpadHeader.TextColor3 = Color3.fromRGB(185, 195, 220)
dpadHeader.Font = Enum.Font.GothamBlack
dpadHeader.TextSize = 11
dpadHeader.TextXAlignment = Enum.TextXAlignment.Left
dpadHeader.Parent = dpadCard

local widthValueLbl, heightValueLbl, widthSliderFill, heightSliderFill

local function syncBeamUIAndApply()
    BeamPosX = math.clamp(math.floor(BeamPosX * 10000 + 0.5) / 10000, -1.5, 2.5)
    BeamPosY = math.clamp(math.floor(BeamPosY * 10000 + 0.5) / 10000, -1.5, 2.5)
    BeamSizeX = math.clamp(math.floor(BeamSizeX * 10000 + 0.5) / 10000, 0.05, 2.5)
    BeamSizeY = math.clamp(math.floor(BeamSizeY * 10000 + 0.5) / 10000, 0.05, 2.5)

    coordsReadoutLbl.Text = string.format(
        "POS: X %.4f, Y %.4f   |   TAMAÑO: ANCHO %.4f, ALTO %.4f",
        BeamPosX, BeamPosY, BeamSizeX, BeamSizeY
    )

    if widthValueLbl then widthValueLbl.Text = string.format("%.4f", BeamSizeX) end
    if heightValueLbl then heightValueLbl.Text = string.format("%.4f", BeamSizeY) end
    if widthSliderFill then
        widthSliderFill.Size = UDim2.new(math.clamp((BeamSizeX - 0.05) / 1.95, 0, 1), 0, 1, 0)
    end
    if heightSliderFill then
        heightSliderFill.Size = UDim2.new(math.clamp((BeamSizeY - 0.05) / 2.45, 0, 1), 0, 1, 0)
    end

    applyBeamTransformToAll()
    saveConfig()
end

local function bindHoldRepeatButton(btn, actionFn)
    local holding = false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = true
            actionFn()
            task.spawn(function()
                task.wait(0.32)
                while holding and btn and btn.Parent do
                    actionFn()
                    task.wait(0.06)
                end
            end)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = false
        end
    end)
    btn.MouseLeave:Connect(function()
        holding = false
    end)
end

local function createArrowBtn(symbol, offsetX, posY, isReset)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0)
    b.Size = UDim2.new(0, 62, 0, 34)
    b.Position = UDim2.new(0.5, offsetX, 0, posY)
    b.BackgroundColor3 = isReset and Color3.fromRGB(45, 32, 48) or Color3.fromRGB(32, 34, 48)
    b.Text = symbol
    b.TextColor3 = isReset and Color3.fromRGB(255, 160, 180) or Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBlack
    b.TextSize = isReset and 11 or 16
    b.Parent = dpadCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    local st = Instance.new("UIStroke", b)
    st.Color = isReset and COLOR_ROJO or COLOR_CELESTE
    st.Thickness = 1
    st.Transparency = 0.65
    return b
end

local upArrowBtn = createArrowBtn("▲", 0, 30, false)
local leftArrowBtn = createArrowBtn("◄", -68, 70, false)
local centerResetPosBtn = createArrowBtn("CENTRO", 0, 70, true)
local rightArrowBtn = createArrowBtn("►", 68, 70, false)
local downArrowBtn = createArrowBtn("▼", 0, 110, false)

bindHoldRepeatButton(upArrowBtn, function()
    BeamPosY = BeamPosY - moveStep
    syncBeamUIAndApply()
end)

bindHoldRepeatButton(downArrowBtn, function()
    BeamPosY = BeamPosY + moveStep
    syncBeamUIAndApply()
end)

bindHoldRepeatButton(leftArrowBtn, function()
    BeamPosX = BeamPosX - moveStep
    syncBeamUIAndApply()
end)

bindHoldRepeatButton(rightArrowBtn, function()
    BeamPosX = BeamPosX + moveStep
    syncBeamUIAndApply()
end)

centerResetPosBtn.MouseButton1Click:Connect(function()
    BeamPosX = DEFAULT_BEAM_POS_X
    BeamPosY = DEFAULT_BEAM_POS_Y
    syncBeamUIAndApply()
end)

-- Tarjeta de tamaño (Ancho y Alto)
local sizeCard = Instance.new("Frame")
sizeCard.Size = UDim2.new(1, -6, 0, 178)
sizeCard.Position = UDim2.new(0, 3, 0, 322)
sizeCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
sizeCard.Parent = beamAdjustContainer
Instance.new("UICorner", sizeCard).CornerRadius = UDim.new(0, 12)

local sizeCardStroke = Instance.new("UIStroke", sizeCard)
sizeCardStroke.Color = Color3.fromRGB(40, 42, 56)
sizeCardStroke.Thickness = 1

local sizeCardHeader = Instance.new("TextLabel")
sizeCardHeader.Size = UDim2.new(0.6, 0, 0, 18)
sizeCardHeader.Position = UDim2.new(0, 12, 0, 8)
sizeCardHeader.BackgroundTransparency = 1
sizeCardHeader.Text = "AJUSTAR TAMAÑO DE LA RAYA"
sizeCardHeader.TextColor3 = Color3.fromRGB(185, 195, 220)
sizeCardHeader.Font = Enum.Font.GothamBlack
sizeCardHeader.TextSize = 11
sizeCardHeader.TextXAlignment = Enum.TextXAlignment.Left
sizeCardHeader.Parent = sizeCard

local resetAllBeamBtn = Instance.new("TextButton")
resetAllBeamBtn.Size = UDim2.new(0, 102, 0, 22)
resetAllBeamBtn.Position = UDim2.new(1, -114, 0, 6)
resetAllBeamBtn.BackgroundColor3 = Color3.fromRGB(48, 30, 42)
resetAllBeamBtn.Text = "RESET TODO"
resetAllBeamBtn.TextColor3 = Color3.fromRGB(255, 150, 165)
resetAllBeamBtn.Font = Enum.Font.GothamBlack
resetAllBeamBtn.TextSize = 10
resetAllBeamBtn.Parent = sizeCard
Instance.new("UICorner", resetAllBeamBtn).CornerRadius = UDim.new(0, 6)

resetAllBeamBtn.MouseButton1Click:Connect(function()
    BeamPosX = DEFAULT_BEAM_POS_X
    BeamPosY = DEFAULT_BEAM_POS_Y
    BeamSizeX = DEFAULT_BEAM_SIZE_X
    BeamSizeY = DEFAULT_BEAM_SIZE_Y
    syncBeamUIAndApply()
end)

local function buildDimensionControl(labelText, posY, minVal, maxVal, getVal, setVal)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -24, 0, 62)
    holder.Position = UDim2.new(0, 12, 0, posY)
    holder.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    holder.Parent = sizeCard
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 9)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 130, 0, 26)
    lbl.Position = UDim2.new(0, 10, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(235, 240, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 34, 0, 26)
    minusBtn.Position = UDim2.new(1, -158, 0, 6)
    minusBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 48)
    minusBtn.Text = "-"
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.Font = Enum.Font.GothamBlack
    minusBtn.TextSize = 16
    minusBtn.Parent = holder
    Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 6)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 74, 0, 26)
    valLbl.Position = UDim2.new(1, -120, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = string.format("%.4f", getVal())
    valLbl.TextColor3 = COLOR_CELESTE
    valLbl.Font = Enum.Font.GothamBlack
    valLbl.TextSize = 12
    valLbl.Parent = holder

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 34, 0, 26)
    plusBtn.Position = UDim2.new(1, -42, 0, 6)
    plusBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 48)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.Font = Enum.Font.GothamBlack
    plusBtn.TextSize = 16
    plusBtn.Parent = holder
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 6)

    local sBg = Instance.new("Frame")
    sBg.Size = UDim2.new(1, -20, 0, 12)
    sBg.Position = UDim2.new(0, 10, 0, 40)
    sBg.BackgroundColor3 = Color3.fromRGB(9, 9, 13)
    sBg.Parent = holder
    Instance.new("UICorner", sBg).CornerRadius = UDim.new(1, 0)

    local sFill = Instance.new("Frame")
    sFill.Size = UDim2.new(math.clamp((getVal() - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    sFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sFill.Parent = sBg
    Instance.new("UICorner", sFill).CornerRadius = UDim.new(1, 0)

    local sGrad = Instance.new("UIGradient", sFill)
    sGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
        ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
    })

    bindHoldRepeatButton(minusBtn, function()
        setVal(getVal() - moveStep)
        syncBeamUIAndApply()
    end)

    bindHoldRepeatButton(plusBtn, function()
        setVal(getVal() + moveStep)
        syncBeamUIAndApply()
    end)

    local draggingDim = false
    local function updateFromBar(input)
        local relX = math.clamp((input.Position.X - sBg.AbsolutePosition.X) / sBg.AbsoluteSize.X, 0, 1)
        setVal(minVal + relX * (maxVal - minVal))
        syncBeamUIAndApply()
    end

    sBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingDim = true
            updateFromBar(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingDim and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromBar(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingDim = false
        end
    end)

    return valLbl, sFill
end

widthValueLbl, widthSliderFill = buildDimensionControl(
    "ANCHO (X)",
    36,
    0.05,
    2.00,
    function() return BeamSizeX end,
    function(v) BeamSizeX = v end
)

heightValueLbl, heightSliderFill = buildDimensionControl(
    "ALTO (Y)",
    106,
    0.05,
    2.50,
    function() return BeamSizeY end,
    function(v) BeamSizeY = v end
)

syncBeamUIAndApply()

-- ==========================================
-- CONTENIDO DE LA PESTAÑA: COLOR GLOB CHANGER
-- ==========================================
local inputCard = Instance.new("Frame")
inputCard.Size = UDim2.new(1, -6, 0, 106)
inputCard.Position = UDim2.new(0, 3, 0, 2)
inputCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
inputCard.Parent = colorGlobContainer
Instance.new("UICorner", inputCard).CornerRadius = UDim.new(0, 12)

local inputCardStroke = Instance.new("UIStroke", inputCard)
inputCardStroke.Color = Color3.fromRGB(40, 40, 50)
inputCardStroke.Thickness = 1

local inputHeaderLbl = Instance.new("TextLabel")
inputHeaderLbl.Size = UDim2.new(1, -24, 0, 20)
inputHeaderLbl.Position = UDim2.new(0, 12, 0, 8)
inputHeaderLbl.BackgroundTransparency = 1
inputHeaderLbl.Text = "COLOR INTERIOR DEL GLOBO (HEX)"
inputHeaderLbl.TextColor3 = Color3.fromRGB(185, 195, 220)
inputHeaderLbl.Font = Enum.Font.GothamBlack
inputHeaderLbl.TextSize = 11
inputHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
inputHeaderLbl.Parent = inputCard

local hexInput = Instance.new("TextBox")
hexInput.Size = UDim2.new(1, -72, 0, 34)
hexInput.Position = UDim2.new(0, 12, 0, 31)
hexInput.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
hexInput.PlaceholderText = "#B4C0CD"
hexInput.PlaceholderColor3 = Color3.fromRGB(115, 120, 140)
hexInput.Text = CustomGlobeHex or ""
hexInput.TextColor3 = Color3.fromRGB(255, 255, 255)
hexInput.Font = Enum.Font.GothamBold
hexInput.TextSize = 14
hexInput.ClearTextOnFocus = false
hexInput.Parent = inputCard
Instance.new("UICorner", hexInput).CornerRadius = UDim.new(0, 8)

local hexInputStroke = Instance.new("UIStroke", hexInput)
hexInputStroke.Color = Color3.fromRGB(48, 52, 70)
hexInputStroke.Thickness = 1

local previewSwatch = Instance.new("Frame")
previewSwatch.Name = "PreviewSwatch"
previewSwatch.Size = UDim2.new(0, 40, 0, 34)
previewSwatch.Position = UDim2.new(1, -52, 0, 31)
previewSwatch.BackgroundColor3 = CustomGlobeColor or Color3.fromRGB(180, 192, 205)
previewSwatch.BorderSizePixel = 0
previewSwatch.Parent = inputCard
Instance.new("UICorner", previewSwatch).CornerRadius = UDim.new(0, 8)

local swatchStroke = Instance.new("UIStroke", previewSwatch)
swatchStroke.Color = Color3.fromRGB(255, 255, 255)
swatchStroke.Thickness = 1.2
swatchStroke.Transparency = 0.4

hexInput:GetPropertyChangedSignal("Text"):Connect(function()
    local col = parseHexColor(hexInput.Text)
    if col then
        previewSwatch.BackgroundColor3 = col
    end
end)

local applyGlobBtn = Instance.new("TextButton")
applyGlobBtn.Size = UDim2.new(0.5, -16, 0, 28)
applyGlobBtn.Position = UDim2.new(0, 12, 0, 71)
applyGlobBtn.BackgroundColor3 = Color3.fromRGB(65, 115, 240)
applyGlobBtn.Text = "APLICAR"
applyGlobBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
applyGlobBtn.Font = Enum.Font.GothamBlack
applyGlobBtn.TextSize = 11
applyGlobBtn.Parent = inputCard
Instance.new("UICorner", applyGlobBtn).CornerRadius = UDim.new(0, 8)

local saveGlobBtn = Instance.new("TextButton")
saveGlobBtn.Size = UDim2.new(0.5, -16, 0, 28)
saveGlobBtn.Position = UDim2.new(0.5, 4, 0, 71)
saveGlobBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
saveGlobBtn.Text = "+ GUARDAR EN LISTA"
saveGlobBtn.TextColor3 = Color3.fromRGB(220, 225, 245)
saveGlobBtn.Font = Enum.Font.GothamBlack
saveGlobBtn.TextSize = 11
saveGlobBtn.Parent = inputCard
Instance.new("UICorner", saveGlobBtn).CornerRadius = UDim.new(0, 8)

local activeCard = Instance.new("Frame")
activeCard.Size = UDim2.new(1, -6, 0, 72)
activeCard.Position = UDim2.new(0, 3, 0, 116)
activeCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
activeCard.Parent = colorGlobContainer
Instance.new("UICorner", activeCard).CornerRadius = UDim.new(0, 12)

local activeCardStroke = Instance.new("UIStroke", activeCard)
activeCardStroke.Color = Color3.fromRGB(45, 48, 66)
activeCardStroke.Thickness = 1

local activeSwatch = Instance.new("Frame")
activeSwatch.Size = UDim2.new(0, 44, 0, 44)
activeSwatch.Position = UDim2.new(0, 12, 0.5, -22)
activeSwatch.BackgroundColor3 = CustomGlobeColor or SHIELD_MID_BLUE
activeSwatch.BorderSizePixel = 0
activeSwatch.Parent = activeCard
Instance.new("UICorner", activeSwatch).CornerRadius = UDim.new(0, 9)

local activeSwatchStroke = Instance.new("UIStroke", activeSwatch)
activeSwatchStroke.Color = Color3.fromRGB(255, 255, 255)
activeSwatchStroke.Thickness = 1.2
activeSwatchStroke.Transparency = 0.5

local activeNameBox = Instance.new("TextBox")
activeNameBox.Size = UDim2.new(1, -150, 0, 24)
activeNameBox.Position = UDim2.new(0, 66, 0, 12)
activeNameBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
activeNameBox.Text = CustomGlobeName
activeNameBox.PlaceholderText = "Renombrar color..."
activeNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
activeNameBox.Font = Enum.Font.GothamBold
activeNameBox.TextSize = 12
activeNameBox.TextXAlignment = Enum.TextXAlignment.Left
activeNameBox.ClearTextOnFocus = false
activeNameBox.Parent = activeCard
Instance.new("UICorner", activeNameBox).CornerRadius = UDim.new(0, 6)

local namePad = Instance.new("UIPadding", activeNameBox)
namePad.PaddingLeft = UDim.new(0, 8)

local activeHexLbl = Instance.new("TextLabel")
activeHexLbl.Size = UDim2.new(1, -150, 0, 18)
activeHexLbl.Position = UDim2.new(0, 68, 0, 41)
activeHexLbl.BackgroundTransparency = 1
activeHexLbl.Text = CustomGlobeHex and ("ACTIVO: " .. CustomGlobeHex) or "ACTIVO: DEFAULT SHIELD"
activeHexLbl.TextColor3 = Color3.fromRGB(165, 175, 200)
activeHexLbl.Font = Enum.Font.GothamBold
activeHexLbl.TextSize = 11
activeHexLbl.TextXAlignment = Enum.TextXAlignment.Left
activeHexLbl.Parent = activeCard

local copyActiveBtn = Instance.new("TextButton")
copyActiveBtn.Size = UDim2.new(0, 68, 0, 28)
copyActiveBtn.Position = UDim2.new(1, -78, 0.5, -14)
copyActiveBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
copyActiveBtn.Text = "COPIAR"
copyActiveBtn.TextColor3 = Color3.fromRGB(220, 230, 255)
copyActiveBtn.Font = Enum.Font.GothamBlack
copyActiveBtn.TextSize = 11
copyActiveBtn.Parent = activeCard
Instance.new("UICorner", copyActiveBtn).CornerRadius = UDim.new(0, 8)

activeNameBox.FocusLost:Connect(function()
    local newName = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if newName == "" then
        newName = CustomGlobeHex or "Color Personalizado"
        activeNameBox.Text = newName
    end
    CustomGlobeName = newName
    saveConfig()
end)

copyActiveBtn.MouseButton1Click:Connect(function()
    local toCopy = CustomGlobeHex or "#B4C0CD"
    if copyToClipboard then
        pcall(copyToClipboard, toCopy)
    end
    copyActiveBtn.Text = "COPIADO"
    task.delay(1.1, function()
        if copyActiveBtn and copyActiveBtn.Parent then
            copyActiveBtn.Text = "COPIAR"
        end
    end)
end)

local savedHeader = Instance.new("TextLabel")
savedHeader.Size = UDim2.new(1, -8, 0, 20)
savedHeader.Position = UDim2.new(0, 4, 0, 196)
savedHeader.BackgroundTransparency = 1
savedHeader.Text = "COLORES GUARDADOS"
savedHeader.TextColor3 = Color3.fromRGB(155, 165, 190)
savedHeader.Font = Enum.Font.GothamBlack
savedHeader.TextSize = 11
savedHeader.TextXAlignment = Enum.TextXAlignment.Left
savedHeader.Parent = colorGlobContainer

local savedScroll = Instance.new("ScrollingFrame")
savedScroll.Size = UDim2.new(1, -6, 1, -222)
savedScroll.Position = UDim2.new(0, 3, 0, 218)
savedScroll.BackgroundTransparency = 1
savedScroll.ScrollBarThickness = 4
savedScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
savedScroll.Parent = colorGlobContainer

local savedListLayout = Instance.new("UIListLayout", savedScroll)
savedListLayout.Padding = UDim.new(0, 8)
savedListLayout.SortOrder = Enum.SortOrder.LayoutOrder

RunService.RenderStepped:Connect(function()
    if savedScroll and savedScroll.Parent then
        savedScroll.CanvasSize = UDim2.new(0, 0, 0, savedListLayout.AbsoluteContentSize.Y + 10)
    end
end)

local function applyCustomGlobeColor(col, normHex, customName)
    CustomGlobeColor = col
    CustomGlobeHex = normHex
    if customName and customName ~= "" then
        CustomGlobeName = customName
    elseif not CustomGlobeName or CustomGlobeName == "" then
        CustomGlobeName = normHex
    end

    previewSwatch.BackgroundColor3 = col
    activeSwatch.BackgroundColor3 = col
    activeHexLbl.Text = "ACTIVO: " .. normHex
    activeNameBox.Text = CustomGlobeName
    hexInput.Text = normHex

    refreshAllBillboardInnerColors()
    saveConfig()
end

local function rebuildSavedColorsList()
    for _, child in ipairs(savedScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for idx, entry in ipairs(SavedGlobeColors) do
        local col, normHex = parseHexColor(entry.hex)
        if col and normHex then
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -8, 0, 56)
            item.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
            item.LayoutOrder = idx
            item.Parent = savedScroll
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 10)

            local itemStroke = Instance.new("UIStroke", item)
            itemStroke.Color = Color3.fromRGB(40, 42, 56)
            itemStroke.Thickness = 1

            local sw = Instance.new("Frame")
            sw.Size = UDim2.new(0, 34, 0, 34)
            sw.Position = UDim2.new(0, 10, 0.5, -17)
            sw.BackgroundColor3 = col
            sw.BorderSizePixel = 0
            sw.Parent = item
            Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 7)

            local renameBox = Instance.new("TextBox")
            renameBox.Size = UDim2.new(1, -186, 0, 22)
            renameBox.Position = UDim2.new(0, 52, 0, 7)
            renameBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
            renameBox.Text = entry.name or normHex
            renameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameBox.Font = Enum.Font.GothamBold
            renameBox.TextSize = 11
            renameBox.TextXAlignment = Enum.TextXAlignment.Left
            renameBox.ClearTextOnFocus = false
            renameBox.Parent = item
            Instance.new("UICorner", renameBox).CornerRadius = UDim.new(0, 6)

            local rPad = Instance.new("UIPadding", renameBox)
            rPad.PaddingLeft = UDim.new(0, 6)

            renameBox.FocusLost:Connect(function()
                local txt = renameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if txt == "" then txt = normHex end
                renameBox.Text = txt
                SavedGlobeColors[idx].name = txt
                if CustomGlobeHex == normHex then
                    CustomGlobeName = txt
                    activeNameBox.Text = txt
                end
                saveConfig()
            end)

            local hexTag = Instance.new("TextLabel")
            hexTag.Size = UDim2.new(1, -186, 0, 16)
            hexTag.Position = UDim2.new(0, 54, 0, 33)
            hexTag.BackgroundTransparency = 1
            hexTag.Text = normHex
            hexTag.TextColor3 = Color3.fromRGB(150, 160, 185)
            hexTag.Font = Enum.Font.GothamBold
            hexTag.TextSize = 10
            hexTag.TextXAlignment = Enum.TextXAlignment.Left
            hexTag.Parent = item

            local useBtn = Instance.new("TextButton")
            useBtn.Size = UDim2.new(0, 54, 0, 26)
            useBtn.Position = UDim2.new(1, -126, 0.5, -13)
            useBtn.BackgroundColor3 = Color3.fromRGB(65, 115, 240)
            useBtn.Text = "APLICAR"
            useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            useBtn.Font = Enum.Font.GothamBlack
            useBtn.TextSize = 9
            useBtn.Parent = item
            Instance.new("UICorner", useBtn).CornerRadius = UDim.new(0, 6)

            useBtn.MouseButton1Click:Connect(function()
                applyCustomGlobeColor(col, normHex, SavedGlobeColors[idx].name)
            end)

            local cpBtn = Instance.new("TextButton")
            cpBtn.Size = UDim2.new(0, 42, 0, 26)
            cpBtn.Position = UDim2.new(1, -68, 0.5, -13)
            cpBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
            cpBtn.Text = "COPIAR"
            cpBtn.TextColor3 = Color3.fromRGB(215, 225, 255)
            cpBtn.Font = Enum.Font.GothamBlack
            cpBtn.TextSize = 9
            cpBtn.Parent = item
            Instance.new("UICorner", cpBtn).CornerRadius = UDim.new(0, 6)

            cpBtn.MouseButton1Click:Connect(function()
                if copyToClipboard then
                    pcall(copyToClipboard, normHex)
                end
                cpBtn.Text = "OK"
                task.delay(1.0, function()
                    if cpBtn and cpBtn.Parent then cpBtn.Text = "COPIAR" end
                end)
            end)

            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.new(0, 18, 0, 26)
            delBtn.Position = UDim2.new(1, -22, 0.5, -13)
            delBtn.BackgroundColor3 = Color3.fromRGB(55, 28, 35)
            delBtn.Text = "×"
            delBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 13
            delBtn.Parent = item
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 6)

            delBtn.MouseButton1Click:Connect(function()
                table.remove(SavedGlobeColors, idx)
                saveConfig()
                rebuildSavedColorsList()
            end)
        end
    end
end

applyGlobBtn.MouseButton1Click:Connect(function()
    local raw = (hexInput.Text ~= "" and hexInput.Text) or "#B4C0CD"
    local col, normHex = parseHexColor(raw)
    if col and normHex then
        local currentName = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if currentName == "" or currentName == "Color Personalizado" then
            currentName = normHex
        end
        applyCustomGlobeColor(col, normHex, currentName)
        applyGlobBtn.Text = "APLICADO"
        task.delay(1.0, function()
            if applyGlobBtn and applyGlobBtn.Parent then
                applyGlobBtn.Text = "APLICAR"
            end
        end)
    else
        applyGlobBtn.Text = "HEX INVÁLIDO"
        task.delay(1.1, function()
            if applyGlobBtn and applyGlobBtn.Parent then
                applyGlobBtn.Text = "APLICAR"
            end
        end)
    end
end)

saveGlobBtn.MouseButton1Click:Connect(function()
    local raw = (hexInput.Text ~= "" and hexInput.Text) or CustomGlobeHex or "#B4C0CD"
    local col, normHex = parseHexColor(raw)
    if col and normHex then
        local nameToSave = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if nameToSave == "" or nameToSave == "Color Personalizado" then
            nameToSave = normHex
        end
        table.insert(SavedGlobeColors, 1, {hex = normHex, name = nameToSave})
        saveConfig()
        rebuildSavedColorsList()
        saveGlobBtn.Text = "GUARDADO"
        task.delay(1.0, function()
            if saveGlobBtn and saveGlobBtn.Parent then
                saveGlobBtn.Text = "+ GUARDAR EN LISTA"
            end
        end)
    end
end)

rebuildSavedColorsList()

-- ==========================================
-- FILAS DE VOICELINES EN LA PESTAÑA SPIDER-MAN
-- ==========================================
local function applyHover(btn, normalColor, hoverColor)
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = normalColor}):Play() end)
end

local function createVoicelineRow(parentScroll, data)
    local accentColor = GLOBAL_PALETTE[((data.order or 1) % #GLOBAL_PALETTE) + 1]

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 85)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    row.LayoutOrder = 10 + (data.order or 1)
    row.Parent = parentScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(40, 40, 50)
    rStroke.Thickness = 1

    row.MouseEnter:Connect(function()
        TweenService:Create(rStroke, TweenInfo.new(0.3), {Color = accentColor}):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(rStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(40, 40, 50)}):Play()
    end)

    local typeDot = Instance.new("Frame")
    typeDot.Size = UDim2.new(0, 8, 0, 8)
    typeDot.Position = UDim2.new(0, 16, 0, 23)
    typeDot.BackgroundColor3 = accentColor
    typeDot.Parent = row
    Instance.new("UICorner", typeDot).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 0, 30)
    lbl.Position = UDim2.new(0, 32, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.Text = data.key
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 80, 0, 30)
    testBtn.Position = UDim2.new(1, -100, 0, 12)
    testBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    testBtn.Text = "PREVIEW"
    testBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
    testBtn.Font = Enum.Font.GothamBlack
    testBtn.TextSize = 11
    testBtn.Parent = row
    Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0, 8)
    applyHover(testBtn, Color3.fromRGB(35, 35, 45), Color3.fromRGB(60, 60, 85))
    testBtn.MouseButton1Click:Connect(function()
        playSound(data, true, player.Character)
    end)

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -90, 0, 12)
    sliderBg.Position = UDim2.new(0, 20, 0, 58)
    sliderBg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    sliderBg.Parent = row
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local sliderFill = Instance.new("Frame")
    local currentVol = VolumeData[data.key] or data.defVol
    sliderFill.Size = UDim2.new(currentVol / 10, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

    local fGrad = Instance.new("UIGradient", sliderFill)
    fGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
        ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
    })

    local volTxt = Instance.new("TextLabel")
    volTxt.Size = UDim2.new(0, 40, 0, 20)
    volTxt.Position = UDim2.new(1, -60, 0, 54)
    volTxt.BackgroundTransparency = 1
    volTxt.Text = math.floor((currentVol / 10) * 100) .. "%"
    volTxt.TextColor3 = Color3.fromRGB(200, 200, 220)
    volTxt.Font = Enum.Font.GothamBold
    volTxt.TextSize = 12
    volTxt.Parent = row

    local draggingSlider = false

    local function updateSlider(input)
        local inputPos = input.Position.X
        local relX = math.clamp((inputPos - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        TweenService:Create(sliderFill, TweenInfo.new(0.05, Enum.EasingStyle.Sine), {Size = UDim2.new(relX, 0, 1, 0)}):Play()
        volTxt.Text = math.floor(relX * 100) .. "%"
        VolumeData[data.key] = relX * 10

        if data.isSong and activeSong and activeSong.sound and activeSong.sound.Parent and (activeSong.interrupts or 0) == 0 then
            activeSong.sound.Volume = VolumeData[data.key]
        end
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            TweenService:Create(sliderFill, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 200, 200)}):Play()
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if draggingSlider then
                draggingSlider = false
                saveConfig()
                TweenService:Create(sliderFill, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        end
    end)
end

local addedSpidey = {}
for _, data in pairs(SOUND_TRACKED) do
    if not addedSpidey[data.key] then
        addedSpidey[data.key] = true
        createVoicelineRow(spideyScroll, data)
    end
end

for _, data in pairs(TRACKED) do
    if not addedSpidey[data.key] then
        addedSpidey[data.key] = true
        createVoicelineRow(spideyScroll, data)
    end
end

if not addedSpidey[DEATH_VOICELINE.key] then
    addedSpidey[DEATH_VOICELINE.key] = true
    createVoicelineRow(spideyScroll, DEATH_VOICELINE)
end

-- ==========================================
-- HOOK DE ANIMACIONES, SONIDOS Y MUERTE DE SPIDER-MAN
-- ==========================================
local lastPlay = {}
local playedTracks = {}
local hookedSounds = setmetatable({}, {__mode = "k"})

local function muteOriginalSound(sound)
    if not sound or not sound.Parent then return end
    sound.Volume = 0
    pcall(function() sound:Stop() end)
    sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if sound and sound.Parent and sound.Volume > 0 then
            sound.Volume = 0
        end
    end)
end

local function handleReplacedSound(sound, char)
    if not sound or not sound:IsA("Sound") or sound:GetAttribute("IsCustomVoice") then return end

    local sid = sound.SoundId:match("%d+")
    if not sid or not SOUND_TRACKED[sid] then return end

    local isOwned = sound:IsDescendantOf(char)
        or (player:FindFirstChild("PlayerGui") and sound:IsDescendantOf(player.PlayerGui))
        or sound:IsDescendantOf(SoundService)

    if not isOwned and sound:IsDescendantOf(Workspace) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local parentPart = sound.Parent and (sound.Parent:IsA("BasePart") and sound.Parent or sound.Parent:FindFirstAncestorWhichIsA("BasePart"))
        if hrp and parentPart and (hrp.Position - parentPart.Position).Magnitude <= 35 then
            isOwned = true
        end
    end

    if not isOwned then return end

    muteOriginalSound(sound)

    local last = lastPlay["SPIDEY_SND_" .. sid] or 0
    if tick() - last < SOUND_TRACKED[sid].cd then return end
    lastPlay["SPIDEY_SND_" .. sid] = tick()

    playSound(SOUND_TRACKED[sid], false, char)
end

local function watchSoundInstance(sound, char)
    if not sound or not sound:IsA("Sound") or hookedSounds[sound] or sound:GetAttribute("IsCustomVoice") then
        return
    end
    hookedSounds[sound] = true

    if sound.IsPlaying then
        handleReplacedSound(sound, char)
    end

    sound.Played:Connect(function()
        handleReplacedSound(sound, char)
    end)

    sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.Playing then
            handleReplacedSound(sound, char)
        end
    end)

    sound:GetPropertyChangedSignal("SoundId"):Connect(function()
        if sound.IsPlaying then
            handleReplacedSound(sound, char)
        end
    end)
end

local function hook(char)
    beamPreviewActive = false
    beamPreviewSessionId = nil
    if toggleGlobeBtn and toggleGlobeBtn.Parent then
        toggleGlobeBtn.Text = "VER GLOBO"
        toggleGlobeBtn.BackgroundColor3 = Color3.fromRGB(55, 130, 230)
    end

    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    local animator = hum:WaitForChild("Animator", 10)
    if not animator then return end
    playedTracks = {}

    local deathTriggered = false
    local function onCharacterDeath()
        if deathTriggered then return end
        if not isSpiderManDefault(char) then return end
        deathTriggered = true
        playSound(DEATH_VOICELINE, false, char)
    end

    hum.Died:Connect(onCharacterDeath)
    hum.HealthChanged:Connect(function(hp)
        if hp <= 0 then
            onCharacterDeath()
        end
    end)

    local containers = {char, player:FindFirstChild("PlayerGui"), SoundService, Workspace}
    for _, container in ipairs(containers) do
        if container then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("Sound") then
                    watchSoundInstance(desc, char)
                end
            end
            container.DescendantAdded:Connect(function(desc)
                if desc:IsA("Sound") then
                    watchSoundInstance(desc, char)
                end
            end)
        end
    end

    animator.AnimationPlayed:Connect(function(track)
        local animId = track.Animation.AnimationId:match("%d+")
        if not animId then return end

        if animId == STOP_SONG_ANIM then
            stopActiveSong(true)
            return
        end

        local data = TRACKED[animId]
        if not data or playedTracks[track] then return end

        if data.isSong and activeSong then
            return
        end

        local last = lastPlay[data.key] or 0
        if tick() - last < data.cd then return end

        task.wait(data.isSong and 0.05 or 0.1)
        if not track.IsPlaying then return end

        lastPlay[data.key] = tick()
        playedTracks[track] = true

        track.Stopped:Connect(function()
            playedTracks[track] = nil
        end)

        playSound(data, false, char, track)
    end)
end

if player.Character then hook(player.Character) end
player.CharacterAdded:Connect(hook)
