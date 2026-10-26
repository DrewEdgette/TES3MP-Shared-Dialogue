-- Isolated network-test fixture. No accounts, saves, or Morrowind assets.
function OnServerInit()
    tes3mp.SetDataFileEnforcementState(false)
    tes3mp.LogMessage(1, "Shared Dialogue network fixture ready")
end
function OnPlayerSendMessage(pid, message)
    tes3mp.SetCell(pid, message == "leave" and "Other cell" or "Dialogue test")
end
function OnPlayerConnect(pid)
    tes3mp.SetCell(pid, pid == 3 and "Other cell" or "Dialogue test")
    tes3mp.SetPos(pid, pid == 2 and 3000 or 0, 0, 0)
end
