local NPCModule = require(game.ServerScriptService.NPCDialog.NPCList)

NPCModule:AddNPC(script.Parent, function(player, chatSelection)	

	if chatSelection == "" then
		-- Check if player has 10 million currency
		local playerData = player:FindFirstChild("PlayerData")
		if playerData then
			local currency = playerData:FindFirstChild("Currency") or playerData:FindFirstChild("Money") or playerData:FindFirstChild("Cash")
			
			if currency and currency.Value >= 10000000 then
				-- Deduct 10 million
				currency.Value = currency.Value - 10000000
				
				-- Give SuperBlueprint to player
				local playerBlueprints = player:FindFirstChild("PlayerBlueprints")
				if playerBlueprints then
					local superBlueprint = playerBlueprints:FindFirstChild("SuperBlueprint")
					if superBlueprint then
						superBlueprint.Value = true
						game.ReplicatedStorage.Notices.SendUserNoticeRemote:FireClient(player, "You purchased SuperBlueprint for 10,000,000!")
					end
				end
			else
				-- Not enough money
				game.ReplicatedStorage.Notices.SendUserNoticeRemote:FireClient(player, "You need 10,000,000 to purchase SuperBlueprint. You have: " .. tostring(currency.Value))
			end
		end
	end
end)
