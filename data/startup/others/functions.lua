-- These functions load the action/unique tables on the map
function loadLuaMapAction(tablename)
	-- It load actions
	for index, value in pairs(tablename) do
		for i = 1, #value.itemPos do
			local tile = Tile(value.itemPos[i])
			local item
			-- Checks if the position is valid
			if tile then
				-- Checks that you have no items created
				if not value.itemId == false and tile:getItemCountById(value.itemId) == 0 then
					Spdlog.warn("[loadLuaMapAction] - Wrong item id found")
					Spdlog.warn(string.format("Action id: %d, item id: %d", index, value.itemId))
					break
				end

				if value.itemId ~= false and tile:getItemCountById(value.itemId) > 0 then
					item = tile:getItemById(value.itemId)
				end
				
				-- If he found the item, add the action id.
				if item and value.itemId ~= false then
					item:setAttribute(ITEM_ATTRIBUTE_ACTIONID, index)
				end
				if value.itemId == false and tile:getTopDownItem() then
					tile:getTopDownItem():setAttribute(ITEM_ATTRIBUTE_ACTIONID, index)
				end
				if value.itemId == false and tile:getTopTopItem() then
					tile:getTopTopItem():setAttribute(ITEM_ATTRIBUTE_ACTIONID, index)
				end
				if value.itemId == false and tile:getGround() then
					tile:getGround():setAttribute(ITEM_ATTRIBUTE_ACTIONID, index)
				end
			end
		end
	end
end

function loadLuaMapUnique(tablename)
	-- It load uniques
	for index, value in pairs(tablename) do
		local tile = Tile(value.itemPos)
		local item
		-- Checks if the position is valid
		if tile then
			-- Checks that you have no items created
			if not value.itemId == false and tile:getItemCountById(value.itemId) == 0 then
				Spdlog.warn("[loadLuaMapUnique] - Wrong item id found")
				Spdlog.warn("Unique id: ".. index ..", item id: ".. value.itemId .."")
				break
			end
			if tile:getItemCountById(value.itemId) < 1 or value.itemId == false then
				Spdlog.warn("[loadLuaMapUnique] - Wrong item id found")
				Spdlog.warn("Unique id: ".. index ..", item id: wrong")
				break
			end
			item = tile:getItemById(value.itemId)
			-- If he found the item, add the unique id
			if item then
				item:setAttribute(ITEM_ATTRIBUTE_UNIQUEID, index)
			end
		end
	end
end

function loadLuaMapSign(tablename)
	-- It load signs on map table
	for index, value in pairs(tablename) do
		local tile = Tile(value.itemPos)
		local item
		-- Checks if the position is valid
		if tile then
			-- Checks that you have no items created
			if tile:getItemCountById(value.itemId) == 0 then
				Spdlog.warn("[loadLuaMapSign] - Wrong item id found")
				Spdlog.warn("Sign id: ".. index ..", item id: ".. value.itemId .."")
				break
			end
			if tile:getItemCountById(value.itemId) == 1 then
				item = tile:getItemById(value.itemId)
			end
			-- If he found the item, add the text
			if item then
				item:setAttribute(ITEM_ATTRIBUTE_TEXT, value.text)
			end
		end
	end
end

function loadLuaMapBookDocument(tablename)
	-- Index 1: total valid, index 2: total loaded
	local totals = {0, 0}
	for index, value in ipairs(tablename) do
		local tile = Tile(value.position)
		-- Check position (some items dont have a know position yet defined, lets ignore them)
		if value.position then
			totals[1] = totals[1] + 1
			-- Check if is a valid tile
			if tile then
				-- Try find the container on the map if containerId is set
				local container = (value.containerId and tile:getItemById(value.containerId) or nil)
				-- Check if cotainerId is not set or if containerId is set also if the container exists
				if not value.containerId or value.containerId and container then
					local item
					-- Check if the item need to be in a container
					if container then
						-- Create the item inside the container
						item = container:addItem(value.itemId, 1, INDEX_WHEREEVER, FLAG_NOLIMIT)
					else
						-- Try first find the item on the map (in some cases the item is already on the map)
						item = tile:getItemById(value.itemId)
						-- Create the item at map position if dont was found
						if not item then
							item = Game.createItem(value.itemId, 1, value.position)
						end
					end
					-- If the item exists, add the text
					if item then
						item:setAttribute(ITEM_ATTRIBUTE_TEXT, value.text)
						totals[2] = totals[2] + 1
					else
						Spdlog.warn("[loadLuaMapBookDocument] - Item not found! Index: ".. index ..", itemId: ".. value.itemId.."")
						break
					end
				else
					Spdlog.warn("[loadLuaMapBookDocument] - Container not found! Index: ".. index ..", containerId: ".. value.containerId.."")
					break
				end
			else
				Spdlog.warn("[loadLuaMapBookDocument] - Tile not found! Index: ".. index ..", position: x: ".. value.position.x.." y: ".. value.position.y .." z: ".. value.position.z .."")
				break
			end
		end
	end
	if totals[1] == totals[2] then
		Spdlog.info("Loaded ".. totals[2] .." books and documents in the map")
	else
		Spdlog.info("Loaded ".. totals[2] .." of ".. totals[1] .." books and documents in the map")
	end
end

function loadLuaNpcs(tablename)
	for index, value in pairs(tablename) do
		if value.name and value.position then
			local spawn = Game.createNpc(value.name, value.position)
			if spawn then
				spawn:setMasterPos(value.position)
				Game.setStorageValue(Storage.NpcSpawn, 1)
			end
		end
	end
	Spdlog.info("Loaded ".. (#NpcTable) .." npcs and spawned with tables.")
end

-- Functions that cannot be used in reload command, so they have been moved here
-- Prey slots consumption
function preyTimeLeft(player, slot)
	local timeLeft = player:getPreyTimeLeft(slot) / 60
	local monster = player:getPreyCurrentMonster(slot)
	if (timeLeft >= 1) then
		local playerId = player:getId()
		local currentTime = os.time()
		local timePassed = currentTime - nextPreyTime[playerId][slot]

		-- Setting new timeleft
		if timePassed >= 59 then
			timeLeft = timeLeft - 1
			nextPreyTime[playerId][slot] = currentTime + 60
		end

		-- Sending new timeLeft
		player:setPreyTimeLeft(slot, timeLeft * 60)
	else
		-- Performing automatic Bonus/LockPrey actions
		if player:getPreyTick(slot) == 1 then
			player:setAutomaticBonus(slot)
			player:sendPreyData(slot)
			return true
		elseif player:getPreyTick(slot) == 2 then
			player:setAutomaticBonus(slot)
			player:sendPreyData(slot)
			return true
		end

		-- Expiring prey as there's no timeLeft
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Your %s's prey has expired.", monster:lower()))
		player:setPreyCurrentMonster(slot, "")
	end

	return player:sendPreyData(slot)
end
