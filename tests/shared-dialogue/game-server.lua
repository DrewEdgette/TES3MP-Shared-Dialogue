-- Disposable manual UI fixture. Localhost only; no accounts or saved campaign.
local cell = "Balmora, Caius Cosades' House"
local connected = {}
local timer
local function command(pid, text, actor)
    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(cell)
    tes3mp.SetObjectListConsoleCommand(text)
    if actor then
        tes3mp.SetObjectRefNum(67647)
        tes3mp.SetObjectMpNum(0)
        tes3mp.AddObject()
    end
    tes3mp.SendConsoleCommand(false, false)
end
function UiTick()
    local file = io.open("command.txt", "r")
    if file then
        local action = file:read("*l")
        file:close()
        if action and action ~= "" then
            file = assert(io.open("command.txt", "w")); file:close()
            local pid = tonumber(action:match("%d+$")) or 0
            if connected[pid] then
                if action:match("^talk") then command(pid, "ForceGreeting", true)
                elseif action:match("^topics") then
                    -- Seed only this client's knowledge so mirroring cannot accidentally
                    -- pass by using the spectator's own available topics.
                    for _, topic in ipairs({"Balmora", "Morrowind lore", "Imperial Cult", "Imperial Legion",
                        "Fighters Guild", "Mages Guild", "Thieves Guild", "Blades", "background",
                        "latest rumors", "little advice", "little secret", "my trade", "Nerevarine",
                        "Dagoth Ur", "Sixth House", "Ashlanders", "Dwemer", "House Hlaalu", "House Redoran",
                        "House Telvanni", "Temple", "Vivec", "Ald'ruhn", "Sadrith Mora", "Seyda Neen"}) do
                        command(pid, 'AddTopic "' .. topic .. '"')
                    end
                elseif action:match("^setup") then
                    command(pid, "EnablePlayerControls")
                    command(pid, "EnablePlayerFighting")
                    command(pid, "EnablePlayerLooking")
                    command(pid, "EnablePlayerViewSwitch")
                    command(pid, "EnablePlayerJumping")
                    command(pid, "EnablePlayerMagic")
                    command(pid, "Set CharGenState To -1")
                end
            end
        end
    end
    tes3mp.StartTimer(timer)
end
function OnServerInit()
    tes3mp.SetDataFileEnforcementState(false)
    timer = tes3mp.CreateTimer("UiTick", 250)
    tes3mp.StartTimer(timer)
end
function OnPlayerConnect(pid)
    connected[pid] = true
    tes3mp.SendBaseInfo(pid)
    tes3mp.SetCell(pid, cell)
    tes3mp.SetPos(pid, 140 + pid * 60, -190, 72.6)
    tes3mp.SetRot(pid, 0, -1.57)
    tes3mp.SendCell(pid)
    tes3mp.SendPos(pid)
    tes3mp.SetConsoleAllowed(pid, true)
    tes3mp.SendSettings(pid)
end
function OnPlayerDisconnect(pid) connected[pid] = nil end
function OnObjectActivate(pid, cellDescription)
    tes3mp.ReadReceivedObjectList()
    tes3mp.CopyReceivedObjectListToStore()
    tes3mp.SendObjectActivate(false, false)
end
function OnObjectDialogueChoice(pid, cellDescription)
    tes3mp.LogMessage(1, "UI test: dialogue choice received from player " .. pid)
    tes3mp.ReadReceivedObjectList()
    tes3mp.CopyReceivedObjectListToStore()
    tes3mp.SendObjectDialogueChoice(false, false)
end
function OnObjectRestock(pid, cellDescription)
    tes3mp.ReadReceivedObjectList()
    tes3mp.CopyReceivedObjectListToStore()
    tes3mp.SendObjectRestock(false, false)
end
function OnPlayerJournal(pid)
    tes3mp.LogMessage(1, "UI test: journal packet received from player " .. pid)
    tes3mp.SendJournalChanges(pid, true, true)
end
