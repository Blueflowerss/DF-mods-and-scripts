--Author: Blueflowers
local utils = require('utils')

local validArgs = utils.invert({
	'help',
	'start',
  'loop',
  'arenaPosition',
  'arenaSize',
  'centerOnAdventurer',
  'combatIncrement',
  'initialCombat',
  'maxCombat',
  'adventurer'
})
eventful=require "plugins.eventful"
local args = utils.processArgs({...}, validArgs)
-- notes
-- inbetween waves the player might get low on stamina, I could get the player a perk that restores stamina when 
-- killing a combatant DONE

-- ability shop?

if args.help then
	print("Makes a location an arena, spawning opponents in waves. Each wave killed causes another to spawn.\
	Syntax is \"arena -start -arenaPosition [ x z y ] -arenaSize [ x z y ] \"\
	Additional options:\
	-centerOnAdventurer - centers the arena spawn square on the player's character\
	-combatIncrement 1 - combatant amount increase per wave. if blank it defaults to 0.5\
	-initialCombat 1 - initial amount of combatants. default is 5\
	-maxCombat 1 - maximum amount of combatants per wave. default is 20\
	-adventurer (unit_id) - id of the fighting adventurer, if blank it defaults to the unit you're controlling")
end
-- equip the combatants DONE
--show stamina and restore on kill
--enable onUnitDeath event
eventful.enableEvent(5,20)
eventful.onUnitDeath.one=function(unitId)
	--combatant is killed
	local adventurer = df.global.world.units.active[args.adventurer or 0] 
	if adventurer.id ~= unitId then
		adventurer.body.blood_count = math.min(adventurer.body.blood_max, adventurer.body.blood_count + math.floor(adventurer.body.blood_max*0.2))
		adventurer.counters2.exhaustion = math.max(0, math.floor(adventurer.counters2.exhaustion - (6000*0.1)))
		if df.global.gamemode == df.game_mode.ADVENTURE then
			dfhack.gui.showAnnouncement("Blood is: "..math.floor((adventurer.body.blood_count/adventurer.body.blood_max)*100).."% (+10%)",100)
			if adventurer.counters2.exhaustion == 0 then
				dfhack.gui.showAnnouncement("You aren't tired. (+25%)",100)
			else
				dfhack.gui.showAnnouncement("Stamina is: "..math.floor(math.floor((math.max(6000-adventurer.counters2.exhaustion,0)/6000)*100)).."% (+10%)",100)
			end
		end
	end
end
-- center the combatant spawn area on the player to allow for more varied terrain in arena
if (args.arenaPosition or args.centerOnAdventurer) and args.arenaSize then
	arenaPosition = args.arenaPosition
	arenaSize = args.arenaSize
	arenaAdventurer = args.centerOnAdventurer
elseif tonumber(args.loop) ~= 1 then
	print("arena position and/or size not specified!")
end
--if loop is set to nil, it means the player entered the command
--else if 1, it was automatically entered
if tonumber(args.loop) ~= 1 then
	local centerOnAdventurer = ""
	if args.centerOnAdventurer then centerOnAdventurer = "-centerOnAdventurer" end
	local cmd = "repeat -name arenaLoop -time 3 -timeUnits ticks -command [ arena -loop 1 "..centerOnAdventurer.." ]"
	arenaVars = nil
	dfhack.run_command(cmd)
	if arenaVars == nil then
		arenaVars = 1
		arenaWeapons = nil
		arenaMetals = nil
		arenaCombatantIncrease = args.combatIncrement or 0.5
		arenaMaxCombatants = args.maxCombat or 20
		arenaCombatantLimit = args.initialCombat or 5
		arenaCombatants = {}
		arenaKillCount = 0
		arenaWaitPeriod = false
		arenaNextWaveAllowed = true
	end
	if arenaWeapons == nil then
		arenaWeapons = {}
		arenaMetals = {}
		for i,v in pairs(df.global.world.raws.itemdefs.weapons) do
			arenaWeapons[i] = {v.name,i}
		end
		for i,v in pairs(df.global.world.raws.inorganics) do
			if v.material.flags.ITEMS_WEAPON and v.material.flags.ITEMS_WEAPON_RANGED and v.material.flags.ITEMS_ARMOR then
				table.insert(arenaMetals,v)
			end
		end
	end
