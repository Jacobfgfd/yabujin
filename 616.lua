--!nocheck
-- 616 :: rivals skinchanger
-- Built by Olivia. https://discord.gg/ojailbreaks
-- RIGHT SHIFT toggles menu. Background clicks locked while open.

local PREV = _G.RivalsSkins
if PREV and PREV.stop then
    pcall(PREV.stop)
end

local CFG = {
    toggleKey = Enum.KeyCode.RightShift,
    dir = "rivals_skins",
    allowMisfit = false,
    startOpen = true,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS  = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local LP = Players.LocalPlayer

local O = { children = 0x70, parent = 0x60, name = 0x68, primary = 0x240, scale = 0x12c, loaded = 0x150 }
local L = { strLen = 0x14, strText = 0x18, tLsz = 5, tSizeArr = 8, tArr = 0x20, tNode = 0x28 }

local S = {
    running = true, dead = false, stopReq = false, inTick = false,
    enabled = true, wasEnabled = false,
    status = "starting", statusOk = true, uiDirty = true,
    desired = {}, desiredChanged = false, picksPending = false,
    queue = {}, applied = {}, over = {}, retry = {}, defRetry = {}, defFails = {},
    unsafe = {}, equipped = {}, invWeapons = {}, weapons = {}, skins = {},
    skinIndex = {}, skinsByWeapon = {}, folders = {},
    root = nil, offsetsOk = false, loadedOk = false,
    world = 0, journalChecked = false, fpB = 0, fpE = 0,
    donors = nil, donorsAt = 0, catalogGrew = false, verifyAt = nil,
    learned = {}, ownersTried = false, log = {},
}

local Core = {}
local Cos  = {}
S.cos = {
    desired = { charm = {}, finisher = {} },
    applied = { charm = {}, finisher = {} },
    lists   = { charm = {}, finisher = {} },
    cache = {}, retry = {},
}
local Defs = {}
local UI = { cat = "All", wsel = nil, open = CFG.startOpen }

local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    local t = S.log
    t[#t + 1] = string.format("%.1f %s", os.clock(), msg)
    if #t > 300 then table.remove(t, 1) end
end

local function setStatus(ok, fmt, ...)
    local good, msg = pcall(string.format, fmt, ...)
    if not good then msg = tostring(fmt) end
    if S.status ~= msg or S.statusOk ~= ok then
        S.status = msg; S.statusOk = ok; S.uiDirty = true
        log("status: %s", msg)
    end
end

local function rp(a)
    if not a or a == 0 then return 0 end
    local ok, v = pcall(memory_read, "uintptr", a)
    return (ok and v) or 0
end
local function wp(a, v) pcall(memory_write, "uintptr", a, v) end
local function rb(a)
    if not a or a == 0 then return 0 end
    local ok, v = pcall(memory_read, "byte", a)
    return (ok and v) or 0
end
local function okp(p) return p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end
local function ptrOrZero(p) return p == 0 or okp(p) end
local function ru32(a) return rb(a) + rb(a+1)*256 + rb(a+2)*65536 + rb(a+3)*16777216 end
local function bytes(a, n)
    local t = table.create(n)
    for i = 0, n-1 do t[i+1] = string.char(rb(a + i)) end
    return table.concat(t)
end

local sliceAt = os.clock()
local function breathe()
    if S.inTick and os.clock() - sliceAt > 0.004 then
        task.wait(); sliceAt = os.clock()
    end
end

local CATEGORY = {}
local CATEGORIES = { "All", "Rifles", "Marksman", "Shotguns", "Pistols", "Heavy", "Melee", "Utility", "Charms", "Finishers" }
do
    local function cat(name, list)
        for w in string.gmatch(list, "[^|]+") do CATEGORY[w] = name end
    end
    cat("Rifles",   "Assault Rifle|Burst Rifle|Energy Rifle|Permafrost|Wildcat|Distortion|Gunblade|Paintball Gun|Flamethrower")
    cat("Marksman", "Sniper|Bow|Crossbow")
    cat("Shotguns", "Shotgun|Shorty")
    cat("Pistols",  "Handgun|Energy Pistols|Revolver|Uzi|Spray|Flare Gun|Exogun|Slingshot|Warper|Daggers|Glass Cannon")
    cat("Heavy",    "Minigun|RPG|Grenade Launcher")
    cat("Melee",    "Knife|Katana|Fists|Battle Axe|Maul|Chainsaw|Scythe|Spear|Trowel|Riot Shield")
end

local nameCache = {}
local nameCacheAt = os.clock()
local function stdstr(p)
    local size = rp(p + 0x10); local cap = rp(p + 0x18)
    if size == 0 or size > 128 or cap < size then return nil end
    local d = p
    if cap > 15 then d = rp(p); if not okp(d) then return nil end end
    return bytes(d, size)
end
local function nameFresh(inst)
    if not okp(inst) then return "" end
    local np = rp(inst + O.name); if not okp(np) then return "" end
    return stdstr(np) or ""
end
local function nameOf(inst)
    if not okp(inst) then return "" end
    local np = rp(inst + O.name); if not okp(np) then return "" end
    local c = nameCache[np]; if c then return c end
    local s = stdstr(np) or ""
    if s ~= "" then nameCache[np] = s end
    return s
end
local function readVec(parent)
    if not okp(parent) then return nil end
    local start = rp(parent + O.children); if not okp(start) then return nil end
    local b, e, c = rp(start), rp(start + 8), rp(start + 16)
    if not okp(b) or e < b or c < e or (e - b) % 16 ~= 0 then return nil end
    local n = (e - b) / 16
    if n > 4096 then return nil end
    return { start = start, b = b, e = e, n = n }
end
local function kids(parent)
    local h = readVec(parent); if not h then return nil end
    local t = {}
    for i = 0, h.n - 1 do
        local p = rp(h.b + i * 16); if okp(p) then t[#t+1] = p end
    end
    return t, h
end
local function children(parent)
    local out = {}; local list = kids(parent); if not list then return out end
    for i = 1, #list do
        local n = nameOf(list[i]); if n ~= "" then out[#out+1] = { addr = list[i], name = n } end
    end
    return out
end
local function findChild(parent, name)
    local list = kids(parent); if not list then return 0 end
    for i = 1, #list do if nameOf(list[i]) == name then return list[i] end end
    return 0
end
local function parentOf(inst)
    if not okp(inst) then return 0 end
    return rp(inst + O.parent)
end
local function swapContents(a, b)
    if not okp(a) or not okp(b) or a == b then return false end
    local cs = O.children
    local ca0, ca1 = rp(a + cs), rp(a + cs + 8)
    local cb0, cb1 = rp(b + cs), rp(b + cs + 8)
    if not okp(ca0) or not okp(cb0) or not ptrOrZero(ca1) or not ptrOrZero(cb1) then return false end
    local sa, sb = kids(a), kids(b); if not sa or not sb then return false end
    wp(a + cs, cb0); wp(a + cs + 8, cb1); wp(b + cs, ca0); wp(b + cs + 8, ca1)
    for i = 1, #sb do wp(sb[i] + O.parent, a) end
    for i = 1, #sa do wp(sa[i] + O.parent, b) end
    local pp = O.primary
    local pa0, pa1 = rp(a + pp), rp(a + pp + 8)
    local pb0, pb1 = rp(b + pp), rp(b + pp + 8)
    if ptrOrZero(pa0) and ptrOrZero(pa1) and ptrOrZero(pb0) and ptrOrZero(pb1) then
        wp(a + pp, pb0); wp(a + pp + 8, pb1); wp(b + pp, pa0); wp(b + pp + 8, pa1)
    end
    local fa = memory_read("float", a + O.scale) or 0
    local fb = memory_read("float", b + O.scale) or 0
    if fa > 0 and fb > 0 and fa ~= fb then
        memory_write("float", a + O.scale, fb); memory_write("float", b + O.scale, fa)
    end
    return true
end
local function swapNames(a, b)
    if not okp(a) or not okp(b) or a == b then return false end
    local na, nb = rp(a + O.name), rp(b + O.name)
    if not okp(na) or not okp(nb) then return false end
    wp(a + O.name, nb); wp(b + O.name, na); return true
end
local function swapKids(a, b)
    if not okp(a) or not okp(b) or a == b then return nil end
    local cs = O.children
    local a0, a1 = rp(a + cs), rp(a + cs + 8)
    local b0, b1 = rp(b + cs), rp(b + cs + 8)
    if not okp(a0) or not okp(b0) or a0 == b0 or not ptrOrZero(a1) or not ptrOrZero(b1) then return nil end
    local ka, kb = kids(a), kids(b)
    if not ka or not kb or #ka == 0 or #kb == 0 then return nil end
    wp(a + cs, b0); wp(a + cs + 8, b1); wp(b + cs, a0); wp(b + cs + 8, a1)
    for i = 1, #kb do wp(kb[i] + O.parent, a) end
    for i = 1, #ka do wp(ka[i] + O.parent, b) end
    return { a = a, b = b, ka = a0, kb = b0, ea = a1, eb = b1 }
end
local function undoKids(a, b, ka, kb, ea, eb)
    if not okp(a) or not okp(b) or not okp(ka) or not okp(kb) or not ptrOrZero(ea) or not ptrOrZero(eb) then return false end
    local cs = O.children
    if rp(a + cs) ~= kb or rp(b + cs) ~= ka then return false end
    local la, lb = kids(a) or {}, kids(b) or {}
    wp(a + cs, ka); wp(a + cs + 8, ea); wp(b + cs, kb); wp(b + cs + 8, eb)
    for i = 1, #la do wp(la[i] + O.parent, b) end
    for i = 1, #lb do wp(lb[i] + O.parent, a) end
    return true
end
local function validateOffsets(r)
    if parentOf(r.weapons) ~= r.viewmodels or parentOf(r.viewmodels) ~= r.assets then return false, "parent" end
    local lp = Players.LocalPlayer
    local ps = lp and lp:FindFirstChild("PlayerScripts")
    if not r.fallback and ps and ps.Address ~= r.scripts then return false, "children" end
    local list = kids(r.weapons); if not list or #list == 0 then return false, "weapons" end
    local seen = 0
    for i = 1, #list do
        local m = list[i]
        if nameOf(m) ~= "Unobtainable" then
            local sc = memory_read("float", m + O.scale) or 0
            local p0, p1 = rp(m + O.primary), rp(m + O.primary + 8)
            local c0, c1 = rp(m + O.children), rp(m + O.children + 8)
            if sc < 0.01 or sc > 100 or not ptrOrZero(p0) or not ptrOrZero(p1) or not okp(c0) or not ptrOrZero(c1) then
                return false, "model " .. nameOf(m)
            end
            if p0 ~= 0 then
                local p = p0; local found = false
                for _ = 1, 8 do
                    p = parentOf(p); if p == m then found = true; break end
                    if not okp(p) then break end
                end
                if not found then return false, "primary part " .. nameOf(m) end
            end
            seen += 1; if seen >= 16 then break end
        end
    end
    return seen > 0
end
local function deriveLoaded(r)
    local vms = findChild(findChild(r.scripts, "Modules"), "ViewModels")
    local list = kids(vms); if not list or #list == 0 then return false end
    local function test(off)
        local zero, non, val = 0, 0, nil
        for i = 1, #list do
            local v = rp(list[i] + off)
            if v == 0 then zero += 1
            elseif val == nil or v == val then val = v; non += 1
            else return false, 0, 0 end
        end
        return true, zero, non
    end
    local ok, zero, non = test(O.loaded)
    if ok and (non == 0 or zero > 0) then return true end
    local found = nil
    for off = 0x100, 0x200, 8 do
        local good, z, n = test(off)
        if good and z > 0 and n > 0 then if found then return false end; found = off end
    end
    if found then log("module-loaded field moved: %x -> %x", O.loaded, found); O.loaded = found; return true end
    return false
end
local function isLoaded(module) return S.loadedOk and okp(module) and rp(module + O.loaded) ~= 0 end

local function resolve()
    local r = { datamodel = game.Address or 0, player = 0, scripts = 0, assets = 0, viewmodels = 0, weapons = 0, fallback = false, starter = 0 }
    local lp = Players.LocalPlayer
    r.player = lp and lp.Address or 0
    local sp = game:GetService("StarterPlayer")
    local spa = sp and sp.Address or 0
    if okp(r.player) then
        r.scripts = findChild(r.player, "PlayerScripts")
        r.assets  = findChild(r.scripts, "Assets")
        if r.assets ~= 0 then r.starter = findChild(spa, "StarterPlayerScripts") end
    end
    if r.assets == 0 then
        r.scripts = findChild(spa, "StarterPlayerScripts")
        r.assets  = findChild(r.scripts, "Assets")
        r.fallback = true
    end
    r.viewmodels = findChild(r.assets, "ViewModels")
    r.weapons    = findChild(r.viewmodels, "Weapons")
    return r
end
local function rootValid(r) return r ~= nil and r.viewmodels ~= 0 and r.weapons ~= 0 end
local function stillValid(r)
    if not rootValid(r) then return false end
    local lp = Players.LocalPlayer
    if r.datamodel ~= (game.Address or 0) or r.player ~= (lp and lp.Address or 0) then return false end
    if parentOf(r.weapons) ~= r.viewmodels then return false end
    if parentOf(r.viewmodels) ~= r.assets then return false end
    if parentOf(r.assets) ~= r.scripts then return false end
    if nameFresh(r.viewmodels) ~= "ViewModels" then return false end
    if r.fallback and okp(r.player) and findChild(findChild(r.player, "PlayerScripts"), "Assets") ~= 0 then return false end
    return true
end
local function journalPath() return CFG.dir .. "/journal.txt" end
local function writeJournal()
    local lines = {}
    for _, ov in pairs(S.over) do
        for i = 1, #ov.writes do
            local w = ov.writes[i]
            lines[#lines+1] = string.format("W %x %x %x", w.slot, w.orig, w.value)
        end
    end
    for _, ap in pairs(S.applied) do
        if ap.a ~= 0 then lines[#lines+1] = string.format("C %x %x %x %x", ap.a, ap.b, ap.va, ap.vb) end
        for i = 1, #ap.names do
            local n = ap.names[i]
            lines[#lines+1] = string.format("N %x %x %x %x", n.a, n.b, n.pa, n.pb)
        end
    end
    for _, set in pairs(S.cos.applied) do
        for _, rec in pairs(set) do
            if rec.ka then lines[#lines+1] = string.format("K %x %x %x %x %x %x", rec.a, rec.b, rec.ka, rec.kb, rec.ea, rec.eb) end
            if rec.na then lines[#lines+1] = string.format("N %x %x %x %x", rec.ma, rec.mb, rec.na, rec.nb) end
        end
    end
    if #lines == 0 then
        if isfile(journalPath()) then pcall(delfile, journalPath()) end
        return
    end
    local head = string.format("%s\nO %x %x %x %x %x\n", tostring(game.JobId), O.children, O.parent, O.name, O.primary, O.scale)
    pcall(writefile, journalPath(), head .. table.concat(lines, "\n") .. "\n")
end
local function undoJournal()
    if not isfile(journalPath()) then return end
    local ok, text = pcall(readfile, journalPath()); pcall(delfile, journalPath())
    if not ok or type(text) ~= "string" then return end
    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do lines[#lines+1] = line end
    if #lines < 3 or lines[1] ~= tostring(game.JobId) then return end
    local o = {}
    for v in string.gmatch(lines[2], "%x+") do o[#o+1] = tonumber(v, 16) end
    if string.sub(lines[2], 1, 2) ~= "O " or #o ~= 5 then return end
    local keep = { children = O.children, parent = O.parent, name = O.name, primary = O.primary, scale = O.scale }
    O.children, O.parent, O.name, O.primary, O.scale = o[1], o[2], o[3], o[4], o[5]
    local undone = 0
    for i = #lines, 3, -1 do
        local kind = string.sub(lines[i], 1, 1); local p = {}
        for v in string.gmatch(string.sub(lines[i], 3), "%x+") do p[#p+1] = tonumber(v, 16) end
        if kind == "W" and #p == 3 then
            if okp(p[1]) and rp(p[1]) == p[3] then wp(p[1], p[2]); undone += 1 end
        elseif kind == "C" and #p == 4 then
            if okp(p[1]) and okp(p[2]) and rp(p[1] + O.children) == p[4] and rp(p[2] + O.children) == p[3] then
                if swapContents(p[1], p[2]) then undone += 1 end
            end
        elseif kind == "N" and #p == 4 then
            if okp(p[1]) and okp(p[2]) and rp(p[1] + O.name) == p[4] and rp(p[2] + O.name) == p[3] then
                if swapNames(p[1], p[2]) then undone += 1 end
            end
        elseif kind == "K" and #p == 6 then
            if undoKids(p[1], p[2], p[3], p[4], p[5], p[6]) then undone += 1 end
        end
    end
    for k, v in pairs(keep) do O[k] = v end
    log("undid %d changes left by an earlier session", undone)
end
local function savePicks()
    local names = {}
    for w in pairs(S.desired) do names[#names+1] = w end
    table.sort(names)
    local parts = {}
    for i = 1, #names do parts[#parts+1] = names[i] .. ":" .. S.desired[names[i]] end
    pcall(writefile, CFG.dir .. "/picks.txt", table.concat(parts, "|"))
end
local function loadPicks()
    if not isfile(CFG.dir .. "/picks.txt") then return end
    local ok, text = pcall(readfile, CFG.dir .. "/picks.txt")
    if not ok or type(text) ~= "string" then return end
    for item in string.gmatch(text, "[^|]+") do
        local c = string.find(item, ":", 1, true)
        if c and c > 1 and c < #item then S.desired[string.sub(item, 1, c-1)] = string.sub(item, c+1) end
    end
    if next(S.desired) then S.desiredChanged = true end
end
local function saveCos()
    local lines = {}
    for kind, set in pairs(S.cos.desired) do
        for from, to in pairs(set) do lines[#lines+1] = kind .. "\t" .. from .. "\t" .. to end
    end
    table.sort(lines)
    pcall(writefile, CFG.dir .. "/cosmetics.txt", table.concat(lines, "\n"))
end
local function loadCos()
    if not isfile(CFG.dir .. "/cosmetics.txt") then return end
    local ok, text = pcall(readfile, CFG.dir .. "/cosmetics.txt")
    if not ok or type(text) ~= "string" then return end
    for line in string.gmatch(text, "[^\r\n]+") do
        local kind, from, to = string.match(line, "^(%a+)\t([^\t]+)\t([^\t]+)$")
        if kind and S.cos.desired[kind] and from ~= to then
            S.cos.desired[kind][from] = to; S.desiredChanged = true
        end
    end
end

function Core.scan()
    S.scanAt = os.clock()
    local r = S.root; local weapons = {}; local skins = {}
    if rootValid(r) then
        local wk = children(r.weapons)
        for i = 1, #wk do if wk[i].name ~= "Unobtainable" then weapons[#weapons+1] = wk[i].name end end
        table.sort(weapons)
        local wset = {}; for i = 1, #weapons do wset[weapons[i]] = true end
        local seen = {}
        local folders = children(r.viewmodels)
        for f = 1, #folders do
            local folder = folders[f]
            if folder.name ~= "Weapons" and folder.name ~= "WIP" and folder.name ~= "Unobtainable" then
                local h = readVec(folder.addr)
                if h then
                    local fc = S.folders[folder.addr]
                    if not (fc and fc.b == h.b and fc.e == h.e) then
                        fc = { b = h.b, e = h.e, names = {} }
                        local list = children(folder.addr)
                        for i = 1, #list do fc.names[#fc.names+1] = list[i].name end
                        breathe()
                    end
                    for i = 1, #fc.names do
                        local n = fc.names[i]
                        local si = { name = n, folder = folder.name, weapon = "" }
                        if wset[folder.name] then si.weapon = folder.name
                        elseif S.learned[n] and wset[S.learned[n]] then si.weapon = S.learned[n]
                        else
                            local best = 0
                            for k = 1, #weapons do
                                local w = weapons[k]
                                if #n > #w + 1 and #w > best and string.sub(n, -#w) == w and string.sub(n, -#w-1, -#w-1) == " " then
                                    si.weapon = w; best = #w
                                end
                            end
                        end
                        skins[#skins+1] = si
                    end
                    seen[folder.addr] = fc
                end
            end
        end
        S.folders = seen
    end
    table.sort(skins, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        local x = a.folder == a.weapon and 1 or 0
        local y = b.folder == b.weapon and 1 or 0
        return x > y
    end)
    local uniq = {}
    for i = 1, #skins do if i == 1 or skins[i].name ~= skins[i-1].name then uniq[#uniq+1] = skins[i] end end
    skins = uniq
    local changed = #weapons ~= #S.weapons or #skins ~= #S.skins
    if not changed then for i = 1, #weapons do if weapons[i] ~= S.weapons[i] then changed = true; break end end end
    if not changed then for i = 1, #skins do if skins[i].name ~= S.skins[i].name or skins[i].folder ~= S.skins[i].folder then changed = true; break end end end
    if not changed then return end
    local index, byWeapon = {}, {}
    for i = 1, #skins do
        index[skins[i].name] = skins[i]
        local w = skins[i].weapon
        if w ~= "" then local t = byWeapon[w]; if not t then t = {}; byWeapon[w] = t end; t[#t+1] = skins[i].name end
    end
    S.weapons = weapons; S.skins = skins; S.skinIndex = index; S.skinsByWeapon = byWeapon
    S.catalogGrew = true; S.uiDirty = true
    log("catalog: %d weapons, %d skins", #weapons, #skins)
end

local EFFECT_FOLDERS = {
    "Misc/MuzzleFlashes","Misc/SmokeClouds","Misc/BurningEffects","Misc/MolotovExplosionEffects",
    "Misc/FlamethrowerFlames","Misc/FlamethrowerAirblasts","Misc/DeflectHitEffects",
    "Misc/DeflectActiveEffects","Misc/BlipEffects","Misc/ChainsawParticles","Misc/WarHornEffects",
    "Projectiles","Throwables",
}
local function effectFolder(path)
    local at = S.root.assets
    for part in string.gmatch(path, "[^/]+") do if at == 0 then break end; at = findChild(at, part) end
    return at
end
local function codeFolder(weapon)
    local vms = findChild(findChild(S.root.scripts, "Modules"), "ViewModels")
    local base = findChild(vms, "Base" .. weapon)
    if base ~= 0 then return base end
    return findChild(vms, weapon)
end
local function buildDonors()
    local idx = {}; local budget = 60000; local count = 0
    local function walk(inst, depth)
        if depth > 8 or budget < 0 or S.stopReq then return end
        local list = kids(inst); if not list then return end
        for i = 1, #list do
            budget -= 1; if budget < 0 then return end
            local c = list[i]; local n = nameOf(c)
            if n ~= "" then
                local t = idx[n]; if not t then t = {}; idx[n] = t; count += 1 end
                t[#t+1] = c; walk(c, depth + 1)
            end
        end
        breathe()
    end
    walk(S.root.starter, 0)
    S.donors = idx; S.donorsAt = os.clock(); S.donorMissed = false
    log("%d donor names indexed", count)
end
local function donorInUse(inst)
    for _, ap in pairs(S.applied) do
        for i = 1, #ap.names do if ap.names[i].a == inst or ap.names[i].b == inst then return true end end
    end
    return false
end
local function donor(name, pending)
    local r = S.root
    if r.starter == 0 or r.fallback or not S.donors then return 0 end
    local list = S.donors[name]
    if list then
        for i = 1, #list do
            local d = list[i]; local busy = donorInUse(d)
            if not busy then for k = 1, #pending do if pending[k].a == d or pending[k].b == d then busy = true; break end end end
            if not busy and nameFresh(d) == name then
                local p = d
                for _ = 1, 12 do if p == 0 or p == r.starter then break end; p = parentOf(p) end
                if p == r.starter then return d end
            end
        end
    end
    if not S.donorRetry and S.inTick and not S.stopReq and os.clock() - S.donorsAt >= 3 then
        S.donorRetry = true; buildDonors(); local d = donor(name, pending); S.donorRetry = false; return d
    end
    S.donorMissed = true; return 0
end
local function recordSwap(a, b, out)
    local pa, pb = rp(a + O.name), rp(b + O.name)
    if not swapNames(a, b) then return false end
    out[#out+1] = { a = a, b = b, pa = pa, pb = pb }; return true
end
local function redirectName(folder, key, pick, toDefault, out, missed)
    if folder == 0 or key == pick then return false end
    local k, p = findChild(folder, key), findChild(folder, pick)
    if k ~= 0 and p ~= 0 then return recordSwap(k, p, out) end
    local want = p ~= 0 or (k ~= 0 and toDefault and findChild(folder, "Default") ~= 0)
    if not want then return false end
    local d = donor(p ~= 0 and key or pick, out)
    if d == 0 then missed[#missed+1] = nameOf(folder); return false end
    return recordSwap(p ~= 0 and p or k, d, out)
end
local function isDefaultCodeFolder(folder, weapon, key)
    return folder ~= 0 and key == weapon and nameOf(folder) == weapon and findChild(folder, key) == 0
end
local function redirectCode(folder, weapon, key, pick, out, missed)
    if folder == 0 or key == pick then return false, false end
    if not isDefaultCodeFolder(folder, weapon, key) then
        local k, p = findChild(folder, key), findChild(folder, pick)
        if k ~= 0 and p == 0 and key ~= weapon then
            local d = donor(pick, out)
            if d == 0 then missed[#missed+1] = nameOf(folder); return false, false end
            return recordSwap(k, d, out), false
        end
        return redirectName(folder, key, pick, false, out, missed), false
    end
    local p = findChild(folder, pick); if p == 0 then return false, false end
    if not isLoaded(p) then return false, true end
    return recordSwap(folder, p, out), false
end
local function missingNeededPart(weapon, base, pick)
    if weapon == "Flare Gun" then
        if findChild(findChild(base, "ItemVisual"), "Shell") ~= 0 and findChild(findChild(pick, "ItemVisual"), "Shell") == 0 then return true end
    end
    return false
end
local function templates(weapon, skin)
    local si = S.skinIndex[skin]; if not si then return 0, 0 end
    local base = findChild(S.root.weapons, weapon)
    local pick = findChild(findChild(S.root.viewmodels, si.folder), skin)
    local ap = S.applied[weapon]
    if ap and ap.skin == skin and ap.a ~= 0 and rp(ap.a + O.children) == ap.vb then base = ap.b; pick = ap.a end
    return base, pick
end
local function missingNeededPartByName(weapon, skin)
    local base, pick = templates(weapon, skin)
    return base ~= 0 and pick ~= 0 and missingNeededPart(weapon, base, pick)
end
local UNNAMED = { MeshPart = true, Primary = true, Part = true, _charm_attachment_model = true }
local function modelFits(weapon, skin)
    if not S.skinIndex[skin] then return false end
    local base, pick = templates(weapon, skin)
    if base == 0 or pick == 0 then return false end
    if weapon == "Medkit" then
        local tops = children(base)
        for i = 1, #tops do if not UNNAMED[tops[i].name] and findChild(pick, tops[i].name) == 0 then return false end end
    end
    if missingNeededPart(weapon, base, pick) then return false end
    return skin ~= "Keynade"
end
function Core.restoreOverride(weapon)
    local ov = S.over[weapon]; if not ov then return end
    Defs.restore(ov.writes); S.over[weapon] = nil
end
function Core.restoreSwaps(weapon)
    local ap = S.applied[weapon]; if not ap then return end
    if ap.a ~= 0 and rp(ap.a + O.children) == ap.vb and rp(ap.b + O.children) == ap.va then swapContents(ap.a, ap.b) end
    for i = #ap.names, 1, -1 do
        local n = ap.names[i]
        if rp(n.a + O.name) == n.pb and rp(n.b + O.name) == n.pa then swapNames(n.a, n.b) end
    end
    S.applied[weapon] = nil
end
function Core.restore(weapon) Core.restoreOverride(weapon); Core.restoreSwaps(weapon) end
function Core.restoreAll()
    local names = {}
    for w in pairs(S.applied) do names[#names+1] = w end
    for w in pairs(S.over) do names[#names+1] = w end
    for i = 1, #names do Core.restore(names[i]) end
    Cos.undoAll()
end
local function undoNames(list) for i = #list, 1, -1 do swapNames(list[i].a, list[i].b) end end
function Core.apply(weapon, skinName)
    local info = S.skinIndex[skinName]
    if not info then setStatus(false, "%s not loaded", skinName); return false end
    local base = ""
    local eq = S.equipped[weapon]
    if eq and eq ~= "" and S.skinIndex[eq] then base = eq end
    if base == skinName then
        Core.restoreSwaps(weapon)
        S.applied[weapon] = { weapon = weapon, skin = skinName, base = base, a = 0, b = 0, va = 0, vb = 0, names = {}, missed = {}, code = false, codeWait = false, codePrime = false, codeModule = 0 }
        setStatus(true, "%s already equipped on %s", skinName, weapon); return true
    end
    local cur = S.applied[weapon]
    if cur and cur.skin == skinName and cur.base == base then return true end
    local kick = {}
    for w, ap in pairs(S.applied) do if ap.skin == skinName and w ~= weapon then kick[#kick+1] = w end end
    for i = 1, #kick do Core.restoreSwaps(kick[i]) end
    Core.restoreSwaps(weapon)
    local r = S.root; local wep
    if base == "" then wep = findChild(r.weapons, weapon)
    else wep = findChild(findChild(r.viewmodels, S.skinIndex[base].folder), base) end
    if wep == 0 then setStatus(false, "%s template missing", base == "" and weapon or base); return false end
    local skin = findChild(findChild(r.viewmodels, info.folder), skinName)
    if skin == 0 then setStatus(false, "%s not loaded", skinName); return false end
    local rec = { weapon = weapon, skin = skinName, base = base, a = 0, b = 0, va = 0, vb = 0, names = {}, missed = {}, code = false, codeWait = false, codePrime = false, codeModule = 0 }
    local key = base == "" and weapon or base
    local folder = codeFolder(weapon)
    local codeModule = findChild(folder, skinName)
    local defaultFolder = isDefaultCodeFolder(folder, weapon, key)
    local keyModule = not defaultFolder and key ~= weapon and findChild(folder, key) ~= 0
    local okCode, wait = redirectCode(folder, weapon, key, skinName, rec.names, rec.missed)
    rec.codeWait = wait
    if okCode then rec.code = true end
    if (codeModule ~= 0 or keyModule) and not rec.code and not (defaultFolder and rec.codeWait) then
        undoNames(rec.names); S.unsafe[weapon] = true
        setStatus(false, "%s: code can't run as %s - skipped", skinName, key); return false
    end
    S.unsafe[weapon] = nil
    rec.codePrime = base ~= "" and codeModule ~= 0 and not isLoaded(codeModule) and isDefaultCodeFolder(folder, weapon, weapon)
    if rec.codeWait or rec.codePrime then rec.codeModule = codeModule end
    local va = rp(wep + O.children); local vb = rp(skin + O.children)
    if not swapContents(wep, skin) then undoNames(rec.names); setStatus(false, "%s: swap refused", skinName); return false end
    rec.a = wep; rec.b = skin; rec.va = va; rec.vb = vb
    S.applied[weapon] = rec; writeJournal()
    local effects = 0
    for i = 1, #EFFECT_FOLDERS do
        if redirectName(effectFolder(EFFECT_FOLDERS[i]), key, skinName, true, rec.names, rec.missed) then effects += 1 end
    end
    writeJournal()
    local via = base == "" and weapon or base
    if rec.codeWait then setStatus(true, "%s on default %s — respawn", skinName, weapon)
    elseif S.equipped[weapon] == nil then setStatus(true, "%s on %s — hold it once then re-equip", skinName, weapon)
    else setStatus(true, "%s via %s (%d fx) — respawn", skinName, via, effects) end
    return true
end
function Core.checkSwaps()
    local stale = {}
    for w, ap in pairs(S.applied) do
        local what = nil
        if ap.a ~= 0 and (rp(ap.a + O.children) ~= ap.vb or rp(ap.b + O.children) ~= ap.va) then what = "model" end
        if not what then
            for i = 1, #ap.names do
                local n = ap.names[i]
                if rp(n.a + O.name) ~= n.pb or rp(n.b + O.name) ~= n.pa then what = "name"; break end
            end
        end
        if what == "model" and (rp(ap.a + O.children) == 0 or rp(ap.b + O.children) == 0) then what = nil end
        if what then stale[#stale+1] = w end
    end
    for i = 1, #stale do Core.restoreSwaps(stale[i]); S.retry[stale[i]] = nil end
    local loaded = {}
    for w, ap in pairs(S.applied) do
        if ap.codeWait and ap.codeModule ~= 0 and isLoaded(ap.codeModule) then loaded[#loaded+1] = w end
    end
    for i = 1, #loaded do Core.restoreSwaps(loaded[i]); S.retry[loaded[i]] = nil end
    for w, ap in pairs(S.applied) do
        if ap.codePrime and ap.codeModule ~= 0 and isLoaded(ap.codeModule) then
            ap.codePrime = false
            setStatus(true, "%s code loaded — switch back to default %s now", ap.skin, w)
        end
    end
    return #stale > 0 or #loaded > 0
end
local function defKey(weapon)
    local eq = S.equipped[weapon]; if eq and eq ~= "" then return eq end
    return weapon
end
local SKIN_CODED = { Daggers = true, Crossbow = true, Chainsaw = true, RPG = true, Slingshot = true, Gunblade = true }
local function blocked(weapon, skin, force)
    local eq = defKey(weapon); local ap = S.applied[weapon]
    local swapped = ap and ap.skin == skin and ap.code
    if swapped or eq == skin then return false end
    local folder = codeFolder(weapon); local pick = findChild(folder, skin)
    if not SKIN_CODED[weapon] then
        if not CFG.allowMisfit and missingNeededPartByName(weapon, skin) and not (pick ~= 0 and isLoaded(pick)) then
            if force then setStatus(false, "%s can't go on default %s", skin, weapon) end; return true
        end
        if pick == 0 or not isDefaultCodeFolder(folder, weapon, eq) or isLoaded(pick) or CFG.allowMisfit or modelFits(weapon, skin) then return false end
        if force then setStatus(false, "%s needs its code loaded first", skin) end; return true
    end
    if pick == 0 or not isDefaultCodeFolder(folder, weapon, eq) or isLoaded(pick) then return false end
    if force then setStatus(false, "%s needs its code loaded first", skin) end; return true
end
function Core.applyDefs(weapon, skin)
    local from = defKey(weapon); Core.restoreOverride(weapon)
    if from == skin then
        S.over[weapon] = { skin = skin, from = from, writes = {}, verifiedAt = os.clock() }; return true, false
    end
    setStatus(true, "loading %s animations and sounds…", skin); S.uiDirty = true; task.wait(0.05)
    local writes, why = Defs.redirect(from, skin)
    if not writes then setStatus(false, "%s: %s", skin, why); return false, why == "definitions not loaded yet" end
    S.over[weapon] = { skin = skin, from = from, writes = writes, verifiedAt = os.clock() }
    writeJournal(); setStatus(true, "%s on %s with anims+sounds — respawn", skin, weapon); return true, false
end
function Core.reconcile(force)
    local changed = force; local desired = {}
    for w, s in pairs(S.desired) do desired[w] = s end
    local drop = {}
    for w, ap in pairs(S.applied) do if desired[w] ~= ap.skin then drop[w] = true end end
    for w, ov in pairs(S.over)   do if desired[w] ~= ov.skin then drop[w] = true end end
    for w in pairs(drop) do Core.restore(w); changed = true end
    if S.root.starter ~= 0 and not S.root.fallback and next(desired) then
        if not S.donors or (S.donorMissed and os.clock() - S.donorsAt >= 3) then buildDonors() end
        if S.stopReq then return end
    end
    local now = os.clock()
    for w, skin in pairs(desired) do
        if blocked(w, skin, force) then
            if S.applied[w] or S.over[w] then Core.restore(w); changed = true end
        elseif not S.applied[w] then
            local r = S.retry[w]; if not r then r = { attempts = 0, next = now }; S.retry[w] = r end
            if force or (r.attempts < 10 and now >= r.next) then
                if Core.apply(w, skin) then S.retry[w] = { attempts = 0, next = now }
                else r.attempts += 1; r.next = now + 1.5 end
                if S.unsafe[w] and S.retry[w] then S.retry[w].attempts = 10 end
                changed = true
            end
        end
    end
    for w, skin in pairs(desired) do
        if S.stopReq then break end
        if not blocked(w, skin, false) then
            local ap = S.applied[w]
            if not ap or ap.skin ~= skin then
                if S.over[w] then Core.restoreOverride(w); changed = true end
            else
                local ov = S.over[w]
                local on = ov ~= nil and ov.skin == skin and ov.from == defKey(w) and Defs.stillApplied(ov.writes)
                if on and ov.stale then on = false end
                if not on then
                    local fails = S.defFails[w] or 0; local due = S.defRetry[w] or now
                    if (force and fails == 0) or now >= due then
                        local ok, soon = Core.applyDefs(w, skin)
                        if ok then S.defFails[w] = 0; S.defRetry[w] = now
                        else S.defFails[w] = fails + 1; S.defRetry[w] = os.clock() + (fails >= 2 and 120 or (soon and 10 or 30)) end
                        changed = true
                    end
                end
            end
        end
    end
    if changed then writeJournal(); S.uiDirty = true end
end
function Core.reset(why)
    local r = S.root
    if r and r.datamodel ~= 0 and r.datamodel == (game.Address or 0) then
        for _, ap in pairs(S.applied) do
            if ap.a ~= 0 and rp(ap.a + O.children) == ap.vb and rp(ap.b + O.children) == ap.va then swapContents(ap.a, ap.b) end
            for i = #ap.names, 1, -1 do
                local n = ap.names[i]
                if rp(n.a + O.name) == n.pb and rp(n.b + O.name) == n.pa then swapNames(n.a, n.b) end
            end
        end
    end
    if r and r.datamodel ~= 0 and r.datamodel == (game.Address or 0) then Cos.undoAll()
    else S.cos.applied = { charm = {}, finisher = {} } end
    S.cos.cache = {}; S.cos.retry = {}
    S.applied = {}; S.retry = {}; S.folders = {}
    S.fpB, S.fpE = 0, 0
    S.defRetry = {}; S.defFails = {}; S.donors = nil
    S.root = nil; S.offsetsOk = false
    nameCache = {}; writeJournal(); S.uiDirty = true
    log("asset root reset (%s)", why)
end

function Cos.folders(kind)
    if kind == "charm" then
        local r = S.root
        return findChild(r.assets, "Charms"), findChild(findChild(r.scripts, "Modules"), "Charms")
    end
    local rs = game:GetService("ReplicatedStorage")
    return findChild(findChild(rs and rs.Address or 0, "Modules"), "Finishers"), 0
end
function Cos.scan()
    for _, kind in ipairs({ "charm", "finisher" }) do
        local folder = Cos.folders(kind)
        local h = readVec(folder)
        local c = S.cos.cache[kind]
        if h and not (c and c.b == h.b and c.e == h.e) then
            local names = {}; local list = children(folder)
            for i = 1, #list do names[#names+1] = list[i].name end
            table.sort(names)
            S.cos.cache[kind] = { b = h.b, e = h.e }
            S.cos.lists[kind] = names; S.uiDirty = true
            log("%d %ss found", #names, kind); breathe()
        end
    end
end
function Cos.inPlace(rec)
    if rec.ka and (rp(rec.a + O.children) ~= rec.kb or rp(rec.b + O.children) ~= rec.ka) then return false end
    if rec.na and (rp(rec.ma + O.name) ~= rec.nb or rp(rec.mb + O.name) ~= rec.na) then return false end
    return true
end
function Cos.undo(kind, from)
    local rec = S.cos.applied[kind][from]; if not rec then return end
    if rec.ka then undoKids(rec.a, rec.b, rec.ka, rec.kb, rec.ea, rec.eb) end
    if rec.na and rp(rec.ma + O.name) == rec.nb and rp(rec.mb + O.name) == rec.na then swapNames(rec.ma, rec.mb) end
    S.cos.applied[kind][from] = nil
end
function Cos.undoAll()
    for kind, set in pairs(S.cos.applied) do
        local names = {}
        for from in pairs(set) do names[#names+1] = from end
        for i = 1, #names do Cos.undo(kind, names[i]) end
    end
end
function Cos.busy(kind, from, to)
    for f, rec in pairs(S.cos.applied[kind]) do
        if f ~= from and (f == to or rec.to == from or rec.to == to) then return true end
    end
    return false
end
function Cos.apply(kind, from, to)
    local folder, mods = Cos.folders(kind)
    if folder == 0 then return false, "folder not loaded" end
    local a, b = findChild(folder, from), findChild(folder, to)
    if a == 0 or b == 0 then return false, (a == 0 and from or to) .. " not loaded" end
    local rec = { to = to }
    if kind == "finisher" then
        local na, nb = rp(a + O.name), rp(b + O.name)
        if not swapNames(a, b) then return false, "swap refused" end
        rec.ma, rec.mb, rec.na, rec.nb = a, b, na, nb
    else
        if mods ~= 0 then
            local ma, mb = findChild(mods, from), findChild(mods, to)
            if ma ~= 0 and mb ~= 0 then
                local na, nb = rp(ma + O.name), rp(mb + O.name)
                if swapNames(ma, mb) then rec.ma, rec.mb, rec.na, rec.nb = ma, mb, na, nb end
            end
        end
        local k = swapKids(a, b)
        if not k then if rec.na then swapNames(rec.ma, rec.mb) end; return false, "swap refused" end
        rec.a, rec.b, rec.ka, rec.kb, rec.ea, rec.eb = k.a, k.b, k.ka, k.kb, k.ea, k.eb
    end
    S.cos.applied[kind][from] = rec; return true
end
function Cos.reconcile(force)
    local changed = false; local now = os.clock()
    for _, kind in ipairs({ "charm", "finisher" }) do
        local desired = S.cos.desired[kind]; local applied = S.cos.applied[kind]; local drop = {}
        for from, rec in pairs(applied) do if desired[from] ~= rec.to or not Cos.inPlace(rec) then drop[#drop+1] = from end end
        for i = 1, #drop do Cos.undo(kind, drop[i]); changed = true end
        for from, to in pairs(desired) do
            local key = kind .. "\t" .. from
            if not applied[from] and (force or now >= (S.cos.retry[key] or 0)) then
                if Cos.busy(kind, from, to) then
                    S.cos.retry[key] = now + 2
                else
                    local ok, why = Cos.apply(kind, from, to)
                    if ok then changed = true; S.cos.retry[key] = nil
                        setStatus(true, "%s → %s", from, to)
                    else S.cos.retry[key] = now + 2 end
                end
            end
        end
    end
    if changed then S.uiDirty = true end
    return changed
end

local strCache = {}; local strCacheAt = os.clock()
local function tstr(p)
    if not okp(p) then return nil end
    local c = strCache[p]; if c then return c end
    local len = ru32(p + L.strLen); if len == 0 or len > 64 then return nil end
    local s = bytes(p + L.strText, len); strCache[p] = s; return s
end
local function tfind(t, key)
    if not okp(t) then return nil end
    local lsz = rb(t + L.tLsz); if lsz > 10 then return nil end
    local node = rp(t + L.tNode); if not okp(node) then return nil end
    for i = 0, 2^lsz - 1 do
        local n = node + i * 32
        local kp = rp(n + 16)
        if okp(kp) then
            local ktt = rb(n + 28) % 16
            if rb(kp) == ktt and tstr(kp) == key then return n, rp(n), rb(n + 12) % 16, ktt end
        end
    end
    return nil
end
local function tfindString(t, key)
    local n, v, vtt, ktt = tfind(t, key)
    if not n or vtt ~= ktt or not okp(v) or rb(v) ~= vtt then return nil end
    return tstr(v)
end
local function tfindTable(t, key)
    local n, v, vtt, ktt = tfind(t, key)
    if not n or vtt == ktt or not okp(v) or rb(v) ~= vtt or rb(v) ~= rb(t) then return nil end
    return v
end
function Defs.slots(name)
    local out = {}; local ok, hits = pcall(getgc, name)
    if not ok or type(hits) ~= "table" then return out end
    local seen = {}
    for i = 1, #hits do
        local h = hits[i]; local node = type(h) == "table" and h.addr or nil
        if type(node) == "number" and okp(node) and node % 8 == 0 and not seen[node] then
            seen[node] = true
            local kp = rp(node + 16); local ktt = rb(node + 28) % 16
            if okp(kp) and rb(kp) == ktt and tstr(kp) == name then
                local val = rp(node); local vtt = rb(node + 12) % 16
                if okp(val) and vtt ~= ktt and rb(val) == vtt and tfind(val, "Image") then
                    local kind = 1
                    if tfind(val, "Animations") then kind += 2 end
                    if tfind(val, "Rarity") then kind += 4 end
                    out[#out+1] = { slot = node, value = val, kind = kind, vtt = vtt }
                end
            end
        end
    end
    return out
end
function Defs.sameArray(a, b)
    local lo, hi = math.min(a, b), math.max(a, b)
    local n = (hi - lo) / 32; if n > 8192 then return true end
    local ktt = rb(a + 28) % 16
    for i = 1, n - 1 do
        local node = lo + i * 32
        local kt = rb(node + 28) % 16
        if kt ~= 0 then
            local kp = rp(node + 16)
            if kt ~= ktt or not okp(kp) or rb(kp) ~= ktt then return false end
        end
    end
    return true
end
function Defs.redirect(from, to)
    strCache = {}
    local fs = Defs.slots(from); task.wait(0.05); if S.stopReq then return nil, "stopped" end
    local ts = Defs.slots(to)
    if #fs == 0 or #ts == 0 then return nil, "definitions not loaded yet" end
    local writes = {}; local used = {}
    for i = 1, #fs do
        local f = fs[i]
        if not used[f.slot] then
            local best, bestD = nil, math.huge
            for k = 1, #ts do
                local d = ts[k]
                if d.kind == f.kind and d.vtt == f.vtt and not used[d.slot] then
                    local dist = math.abs(d.slot - f.slot)
                    if dist % 32 == 0 and dist <= 32 * 65536 and dist < bestD then bestD = dist; best = d end
                end
            end
            if best and not Defs.sameArray(f.slot, best.slot) then best = nil end
            if best and best.value ~= f.value and rp(f.slot) == f.value and rp(best.slot) == best.value
                and rb(f.slot + 12) % 16 == f.vtt and rb(best.slot + 12) % 16 == best.vtt then
                used[f.slot] = true; used[best.slot] = true
                wp(f.slot, best.value); wp(best.slot, f.value)
                writes[#writes+1] = { slot = f.slot, orig = f.value, value = best.value }
                writes[#writes+1] = { slot = best.slot, orig = best.value, value = f.value }
            end
        end
    end
    if #writes == 0 then return nil, "no definitions to redirect" end
    return writes
end
function Defs.stillApplied(writes)
    for i = 1, #writes do if rp(writes[i].slot) ~= writes[i].value then return false end end
    return true
end
function Defs.restore(writes)
    for i = #writes, 1, -1 do
        local w = writes[i]; if rp(w.slot) == w.value then wp(w.slot, w.orig) end
    end
end
function Defs.rebuilt(ov)
    strCache = {}; local mine = {}
    for i = 1, #ov.writes do mine[ov.writes[i].slot] = true end
    local slots = Defs.slots(ov.from)
    for i = 1, #slots do if slots[i].kind % 4 >= 2 and not mine[slots[i].slot] then return true end end
    return false
end
function Defs.harvestOwners(seed)
    strCache = {}; local slots = Defs.slots(seed); local start = nil
    for i = 1, #slots do if slots[i].kind >= 4 then start = slots[i] end end
    if not start then return 0 end
    local ktt = rb(start.slot + 28) % 16; local count = 0
    local function visit(n)
        local kp = rp(n + 16); local kt = rb(n + 28) % 16; local vt = rb(n + 12) % 16
        if kt == 0 or vt == 0 then return 0 end
        if kt ~= ktt or not okp(kp) or rb(kp) ~= ktt then return -1 end
        local val = rp(n)
        if vt ~= start.vtt or not okp(val) or rb(val) ~= vt then return -1 end
        local name = tstr(kp)
        if name then
            local item = tfindString(val, "ItemName")
            if item then S.learned[name] = item; count += 1 end
        end
        return 1
    end
    for dir = -1, 1, 2 do
        local empty = 0
        for i = (dir == 1 and 0 or 1), 8192 do
            local r = visit(start.slot + dir * i * 32)
            if r < 0 then break end
            if r == 0 then empty += 1; if empty > 64 then break end
            else empty = 0 end
            if i % 64 == 0 then breathe() end
        end
    end
    return count
end

local Inv = { list = 0, searchedAt = -1000, wait = 30, suspect = false, ok = false, entries = {} }
local function readEntries()
    local list = Inv.list; if not okp(list) then return nil end
    local n = ru32(list + L.tSizeArr); local arr = rp(list + L.tArr)
    if n == 0 or n > 512 or not okp(arr) then return nil end
    local tt = rb(list); local out = {}
    for i = 0, n - 1 do
        local c = arr + i * 16
        if rb(c + 12) % 16 == tt then
            local entry = rp(c)
            if not okp(entry) or rb(entry) ~= tt then return nil end
            local weapon = tfindString(entry, "Name"); if not weapon then return nil end
            local e = { weapon = weapon, skin = "" }
            local skin = tfindTable(entry, "Skin")
            if skin then e.skin = tfindString(skin, "Name") or "" end
            out[#out+1] = e
        end
    end
    if #out == 0 then return nil end
    return out
end
local function findInventory()
    Inv.list = 0; strCache = {}
    local ok, hits = pcall(getgc, "WeaponInventory")
    if not ok or type(hits) ~= "table" then return false end
    for i = 1, #hits do
        local h = hits[i]; local node = type(h) == "table" and h.addr or nil
        if type(node) == "number" and okp(node) then
            local kp = rp(node + 16); local val = rp(node); local vtt = rb(node + 12) % 16
            if okp(kp) and tstr(kp) == "WeaponInventory" and okp(val) and rb(val) == vtt and vtt ~= rb(node + 28) % 16 then
                Inv.list = val; if readEntries() then return true end
            end
        end
    end
    Inv.list = 0; return false
end
local function readInventory(allowSearch)
    local entries = readEntries(); local since = os.clock() - Inv.searchedAt
    if allowSearch and ((not entries and since >= Inv.wait) or (Inv.suspect and since >= 15)) then
        Inv.searchedAt = os.clock(); Inv.suspect = false
        if findInventory() then entries = readEntries(); Inv.wait = 30
        else entries = nil; Inv.wait = math.min(Inv.wait * 2, 300) end
    end
    Inv.ok = entries ~= nil; Inv.entries = entries or {}
    return Inv.ok
end
local function setEquipped(weapon, cosmetic, changed, source)
    if S.equipped[weapon] == cosmetic then return end
    S.equipped[weapon] = cosmetic; changed[#changed+1] = weapon; S.uiDirty = true
end
local function observeInventory(changed)
    local wset = {}; for i = 1, #S.weapons do wset[S.weapons[i]] = true end
    local inv = {}
    for i = 1, #Inv.entries do
        local e = Inv.entries[i]
        if wset[e.weapon] then
            inv[e.weapon] = true
            local cosmetic = e.skin; if cosmetic == e.weapon then cosmetic = "" end
            setEquipped(e.weapon, cosmetic, changed, "inventory")
        end
    end
    S.invWeapons = inv
end
local function observeHeld(changed)
    local ws = game:GetService("Workspace")
    local fp = findChild(findChild(ws and ws.Address or 0, "ViewModels"), "FirstPerson")
    local h = readVec(fp); if not h then return end
    if h.b == S.fpB and h.e == S.fpE then return end
    S.fpB, S.fpE = h.b, h.e
    local wset = {}; for i = 1, #S.weapons do wset[S.weapons[i]] = true end
    local list = children(fp)
    for i = 1, #list do
        local name = list[i].name
        local a = string.find(name, " - ", 1, true)
        if a then
            local b = string.find(name, " - ", a + 3, true)
            local weapon = b and string.sub(name, a + 3, b - 1) or string.sub(name, a + 3)
            if wset[weapon] then
                local cosmetic = b and string.sub(name, b + 3) or ""
                if cosmetic == weapon then cosmetic = "" end
                if not S.invWeapons[weapon] then setEquipped(weapon, cosmetic, changed, "held")
                elseif S.equipped[weapon] ~= cosmetic then Inv.suspect = true end
            end
        end
    end
end

-- picks
local function pick(weapon, name)
    if not weapon then return end
    if name == nil or name == "(default)" or S.desired[weapon] == name then
        if S.desired[weapon] == nil then return end
        S.desired[weapon] = nil
        S.queue[#S.queue + 1] = { cmd = "restore", weapon = weapon }
    else
        S.desired[weapon] = name
        S.queue[#S.queue + 1] = { cmd = "apply", weapon = weapon, skin = name }
    end
    S.desiredChanged = true; S.uiDirty = true; savePicks()
end
local function pickCos(kind, from, to)
    local set = S.cos.desired[kind]; if not from or not set then return end
    if to == nil or to == "(default)" or to == from or set[from] == to then
        if set[from] == nil then return end; set[from] = nil
    else set[from] = to; S.cos.retry[kind .. "\t" .. from] = nil end
    S.desiredChanged = true; S.uiDirty = true; saveCos()
end
local function uiKind()
    if UI.cat == "Charms" then return "charm" end
    if UI.cat == "Finishers" then return "finisher" end
    return nil
end
local function clearAll()
    S.cos.desired = { charm = {}, finisher = {} }; saveCos()
    S.desired = {}; S.queue[#S.queue+1] = { cmd = "restoreall" }
    S.desiredChanged = true; S.uiDirty = true; savePicks()
end

-- ================== 616 UI ==================
local function host()
    local ok, g = pcall(function() return gethui() end)
    if ok and g then return g end
    return LP:WaitForChild("PlayerGui")
end
for _, n in ipairs({"616_UI","616_LOGO","616_BACKDROP"}) do
    local old = host():FindFirstChild(n); if old then old:Destroy() end
end

local ACC      = Color3.fromRGB(240,40,60)
local ACC_DIM  = Color3.fromRGB(150,20,35)
local ACC_DARK = Color3.fromRGB(60,8,14)
local BG       = Color3.fromRGB(8,8,10)
local PANEL    = Color3.fromRGB(16,16,20)
local PANEL2   = Color3.fromRGB(24,24,30)
local PANEL3   = Color3.fromRGB(34,34,42)
local TEXT     = Color3.fromRGB(245,245,250)
local MUTED    = Color3.fromRGB(130,130,145)
local function corner(i,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=i; return c end
local function stroke(i,t,col,tr) local s=Instance.new("UIStroke"); s.Thickness=t or 1; s.Color=col or ACC; s.Transparency=tr or 0; s.Parent=i; return s end
local function pad(i,p,l,r,b) local u=Instance.new("UIPadding"); u.PaddingTop=UDim.new(0,p); u.PaddingBottom=UDim.new(0,b or p); u.PaddingLeft=UDim.new(0,l or p); u.PaddingRight=UDim.new(0,r or p); u.Parent=i end
local function grad(parent,c1,c2,rot)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(1,c2)})
    g.Rotation=rot or 90; g.Parent=parent; return g
end

local Backdrop = Instance.new("ScreenGui"); Backdrop.Name="616_BACKDROP"; Backdrop.IgnoreGuiInset=true
Backdrop.DisplayOrder=9998; Backdrop.ResetOnSpawn=false; Backdrop.Parent=host()
local dim = Instance.new("Frame"); dim.Size=UDim2.fromScale(1,1); dim.BackgroundColor3=Color3.new(0,0,0)
dim.BackgroundTransparency=1; dim.BorderSizePixel=0; dim.Parent=Backdrop
grad(dim, Color3.fromRGB(14,0,4), Color3.new(0,0,0), 135)
local block = Instance.new("TextButton"); block.Size=UDim2.fromScale(1,1); block.BackgroundTransparency=1
block.Text=""; block.AutoButtonColor=false; block.Modal=true; block.Parent=Backdrop

-- spinning 616 center
local LogoGui = Instance.new("ScreenGui"); LogoGui.Name="616_LOGO"; LogoGui.IgnoreGuiInset=true
LogoGui.DisplayOrder=9999; LogoGui.ResetOnSpawn=false; LogoGui.Parent=host()
local ringHost = Instance.new("Frame"); ringHost.AnchorPoint=Vector2.new(0.5,0.5); ringHost.Position=UDim2.fromScale(0.5,0.5)
ringHost.Size=UDim2.fromOffset(460,460); ringHost.BackgroundTransparency=1; ringHost.Parent=LogoGui
local outerRing = Instance.new("Frame"); outerRing.AnchorPoint=Vector2.new(0.5,0.5); outerRing.Position=UDim2.fromScale(0.5,0.5)
outerRing.Size=UDim2.fromScale(1,1); outerRing.BackgroundTransparency=1; outerRing.Parent=ringHost
corner(outerRing,9999); stroke(outerRing,1,ACC,0.65)
local midRing = Instance.new("Frame"); midRing.AnchorPoint=Vector2.new(0.5,0.5); midRing.Position=UDim2.fromScale(0.5,0.5)
midRing.Size=UDim2.fromScale(0.82,0.82); midRing.BackgroundTransparency=1; midRing.Parent=ringHost
for i=0,35 do
    local t=Instance.new("Frame"); t.AnchorPoint=Vector2.new(0.5,0.5)
    t.Size=UDim2.fromOffset(2, i%3==0 and 18 or 10)
    t.BackgroundColor3=ACC; t.BackgroundTransparency = i%3==0 and 0.1 or 0.55
    t.BorderSizePixel=0; t.Rotation=i*10
    local a=math.rad(i*10-90); local r=180
    t.Position=UDim2.fromScale(0.5,0.5)+UDim2.fromOffset(math.cos(a)*r,math.sin(a)*r)
    t.Parent=midRing
end
local innerRing = Instance.new("Frame"); innerRing.AnchorPoint=Vector2.new(0.5,0.5); innerRing.Position=UDim2.fromScale(0.5,0.5)
innerRing.Size=UDim2.fromScale(0.62,0.62); innerRing.BackgroundTransparency=1; innerRing.Parent=ringHost
corner(innerRing,9999); stroke(innerRing,2,ACC,0.2)
local halo = Instance.new("Frame"); halo.AnchorPoint=Vector2.new(0.5,0.5); halo.Position=UDim2.fromScale(0.5,0.5)
halo.Size=UDim2.fromScale(0.5,0.5); halo.BackgroundColor3=ACC_DARK; halo.BackgroundTransparency=0.4
halo.BorderSizePixel=0; halo.Parent=ringHost; corner(halo,9999)
grad(halo, ACC, Color3.fromRGB(80,0,10), 90)
local logo = Instance.new("TextLabel"); logo.AnchorPoint=Vector2.new(0.5,0.5); logo.Position=UDim2.fromScale(0.5,0.5)
logo.Size=UDim2.fromOffset(320,220); logo.BackgroundTransparency=1; logo.Text="616"
logo.Font=Enum.Font.GothamBlack; logo.TextSize=180; logo.TextColor3=TEXT
logo.TextStrokeTransparency=0.3; logo.TextStrokeColor3=ACC; logo.Parent=ringHost
grad(logo, Color3.fromRGB(255,80,100), ACC, 90)
local sub = Instance.new("TextLabel"); sub.AnchorPoint=Vector2.new(0.5,0)
sub.Position=UDim2.new(0.5,0,0.5,110); sub.Size=UDim2.fromOffset(300,24)
sub.BackgroundTransparency=1; sub.Font=Enum.Font.GothamBold; sub.TextSize=12
sub.Text="S I X   O N E   S I X"; sub.TextColor3=ACC; sub.TextTransparency=0.3
sub.Parent=ringHost

Backdrop.Enabled=false; LogoGui.Enabled=false
local spinConn
local function startSpin()
    if spinConn then return end
    spinConn = RunService.RenderStepped:Connect(function(dt)
        midRing.Rotation   = (midRing.Rotation   + dt*45) % 360
        outerRing.Rotation = (outerRing.Rotation - dt*20) % 360
        innerRing.Rotation = (innerRing.Rotation + dt*35) % 360
        local p = math.sin(tick()*2)*0.5+0.5
        halo.BackgroundTransparency = 0.35 + p*0.25
        halo.Size = UDim2.fromScale(0.48 + p*0.06, 0.48 + p*0.06)
        logo.TextStrokeTransparency = 0.25 + p*0.3
    end)
end
local function stopSpin() if spinConn then spinConn:Disconnect(); spinConn=nil end end

-- main window
local Main = Instance.new("ScreenGui"); Main.Name="616_UI"; Main.IgnoreGuiInset=true
Main.DisplayOrder=10000; Main.ResetOnSpawn=false; Main.Parent=host()
local win = Instance.new("Frame"); win.AnchorPoint=Vector2.new(0.5,0.5); win.Position=UDim2.fromScale(0.5,0.5)
win.Size=UDim2.fromOffset(940,620); win.BackgroundColor3=BG; win.BorderSizePixel=0; win.Parent=Main
corner(win,14); stroke(win,1,ACC_DARK,0.2)
grad(win, Color3.fromRGB(14,10,12), Color3.fromRGB(8,6,8), 135)

local hdr = Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,64); hdr.BackgroundColor3=PANEL
hdr.BorderSizePixel=0; hdr.Parent=win; corner(hdr,14)
grad(hdr, Color3.fromRGB(22,14,18), Color3.fromRGB(14,10,12), 90)

local chip = Instance.new("Frame"); chip.Size=UDim2.fromOffset(72,40); chip.Position=UDim2.fromOffset(16,12)
chip.BackgroundColor3=ACC; chip.BorderSizePixel=0; chip.Parent=hdr; corner(chip,8)
grad(chip, Color3.fromRGB(255,60,80), ACC_DIM, 135)
stroke(chip, 1, Color3.fromRGB(255,120,140), 0.5)
local chipTxt=Instance.new("TextLabel"); chipTxt.Size=UDim2.fromScale(1,1); chipTxt.BackgroundTransparency=1
chipTxt.Font=Enum.Font.GothamBlack; chipTxt.TextSize=22; chipTxt.Text="616"
chipTxt.TextColor3=Color3.fromRGB(255,255,255); chipTxt.TextStrokeTransparency=0.5
chipTxt.TextStrokeColor3=ACC_DARK; chipTxt.Parent=chip

local subt=Instance.new("TextLabel"); subt.Size=UDim2.new(1,-520,0,20); subt.Position=UDim2.fromOffset(100,14)
subt.BackgroundTransparency=1; subt.Font=Enum.Font.GothamBold; subt.TextSize=14
subt.Text="rivals skinchanger"; subt.TextColor3=TEXT
subt.TextXAlignment=Enum.TextXAlignment.Left; subt.Parent=hdr
local subt2=Instance.new("TextLabel"); subt2.Size=UDim2.new(1,-520,0,18); subt2.Position=UDim2.fromOffset(100,34)
subt2.BackgroundTransparency=1; subt2.Font=Enum.Font.Gotham; subt2.TextSize=11
subt2.Text="RIGHT SHIFT  toggle"; subt2.TextColor3=MUTED
subt2.TextXAlignment=Enum.TextXAlignment.Left; subt2.Parent=hdr

local function hbtn(text, x, w, cb, fill)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(w,34); b.Position=UDim2.new(1,-x,0,15)
    b.BackgroundColor3=fill and ACC_DIM or PANEL2; b.BorderSizePixel=0
    b.Text=text; b.Font=Enum.Font.GothamSemibold; b.TextSize=12
    b.TextColor3=TEXT; b.AutoButtonColor=false; b.Parent=hdr; corner(b,7)
    stroke(b, 1, fill and ACC or ACC_DARK, fill and 0.3 or 0.6)
    local idle = fill and ACC_DIM or PANEL2
    b.MouseEnter:Connect(function() TS:Create(b, TweenInfo.new(0.12), {BackgroundColor3=ACC}):Play() end)
    b.MouseLeave:Connect(function() TS:Create(b, TweenInfo.new(0.12), {BackgroundColor3=idle}):Play() end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

local selectedWeapon = nil
local bR = hbtn("Rescan",     360, 92, function() Core.scan(); Cos.scan(); S.uiDirty=true end)
local bX = hbtn("Restore",    258, 92, function()
    if selectedWeapon then
        local k=uiKind(); if k then pickCos(k, selectedWeapon, "(default)") else pick(selectedWeapon, "(default)") end
    end
end)
local bCl= hbtn("Clear all",  156, 92, function() clearAll() end, true)
local bC = hbtn("×",           46, 34)
bC.Font=Enum.Font.GothamBold; bC.TextSize=20

-- tabs
local tabStrip = Instance.new("Frame"); tabStrip.Size=UDim2.new(1,-28,0,36); tabStrip.Position=UDim2.fromOffset(14,74)
tabStrip.BackgroundTransparency=1; tabStrip.Parent=win
local tLay = Instance.new("UIListLayout"); tLay.FillDirection=Enum.FillDirection.Horizontal
tLay.Padding=UDim.new(0,4); tLay.Parent=tabStrip
local tabButtons, tabBars = {}, {}
for _, cat in ipairs(CATEGORIES) do
    local t = Instance.new("TextButton")
    t.Size = UDim2.fromOffset(#cat*7 + 24, 32)
    t.BackgroundColor3 = cat == UI.cat and PANEL3 or PANEL
    t.BorderSizePixel = 0; t.Text = cat; t.Font = Enum.Font.GothamSemibold
    t.TextSize = 12; t.TextColor3 = cat == UI.cat and TEXT or MUTED
    t.AutoButtonColor = false; t.Parent = tabStrip; corner(t, 7)
    local bar = Instance.new("Frame"); bar.Size=UDim2.new(1,-16,0,2); bar.Position=UDim2.new(0,8,1,-4)
    bar.BackgroundColor3=ACC; bar.BorderSizePixel=0; bar.Visible = cat == UI.cat; bar.Parent=t; corner(bar,2)
    tabButtons[cat] = t; tabBars[cat] = bar
    t.MouseButton1Click:Connect(function()
        UI.cat = cat; selectedWeapon = nil
        for n, b in pairs(tabButtons) do
            b.BackgroundColor3 = n == cat and PANEL3 or PANEL
            b.TextColor3 = n == cat and TEXT or MUTED
            tabBars[n].Visible = n == cat
        end
        S.uiDirty = true
    end)
    t.MouseEnter:Connect(function() if cat ~= UI.cat then t.TextColor3 = TEXT end end)
    t.MouseLeave:Connect(function() if cat ~= UI.cat then t.TextColor3 = MUTED end end)
end

-- body
local body = Instance.new("Frame"); body.Size=UDim2.new(1,0,1,-64-36-56); body.Position=UDim2.fromOffset(0,114)
body.BackgroundTransparency=1; body.Parent=win

local side = Instance.new("Frame"); side.Size=UDim2.new(0,260,1,-20); side.Position=UDim2.fromOffset(14,10)
side.BackgroundColor3=PANEL; side.BorderSizePixel=0; side.Parent=body; corner(side,12); pad(side,14,12,12,12)
stroke(side, 1, ACC_DARK, 0.5)
grad(side, Color3.fromRGB(20,16,18), PANEL, 90)
local sT=Instance.new("TextLabel"); sT.Size=UDim2.new(1,0,0,16); sT.BackgroundTransparency=1
sT.Font=Enum.Font.GothamBold; sT.TextSize=10; sT.Text="WEAPON  ·  PICK ONE"; sT.TextColor3=ACC
sT.TextXAlignment=Enum.TextXAlignment.Left; sT.Parent=side
local wList=Instance.new("ScrollingFrame"); wList.Size=UDim2.new(1,0,1,-24); wList.Position=UDim2.fromOffset(0,22)
wList.BackgroundTransparency=1; wList.BorderSizePixel=0; wList.CanvasSize=UDim2.fromOffset(0,0)
wList.AutomaticCanvasSize=Enum.AutomaticSize.Y; wList.ScrollBarThickness=4; wList.ScrollBarImageColor3=ACC
wList.ScrollBarImageTransparency=0.4; wList.Parent=side
local wL=Instance.new("UIListLayout"); wL.Padding=UDim.new(0,4); wL.Parent=wList

local right=Instance.new("Frame"); right.Size=UDim2.new(1,-288,1,-20); right.Position=UDim2.fromOffset(282,10)
right.BackgroundColor3=PANEL; right.BorderSizePixel=0; right.Parent=body; corner(right,12); pad(right,14)
stroke(right, 1, ACC_DARK, 0.5)
grad(right, Color3.fromRGB(20,16,18), PANEL, 90)
local search=Instance.new("TextBox"); search.Size=UDim2.new(1,0,0,36); search.BackgroundColor3=PANEL2
search.BorderSizePixel=0; search.Font=Enum.Font.Gotham; search.TextSize=13; search.PlaceholderText="search skins…"
search.Text=""; search.ClearTextOnFocus=false; search.TextColor3=TEXT; search.PlaceholderColor3=MUTED
search.TextXAlignment=Enum.TextXAlignment.Left; search.Parent=right; corner(search,8); pad(search,8,12,12,8)
local sStroke = stroke(search, 1, ACC_DARK, 0.4)
search.Focused:Connect(function() TS:Create(sStroke, TweenInfo.new(0.2), {Transparency=0.1, Color=ACC}):Play() end)
search.FocusLost:Connect(function() TS:Create(sStroke, TweenInfo.new(0.2), {Transparency=0.4, Color=ACC_DARK}):Play() end)
local sScroll=Instance.new("ScrollingFrame"); sScroll.Size=UDim2.new(1,0,1,-48); sScroll.Position=UDim2.fromOffset(0,44)
sScroll.BackgroundTransparency=1; sScroll.BorderSizePixel=0; sScroll.CanvasSize=UDim2.fromOffset(0,0)
sScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; sScroll.ScrollBarThickness=4; sScroll.ScrollBarImageColor3=ACC
sScroll.ScrollBarImageTransparency=0.4; sScroll.Parent=right
local grid=Instance.new("UIGridLayout"); grid.CellSize=UDim2.fromOffset(196,62); grid.CellPadding=UDim2.fromOffset(8,8)
grid.SortOrder=Enum.SortOrder.Name; grid.Parent=sScroll

-- footer
local footer = Instance.new("Frame"); footer.Size=UDim2.new(1,-28,0,44); footer.Position=UDim2.new(0,14,1,-50)
footer.BackgroundColor3=PANEL; footer.BorderSizePixel=0; footer.Parent=win; corner(footer,10); pad(footer,10,14,14,10)
stroke(footer, 1, ACC_DARK, 0.6)
local dot = Instance.new("Frame"); dot.Size=UDim2.fromOffset(10,10); dot.Position=UDim2.fromOffset(0,7)
dot.BackgroundColor3=ACC; dot.BorderSizePixel=0; dot.Parent=footer
corner(dot, 9999); local dotStroke = stroke(dot, 2, ACC, 0.6)
local status=Instance.new("TextLabel"); status.Size=UDim2.new(1,-24,1,0); status.Position=UDim2.fromOffset(20,0)
status.BackgroundTransparency=1; status.Font=Enum.Font.GothamSemibold; status.TextSize=12
status.Text=""; status.TextColor3=TEXT; status.TextXAlignment=Enum.TextXAlignment.Left; status.Parent=footer

local function clearKids(p)
    for _, c in ipairs(p:GetChildren()) do
        if not (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient")) then
            c:Destroy()
        end
    end
end

local function renderWeapons()
    clearKids(wList)
    local kind = uiKind()
    local list = {}
    if kind then list = S.cos.lists[kind] or {}
    else
        for i = 1, #S.weapons do
            local w = S.weapons[i]
            local c = CATEGORY[w] or "Utility"
            if UI.cat == "All" or c == UI.cat then list[#list+1] = w end
        end
    end
    local desired = kind and S.cos.desired[kind] or S.desired
    for _, w in ipairs(list) do
        local b = Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,32)
        local sel = w == selectedWeapon
        b.BackgroundColor3 = sel and ACC_DIM or PANEL2
        b.BorderSizePixel = 0; b.Text=""; b.AutoButtonColor=false
        b.Parent = wList; corner(b, 7)
        if sel then grad(b, ACC, ACC_DIM, 90); stroke(b,1,ACC,0.2) else stroke(b,1,ACC_DARK,0.7) end
        local lbl = Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-100,1,0); lbl.Position=UDim2.fromOffset(12,0)
        lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=12
        lbl.Text=w; lbl.TextColor3=sel and TEXT or Color3.fromRGB(210,210,220)
        lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=b
        local d = desired[w]
        if d then
            local mark = Instance.new("TextLabel")
            mark.Size = UDim2.new(0, 84, 1, 0); mark.Position = UDim2.new(1, -92, 0, 0)
            mark.BackgroundTransparency=1; mark.Font=Enum.Font.GothamBold; mark.TextSize=9
            mark.Text = d; mark.TextColor3 = sel and TEXT or ACC
            mark.TextXAlignment=Enum.TextXAlignment.Right; mark.TextTruncate=Enum.TextTruncate.AtEnd
            mark.Parent = b
        end
        if not sel then
            b.MouseEnter:Connect(function() TS:Create(b, TweenInfo.new(0.1), {BackgroundColor3=PANEL3}):Play() end)
            b.MouseLeave:Connect(function() TS:Create(b, TweenInfo.new(0.1), {BackgroundColor3=PANEL2}):Play() end)
        end
        b.MouseButton1Click:Connect(function() selectedWeapon = w; S.uiDirty = true end)
    end
    if #list == 0 then
        local e = Instance.new("TextLabel"); e.Size=UDim2.new(1,0,0,80); e.BackgroundTransparency=1
        e.Font=Enum.Font.GothamSemibold; e.TextSize=12; e.LayoutOrder=1
        e.Text = rootValid(S.root) and "— empty —" or "join a match"
        e.TextColor3=MUTED; e.TextWrapped=true; e.Parent=wList
    end
end

local function renderSkins()
    clearKids(sScroll)
    if not selectedWeapon then
        grid.Parent = nil
        local wrap = Instance.new("Frame"); wrap.Size=UDim2.fromScale(1,1); wrap.BackgroundTransparency=1; wrap.Parent=sScroll
        local e = Instance.new("TextLabel"); e.AnchorPoint=Vector2.new(0.5,0.5)
        e.Position=UDim2.fromScale(0.5,0.5); e.Size=UDim2.fromOffset(320,60)
        e.BackgroundTransparency=1; e.Font=Enum.Font.GothamSemibold; e.TextSize=14
        e.Text = rootValid(S.root) and "pick a weapon from the list" or "join a Rivals match first"
        e.TextColor3=MUTED; e.Parent=wrap
        return
    end
    grid.Parent = sScroll
    local kind = uiKind()
    local items = { "(default)" }
    local list = kind and S.cos.lists[kind] or S.skinsByWeapon[selectedWeapon]
    if list then
        for _, n in ipairs(list) do if n ~= selectedWeapon then items[#items+1] = n end end
    end
    local desired = kind and S.cos.desired[kind] or S.desired
    local picked = desired[selectedWeapon]
    local q = search.Text:lower()
    for _, name in ipairs(items) do
        local show = q == "" or name:lower():find(q, 1, true) or name == "(default)"
        if show then
            local chosen = (name == "(default)" and picked == nil) or name == picked
            local card = Instance.new("TextButton")
            card.BackgroundColor3 = chosen and ACC_DIM or PANEL2
            card.BorderSizePixel = 0; card.Text = ""; card.AutoButtonColor = false
            card.Parent = sScroll; corner(card, 9)
            if chosen then grad(card, ACC, ACC_DIM, 135); stroke(card, 1, Color3.fromRGB(255,120,140), 0.4)
            else stroke(card, 1, ACC_DARK, 0.65) end
            local accentBar = Instance.new("Frame"); accentBar.Size=UDim2.new(0,3,1,-16); accentBar.Position=UDim2.fromOffset(6,8)
            accentBar.BackgroundColor3=chosen and TEXT or ACC; accentBar.BorderSizePixel=0
            accentBar.BackgroundTransparency=chosen and 0 or 0.4; accentBar.Parent=card; corner(accentBar,2)
            local n = Instance.new("TextLabel"); n.Size=UDim2.new(1,-24,0,20); n.Position=UDim2.fromOffset(16,10)
            n.BackgroundTransparency=1; n.Font=Enum.Font.GothamBold; n.TextSize=13
            n.Text = name; n.TextColor3 = chosen and TEXT or Color3.fromRGB(230,230,240)
            n.TextXAlignment=Enum.TextXAlignment.Left; n.TextTruncate=Enum.TextTruncate.AtEnd
            n.Parent=card
            local st = Instance.new("TextLabel"); st.Size=UDim2.new(1,-24,0,14); st.Position=UDim2.fromOffset(16,32)
            st.BackgroundTransparency=1; st.Font=Enum.Font.GothamSemibold; st.TextSize=9
            local lbl = "TAP TO EQUIP"
            if chosen then
                if kind then
                    local rec = S.cos.applied[kind] and S.cos.applied[kind][selectedWeapon]
                    lbl = (rec and rec.to == name) and "APPLIED" or "WAITING"
                else
                    local ap = S.applied[selectedWeapon]; local ov = S.over[selectedWeapon]
                    if name == "(default)" then lbl = "DEFAULT"
                    elseif ap and ap.skin == name then lbl = (ov and ov.skin == name) and "APPLIED" or "MODEL ONLY"
                    else lbl = "WAITING" end
                end
            end
            st.Text = lbl; st.TextColor3 = chosen and Color3.fromRGB(255,220,225) or MUTED
            st.TextXAlignment=Enum.TextXAlignment.Left; st.Parent=card
            if not chosen then
                card.MouseEnter:Connect(function() TS:Create(card, TweenInfo.new(0.1), {BackgroundColor3=PANEL3}):Play() end)
                card.MouseLeave:Connect(function() TS:Create(card, TweenInfo.new(0.1), {BackgroundColor3=PANEL2}):Play() end)
            end
            card.MouseButton1Click:Connect(function()
                if kind then pickCos(kind, selectedWeapon, name)
                else pick(selectedWeapon, name) end
            end)
        end
    end
end

local function renderStatus()
    status.Text = S.status or ""
    local col = S.statusOk and ACC or Color3.fromRGB(240,180,40)
    dot.BackgroundColor3 = col; dotStroke.Color = col
end

local function refresh() renderWeapons(); renderSkins(); renderStatus() end
search:GetPropertyChangedSignal("Text"):Connect(renderSkins)

local function setOpen(v)
    UI.open = v
    Backdrop.Enabled = v; LogoGui.Enabled = v; Main.Enabled = v
    if v then
        startSpin()
        TS:Create(dim, TweenInfo.new(0.3), {BackgroundTransparency = 0.3}):Play()
        win.Size = UDim2.fromOffset(880, 580)
        TS:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(940,620)}):Play()
        refresh()
    else
        stopSpin(); dim.BackgroundTransparency = 1
    end
end
setOpen(CFG.startOpen)
bC.MouseButton1Click:Connect(function() setOpen(false) end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CFG.toggleKey then setOpen(not UI.open)
    elseif input.KeyCode == Enum.KeyCode.End and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        S.stopReq = true
    end
end)

-- refresh pump
task.spawn(function()
    while S.running and not S.dead do
        if UI.open and S.uiDirty then S.uiDirty = false; pcall(refresh) end
        task.wait(0.15)
    end
end)

-- ================== finalize + tick ==================
local function finalize()
    if S.dead then return end
    S.dead = true; S.running = false
    pcall(Core.restoreAll); pcall(writeJournal)
    stopSpin()
    pcall(function() Main:Destroy() end)
    pcall(function() LogoGui:Destroy() end)
    pcall(function() Backdrop:Destroy() end)
end

local T = { checkAt = 0, invAt = 0, swapsAt = 0, recAt = 0 }
local function tick()
    local work = S.queue; S.queue = {}
    if S.desiredChanged then S.picksPending = true end
    S.desiredChanged = false
    local desiredChanged = S.picksPending

    local dm = game.Address or 0
    if not okp(dm) then if rootValid(S.root) then Core.reset("no datamodel") end; return end
    if not S.journalChecked then S.journalChecked = true; undoJournal() end
    if dm ~= S.world then
        if S.world ~= 0 then
            S.over = {}; S.defRetry = {}; S.defFails = {}
            Inv.list = 0; Inv.searchedAt = -1000; Inv.wait = 30
            S.ownersTried = false; S.ownerTries = 0; S.ownersRetryAt = nil
            strCache = {}; writeJournal(); S.picksPending = true; desiredChanged = true
        end
        S.world = dm
    end
    local now = os.clock()
    if now - nameCacheAt > 3 then nameCache = {}; nameCacheAt = now end
    if now - strCacheAt  > 5 then strCache  = {}; strCacheAt  = now end

    if #work > 0 or desiredChanged or now - T.checkAt >= 0.5 then
        T.checkAt = now
        if not stillValid(S.root) then
            if rootValid(S.root) then Core.reset("viewmodels rebuilt") end
            S.root = resolve()
            if rootValid(S.root) then
                local ok, what = validateOffsets(S.root)
                S.offsetsOk = ok
                if ok then S.loadedOk = deriveLoaded(S.root); Core.scan()
                else log("offset check failed: %s", tostring(what)) end
            else S.root = nil; setStatus(false, "join a match") end
        elseif UI.open and now - (S.scanAt or 0) >= 3 then Core.scan() end
    end
    if not rootValid(S.root) then
        if #work > 0 then setStatus(false, "join a match first") end
        return
    end
    if (not S.offsetsOk or not S.loadedOk) and now - (T.validAt or 0) >= 3 then
        T.validAt = now
        if not S.offsetsOk then
            local ok, what = validateOffsets(S.root)
            S.offsetsOk = ok; S.offsetFails = ok and 0 or (S.offsetFails or 0) + 1
            if ok then Core.scan() else log("offset: %s", tostring(what)) end
        end
        if S.offsetsOk and not S.loadedOk then S.loadedOk = deriveLoaded(S.root) end
    end
    if not S.offsetsOk then
        if (S.offsetFails or 0) >= 2 then setStatus(false, "offsets don't match this build") end
        return
    end
    if S.ownersRetryAt and now >= S.ownersRetryAt then S.ownersRetryAt = nil; S.ownersTried = false end
    if not S.ownersTried and #S.skins > 0 then
        S.ownersTried = true
        local seed, any, unknown = nil, nil, 0
        for i = 1, #S.skins do
            local si = S.skins[i]; any = any or si.name
            if si.weapon ~= "" then seed = seed or si.name
            elseif S.learned[si.name] == nil then unknown += 1 end
        end
        seed = seed or any
        local first = S.status == "starting"
        if unknown > 0 and seed then
            setStatus(true, "reading skin list (%d skins)…", unknown); task.wait(0.05)
            local n = Defs.harvestOwners(seed)
            if n > 0 then
                for i = 1, #S.skins do
                    local si = S.skins[i]
                    if si.weapon == "" and S.learned[si.name] == nil then S.learned[si.name] = "?" end
                end
                S.skins = {}; Core.scan()
            else
                S.ownerTries = (S.ownerTries or 0) + 1
                S.ownersRetryAt = os.clock() + (S.ownerTries < 10 and 15 or 60)
            end
            first = true
        end
        if first then setStatus(true, "%d weapons, %d skins — ready", #S.weapons, #S.skins) end
    end

    local force = false; local changed = {}
    if now - T.invAt >= 0.5 then
        T.invAt = now
        local want = S.enabled and next(S.desired) ~= nil
        if readInventory(want) then observeInventory(changed) else S.invWeapons = {} end
    end
    observeHeld(changed)
    for i = 1, #changed do
        local w = changed[i]
        S.defFails[w] = nil
        if S.over[w] then force = true end
        if S.unsafe[w] then S.unsafe[w] = nil; S.retry[w] = nil; force = true end
        local ap = S.applied[w]
        if ap and ap.base ~= S.equipped[w] then Core.restoreSwaps(w); S.retry[w] = nil; force = true end
    end
    if #changed > 0 and next(S.over) then S.verifyAt = now + 1.5 end

    for i = 1, #work do
        local q = work[i]
        if q.cmd == "apply" then
            S.retry[q.weapon] = nil; S.defRetry[q.weapon] = nil; S.defFails[q.weapon] = nil
            if not S.skinIndex[q.skin] then Core.scan() end
            force = true
        elseif q.cmd == "restore" then
            Core.restore(q.weapon); writeJournal(); setStatus(true, "%s restored", q.weapon)
        elseif q.cmd == "restoreall" then
            Core.restoreAll(); writeJournal(); setStatus(true, "all restored")
        end
    end
    if not S.enabled then
        if S.wasEnabled or next(S.applied) or next(S.over) or next(S.cos.applied.charm) or next(S.cos.applied.finisher) then
            Core.restoreAll(); writeJournal(); setStatus(true, "off — all restored")
        end
        S.wasEnabled = false; return
    end
    if S.root.fallback then
        local picks = 0
        for _ in pairs(S.desired) do picks += 1 end
        if picks > 0 then setStatus(true, "waiting for scripts (%d picks)", picks) end
        return
    end
    if not S.wasEnabled then force = true; S.retry = {} end
    S.wasEnabled = true
    if now - T.swapsAt >= 2 then T.swapsAt = now; if Core.checkSwaps() then force = true end end
    if S.verifyAt and now >= S.verifyAt then
        S.verifyAt = nil
        for w, ov in pairs(S.over) do
            if #ov.writes > 0 and Defs.rebuilt(ov) then ov.stale = true; S.defFails[w] = 0; S.defRetry[w] = now end
            task.wait(0.05); if S.stopReq then return end
        end
    end
    if S.catalogGrew then
        S.catalogGrew = false
        if not S.ownersRetryAt then S.ownersTried = false end
        S.retry = {}; S.defRetry = {}; S.defFails = {}
    end
    if force or desiredChanged or now - T.recAt >= 0.5 then
        T.recAt = now
        if now - (T.cosAt or 0) >= 3 then T.cosAt = now; Cos.scan() end
        if Cos.reconcile(force or desiredChanged) then writeJournal() end
        Core.reconcile(force or desiredChanged)
        S.picksPending = false
    end
end

_G.RivalsSkins = {
    state = S, pick = pick, pickCos = pickCos, clearAll = clearAll,
    stop = function() S.stopReq = true; if not S.inTick then finalize() end end,
}

task.spawn(function()
    local waited = 0
    while PREV and PREV.state and not PREV.state.dead and waited < 60 do task.wait(0.1); waited += 0.1 end
    PREV = nil
    pcall(makefolder, CFG.dir)
    loadPicks(); loadCos()
    while S.running and not S.stopReq do
        S.inTick = true; sliceAt = os.clock()
        local ok, err = pcall(tick); S.inTick = false
        if not ok then
            log("error: %s", tostring(err))
            S.errBurst = (S.errBurst or 0) + 1
            if S.errBurst >= 5 then setStatus(false, "scanning…"); S.errBurst = 0 end
            S.root = nil; S.offsetsOk = false
        else S.errBurst = 0 end
        if S.stopReq then break end
        task.wait(0.1)
    end
    finalize()
end)

pcall(function()
    StarterGui:SetCore("SendNotification", { Title="616", Text="loaded. RIGHT SHIFT = menu.", Duration=4 })
end)
