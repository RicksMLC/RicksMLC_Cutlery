-- Rick's MLC Cutlery
--
-- Modify the ISEatFoodAction so it gets a spoon or fork from the inventory and put it back when finished.
--
-- Stretch Goal: Wash up after eating:
-- 		cooking pot, sauce pan, frying pan, griddle, roast pan, bowl, cake pan, baking pan, muffin pan, and then all the cup items
--		pile of dirty dishes in the sink - attracts flies
--		Sinks as a container item - "Wash Dishes" menu to change dirty dishes to clean dishes
--		Dishwashers would be nice to do this - plumbing

require "TimedActions/ISEatFoodAction"

local function AdjustUnhappiness(adjustment, limit)
	local newValue = getPlayer():getBodyDamage():getUnhappynessLevel() + adjustment
	-- I've seen code elsewhere in the vanilla PZ which limits unhappiness to 100
	if (adjustment > 0 and newValue > limit) or (adjustment < 0 and newValue < limit) then
		newValue = limit
	end
	getPlayer():getBodyDamage():setUnhappynessLevel(newValue)
	return {"Unhappiness", newValue}
end

local getFromBackPack = false
local origContainer = nil
local usingCutlery = false
local origHeat = 0

local overrideEatFoodStart = ISEatFoodAction.start
function ISEatFoodAction:start()
	local playerInv = self.character:getInventory()
	local spoon = playerInv:getFirstTag("Spoon") or playerInv:getFirstType("Base.Spoon");
	local fork = playerInv:getFirstTag("Fork") or playerInv:getFirstType("Base.Fork");
	origHeat = self.item:getHeat()

	if spoon or fork then
		usingCutlery = self.item:getEatType() == "can" or self.item:getEatType() == "candrink" or self.item:getEatType() == "2hand" or self.item:getEatType() == "plate" or self.item:getEatType() == "2handbowl"
		overrideEatFoodStart(self)
		return
	end

	-- Find out if any useful cutlery is in the inventory
	local spoonItem = playerInv:getFirstTagRecurse("Spoon") or playerInv:getFirstTypeRecurse("Base.Spoon")
	local forkItem = playerInv:getFirstTagRecurse("Fork") or playerInv:getFirstTypeRecurse("Base.Fork")
	local cutlery = nil
	if not (spoonItem or forkItem) then
		-- no cutlery so just run the default code
		overrideEatFoodStart(self)
		return
	end

	getFromBackPack = true
	if spoonItem then
		origContainer = spoonItem:getContainer()
		cutlery = spoonItem
	else
		origContainer = forkItem:getContainer()
		cutlery = forkItem
	end

	-- Add the fetch-from-backpack action before proceeding.
	if cutlery then
		-- We have one, but not in-hand, so add an inventory transfer
		local action = ISInventoryTransferAction:new(self.character, cutlery, cutlery:getContainer(), self.character:getInventory(), nil)
		ISTimedActionQueue.addAfter(self, action)
		finalAction = action
	end
	-- Changing the hand settings means changing the current action so spawn a new ISEatFoodAction.
	local eatFoodAction = ISEatFoodAction:new(self.character, self.item, self.percentage)
	ISTimedActionQueue.addAfter(finalAction, eatFoodAction)
	finalAction = eatFoodAction
	local returnCutleryAction = ISInventoryTransferAction:new(self.character, cutlery, self.character:getInventory(), origContainer, nil)
	ISTimedActionQueue.addAfter(finalAction, returnCutleryAction)

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
	-- Calling the ISBaseTimedAction.perform(self) here will cause the original timed action to close cleanly without executing the perform()
	-- This is necessary so the original ISEatFoodAction is not performed so the new one is run in its place after getting the cutlery
	-- from the inventory.
	-- Therefore when cutlery is fetched from the backpack, the subsequent ISEatFoodAction:perform() execution can clean up the "return cutlery"
	-- state info.
end

local function resetCutleryStates()
	getFromBackPack = false
	origContainer = nil
	usingCutlery = false
	origHeat = 0
end

local overrideEatFoodPerform = ISEatFoodAction.perform
function ISEatFoodAction:perform()
	self.item:setHeat(origHeat)

	overrideEatFoodPerform(self)

	if usingCutlery then
		-- Give a little happiness for clinging onto the last vestiges of civilisation and humanity.
		AdjustUnhappiness(-1 * self.percentage, 0)
	end

	-- Reset the backpack inventory flags
	resetCutleryStates()
end

local overrrideEatFoodStop = ISEatFoodAction.stop
function ISEatFoodAction:stop()
	overrrideEatFoodStop(self)
	resetCutleryStates()
end







