local runService = game:GetService("RunService")
local HS = game:GetService("HttpService")
local MPS = game:GetService("MarketplaceService") -- Added for GamePass check
local WebhookURL = "https://discord.com/api/webhooks/798791561563209728/YjnIVWoKLauxAMuEVuWKp0gdxTV-Ns1lBCkA0LsFeTAUb2j15ZqIT_o-bWvvhs0uImSx"

------------------------[[ Configurations ]]------------------------

local GAMEPASS_ID = 0 -- Replace with your actual GamePass ID
local WHITELIST = {
	"LumbermanLegacy", -- Replace with actual Player Usernames (Put names inside quotation marks)
	"Username2", 
	"Username3"
}

-- Helper function to check whitelist status using usernames (case-insensitive)
local function isWhitelisted(player)
	for _, name in ipairs(WHITELIST) do
		if player.Name:lower() == name:lower() then
			return true
		end
	end
	return false
end

-- Helper function to check gamepass ownership safely
local function hasGamePass(player)
	if GAMEPASS_ID == 0 then return false end
	local success, result = pcall(function()
		return MPS:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)
	return success and result
end

------------------------[[ Blueprint Data Setup ]]------------------------

game.Players.PlayerAdded:connect(function(newPlayer)

	local playerBlueprintsClone = script.Parent.PlayerBlueprints:Clone()
	playerBlueprintsClone.Parent = newPlayer
	
	-- Add SuperBlueprint BoolValue
	local superBlueprint = Instance.new("BoolValue")
	superBlueprint.Name = "SuperBlueprint"
	superBlueprint.Value = isWhitelisted(newPlayer) or hasGamePass(newPlayer)
	superBlueprint.Parent = playerBlueprintsClone

end)

------------------------[[ Blueprint Adding ]]------------------------

script.Parent.AddBlueprint.Event:connect(function(player, box, blueprint)

	if box then
		blueprint = box.PurchasedBoxItemName.Value
	end

	local foundBlueprint = game.ReplicatedStorage.Purchasables.Structures:FindFirstChild(blueprint, true)
	if not foundBlueprint then
		error("Could not find blueprint: "..blueprint)
		return
	end

	local playerBlueprints = player.PlayerBlueprints.Blueprints
	if playerBlueprints:FindFirstChild(blueprint) then
		game.ReplicatedStorage.Notices.SendUserNoticeRemote:FireClient(player, "You already have this blueprint.")
		return
	end

	if box then
		box:Destroy()
	end

	local newBlueprint = Instance.new("Folder")
	newBlueprint.Name = foundBlueprint.Name
	foundBlueprint.ItemCategory:clone().Parent = newBlueprint
	newBlueprint.Parent = playerBlueprints
end)

------------------------[[ Blueprint Construction ]]------------------------

function placeBlueprint(player, structureName, cframe, propertyOwner, oldBlueprint, isAMove)

	local settings = nil

	if oldBlueprint ~= nil then
		if oldBlueprint:FindFirstChild("Owner") and oldBlueprint.Owner.Value ~= player then
			game.ReplicatedStorage.Notices.SendUserNoticeRemote:FireClient(player, "Exploits were detected, or an error has occured. (No Owner Value)")
			--game.ServerStorage.SendLog:Fire(player.Name.. "Tried to FE Btools.")
			return
		end
	end

	if oldBlueprint or isAMove then
		if oldBlueprint then
			if oldBlueprint:FindFirstChild("Settings") then
				settings = oldBlueprint.Settings
				settings.Parent = nil
			end
			if oldBlueprint.Parent ~= nil then
				if oldBlueprint.Parent ~= workspace.PlayerModels then
					return
				end
			end
			oldBlueprint:Destroy()
		--[[else
			game.ReplicatedStorage.Notices.SendUserNoticeRemote:FireClient(player, "Cannot place; blueprint was moved by another player.")
			return]]
		end
	end

	local info = game.ReplicatedStorage.Purchasables.Structures:FindFirstChild(structureName, true)
	if not info then return end
	--game.ServerStorage.SendLog:Fire(player.Name.. " placed " .. info.Name)
	local model = info.Model:clone()
	info.Type:clone().Parent = model
	model.Type.Value = "Blueprint"

	model.Name = structureName

	local itemName = Instance.new("StringValue", model)
	itemName.Name = "ItemName"
	itemName.Value = info.Name

	local owner = Instance.new("ObjectValue", model)
	owner.Name = "Owner"
	owner.Value = propertyOwner

	if not model.PrimaryPart then
		model.PrimaryPart = model.Main
	end
	model:SetPrimaryPartCFrame(cframe)

	if settings and model:FindFirstChild("Settings") then
		model.Settings:Destroy()
		settings.Parent = model
	end	

	prepareModel(model)
	colorModel(model, 0)

	local Progress = script.ProgressBillboard:Clone()
	Progress.Parent = model.PrimaryPart

	local buildRegion = getModelRegion3(model)
	local woodCost = info.WoodCost.Value

	model.Parent = workspace.PlayerModels

	while model and model.Parent do

		local woodPileNet = 0
		local woodPileClasses = {}
		local woodPilePlanks = {}


		local parts = workspace:FindPartsInRegion3(buildRegion, model, 100)
		for _, part in pairs(parts) do
			if part.Parent.Name == "Plank" and part.Parent:FindFirstChild("TreeClass") then

				local partVolume = part.Size.X * part.Size.Y * part.Size.Z

				if not woodPileClasses[part.Parent.TreeClass.Value] then
					woodPileClasses[part.Parent.TreeClass.Value] = {}
					woodPileClasses[part.Parent.TreeClass.Value] = 0
				end
				woodPileClasses[part.Parent.TreeClass.Value] = woodPileClasses[part.Parent.TreeClass.Value] + partVolume

				-- Check for Whitelist, Gamepass, OR the physical StrangeMan structure on the map
				local strangeMan = false
				if isWhitelisted(player) or hasGamePass(player) then
					strangeMan = true
				else
					for i,v in pairs(game.Workspace.PlayerModels:GetChildren()) do
						if v:FindFirstChild("ItemName") then
							if v.ItemName.Value == "StrangeMan" then
								if v:FindFirstChild("Owner") then
									if v.Owner.Value == player then
										strangeMan = true
										break -- break loop early if found
									end
								end
							end
						end
					end
				end

				if strangeMan == true then
					woodCost = 1
				end
				woodPileNet = woodPileNet + partVolume
				table.insert(woodPilePlanks, part.Parent)

				if woodPileNet >= woodCost then
					break
				end
			end
		end

		colorModel(model, woodPileNet / woodCost)	
		Progress.Text.Text = (math.floor(woodPileNet / woodCost * 100)).."%"

		if woodPileNet >= woodCost then
			for _, plank in pairs(woodPilePlanks) do
				plank:Destroy()
			end

			local highestClass
			local maxCount = 0
			for class, count in pairs(woodPileClasses) do
				if count > maxCount then
					maxCount = count
					highestClass = class
				end
			end

			model.Type.Value = "CompletedBlueprint"
			game.ReplicatedStorage.PlaceStructure.ClientPlacedStructureServerServer:Fire(player, structureName, cframe, propertyOwner, highestClass, model)

			break
		end

		wait(0.75)
		--runService.Stepped:wait()
	end

	--[[if model then
		model:Destroy()
	end]]