end
if tonumber(args.loop) == 1 and arenaSize and (arenaPosition or arenaAdventurer) then
		if arenaWaitPeriod then
			--put some message about you being awarded brief period of time between battles
			arenaNextWaveAllowed = true
			arenaWaitPeriod = false
		elseif arenaNextWaveAllowed then
			local cmd = "full-heal --unit "..df.global.world.units.active[0].id
			dfhack.run_command(cmd)
			print("enemies spawned!")
			--make sure to change the arena skills dfhack setting when they spawn
			local tempSide = df.global.world.arena_spawn.side
			df.global.world.arena_spawn.side = 42
			for i = 1,math.floor(arenaCombatantLimit) do
				local unitId = df.global.unit_next_id
				local race = "HUMAN" 
				local caste = "MALE"
				local weaponNextId = df.global.item_next_id
				local weaponMat,breastMat,legMat = math.random(1,#arenaMetals-1),math.random(1,#arenaMetals-1),math.random(1,#arenaMetals-1)
				weaponMat,breastMat,legMat = arenaMetals[weaponMat%#arenaMetals].id,arenaMetals[breastMat%#arenaMetals].id,arenaMetals[legMat%#arenaMetals].id
				local weapon = arenaWeapons[math.random(0,#arenaWeapons)]
				local weaponId = df.global.world.raws.itemdefs.weapons[weapon[2]].id
				local cmd = ""
				if (args.centerOnAdventurer) then
					local adventurer = args.adventurer or 0
					local adventurer = df.global.world.units.active[adventurer]
					cmd = "modtools/create-unit -race "..
								race..
								" -caste "..
								caste..
								" -nick fighter#"..
								i..
								" -customProfession Fighter -name -location [ "..
								adventurer.pos.x.." ".. adventurer.pos.y .. " ".. adventurer.pos.z.. " ] "..
								" -locationRange [ "..
								arenaSize[1].." ".. arenaSize[3] .. " ".. arenaSize[2].. " ] "..
								" -equip [ \""..weaponId..":INORGANIC:"..weaponMat.."\" \"ITEM_ARMOR_BREASTPLATE:INORGANIC:"..breastMat.."\" "..
								"\"ITEM_PANTS_LEGGINGS:INORGANIC:"..legMat.."\" ]"	
				else
					cmd = "modtools/create-unit -race "..
								race..
								" -caste "..
								caste..
								" -nick fighter#"..
								i..
								" -customProfession Fighter -name -location [ "..
								arenaPosition[1].." ".. arenaPosition[3] .. " ".. arenaPosition[2].. " ] "..
								" -locationRange [ "..
								arenaSize[1].." ".. arenaSize[3] .. " ".. arenaSize[2].. " ] "..
								" -equip [ \""..weaponId..":INORGANIC:"..weaponMat.."\" \"ITEM_ARMOR_BREASTPLATE:INORGANIC:"..breastMat.."\" "..
								"\"ITEM_PANTS_LEGGINGS:INORGANIC:"..legMat.."\" ]"		
				end
				--if i == 1 then print(cmd) end
				table.insert(arenaCombatants,unitId)
				dfhack.run_command(cmd)
				df.global.world.units.all[unitId].enemy.caste_flags.EXTRAVISION = true

			end
			df.global.world.arena_spawn.side = tempSide
			print("Current combatant limit: "..math.floor(arenaCombatantLimit)..
			"\nMax combatant limit: ".. arenaMaxCombatants..
			"\nCombatant increment by wave: ".. arenaCombatantIncrease..
			"\nPlayer Killcount: "..arenaKillCount.."\n")
			arenaNextWaveAllowed = false 
		else
			--check if every fighter is dead
			local everyoneDead = true
			for i,v in pairs(arenaCombatants) do
				if not df.global.world.units.all[v].flags1.inactive then
					everyoneDead = false
					break
				end
			end
			-- victory effects
			if everyoneDead then
				arenaWaitPeriod = true
				arenaKillCount = arenaKillCount + math.floor(arenaCombatantLimit)
				arenaCombatantLimit = math.min(arenaCombatantLimit + arenaCombatantIncrease,20)
				local cmd = "full-heal --unit "..df.global.world.units.active[args.adventurer or 0].id
				dfhack.run_command(cmd)
				arenaCombatants = {}
			end
		end
	end