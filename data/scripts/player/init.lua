if onServer() then
	local player = Player()
	if player then
		player:addScriptOnce("lib/torpedo_assembly.lua")
	end
end
