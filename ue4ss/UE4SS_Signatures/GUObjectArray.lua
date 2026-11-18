-- GUObjectArray for the Motor Town 0.7.20 (B1157) dedicated server.
--
-- The pattern this file carried before 0.7.20
-- ("48 8D 0D ?? ?? ?? ?? 48 8B D7 89 5C 24 20 44 8D 4B ??", still what the
-- client package ships) matches ZERO times in the 0.7.20 WindowsServer exe, so
-- UE4SS aborted at startup with
--   "AOB scans could not be completed. Cancelling UE4SS load. ... GUObjectArray"
-- and no mod loaded at all - the server booted with no management API and
-- nothing in the log beyond that fatal line.
--
-- This pattern is unique in the 0.7.20 server exe (verified: one match),
-- followed by `lea rcx, [rip+disp]` whose target is GUObjectArray.
function Register()
    return "89 47 08 33 DB 48 8D 0D ?? ?? ?? ??"
end

function OnMatchFound(matchAddress)
    local lea = matchAddress + 0x5
    local displacement = DerefToInt32(lea + 0x3)
    return lea + 0x7 + displacement
end