end

game.ReplicatedStorage.PlaceStructure.ClientPlacedBlueprint.OnServerEvent:connect(placeBlueprint)
game.ReplicatedStorage.PlaceStructure.ClientPlacedBlueprintServerServer.Event:connect(placeBlueprint)


------------------------[[ Misc Utility Functions ]]------------------------

function prepareModel(model)
	for _, instance in pairs(model:GetChildren()) do
		if instance:IsA("Seat") or instance:IsA("VehicleSeat") then
			local newPart = Instance.new("Part", instance.Parent)
			newPart.Transparency = instance.Transparency
			newPart.Size = instance.Size
			newPart.CFrame = instance.CFrame
			newPart.Material = instance.Material
			newPart.Transparency = instance.Transparency
			newPart.Reflectance = instance.Reflectance
			newPart.Parent = instance.Parent
			instance:Destroy()
			instance = newPart
		end
		if instance:IsA("BasePart") then
			if instance:IsA("UnionOperation") then
				instance.UsePartColor = true
			end
			instance.CanCollide = false
			instance.Anchored = true
			if instance.Transparency < 0.7 then
				instance.Transparency = 0.5
			end
			instance.BrickColor = BrickColor.new("Bright green")
			prepareModel(instance)
		elseif instance:IsA("Model") then
			prepareModel(instance)
		elseif not (instance:IsA("DataModelMesh") or instance.Name == "Owner" or instance.Name == "ItemName" or instance.Name == "Type") then
			instance:Destroy()
		end
	end
end


local colorRange = {"Really black", "Dark stone grey", "Navy blue", "Deep blue", "Bright blue", "Medium blue", "Pastel light blue", "Institutional white"}

function colorModel(model, v)
	for _, instance in pairs(model:GetChildren()) do
		if instance:IsA("BasePart") then
			v = math.min(v, 1)
			instance.BrickColor = BrickColor.new(colorRange[math.floor(v * (#colorRange - 1) + 0.5) + 1])
		else
			colorModel(instance, v)
		end
	end
end

local regionCushion = 0.4

function getModelRegion3(model)
	--[[local part = model.PrimaryPart:clone()
	part.CFrame = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + model:GetExtentsSize().Y / 2, 0)
	part.Size = model:GetExtentsSize()]]

	local absBoundMin = Vector3.new(1,1,1) * 1000000
	local absBoundMax = Vector3.new(1,1,1) * -1000000	

	for _, part in pairs(model:GetChildren()) do
		if part:IsA("BasePart") or part:IsA("Seat") then

			local corner1 = (part.CFrame * CFrame.new(part.Size.X/2 + regionCushion, part.Size.Y/2 + regionCushion, part.Size.Z/2 + regionCushion)).p
			local corner2 = (part.CFrame * CFrame.new(part.Size.X/-2 - regionCushion, part.Size.Y/-2 - regionCushion, part.Size.Z/-2 - regionCushion)).p

			local boundsMin = Vector3.new(math.min(corner1.X, corner2.X),math.min(corner1.Y, corner2.Y),math.min(corner1.Z, corner2.Z))
			local boundsMax = Vector3.new(math.max(corner1.X, corner2.X),math.max(corner1.Y, corner2.Y), math.max(corner1.Z, corner2.Z))

			absBoundMin = Vector3.new(math.min(boundsMin.X, absBoundMin.X),math.min(boundsMin.Y, absBoundMin.Y),math.min(boundsMin.Z, absBoundMin.Z))		
			absBoundMax = Vector3.new(math.max(boundsMax.X, absBoundMax.X),math.max(boundsMax.Y, absBoundMax.Y), math.max(boundsMax.Z, absBoundMax.Z))
		end
	end

	return Region3.new(absBoundMin, absBoundMax)
end
