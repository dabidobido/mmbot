_addon.name = 'Mandragora Mania Bot'
_addon.author = 'Dabidobido'
_addon.version = '1.1.4'
_addon.commands = {'mmbot'}

packets = require('packets')
require('logger')
socket = require('socket')
require('navigationhelper')

local navigation_helper = navigation_helper()

debugging = false

npc_ids = 
{
	[230] = { npc_id = 17719793, menu_id = 3627, game_menu_id = 3629 }, -- South Sandoria
	[234] = { npc_id = 17735951, menu_id = 675, game_menu_id = 677 }, -- Bastok Mines
	[239] = { npc_id = 17756388, menu_id = 566, game_menu_id = 568 }, -- Windurst Walls
	[243] = { npc_id = 17772789, menu_id = 10291, game_menu_id = 10293 }, -- Ru'Lude Gardens
	[247] = { npc_id = 17789028, menu_id = 178, game_menu_id = 180 }, -- Rabao
	[249] = { npc_id = 17797276, menu_id = 401, game_menu_id = 403 }, -- Mhaura
	[257] = { npc_id = 17830196, menu_id = 5234, game_menu_id = 5236 }, -- Eastern Adoulin
	[280] = { npc_id = 17924237, menu_id = 2077, game_menu_id = 2079 }, -- Mog Garden
	[70] = { npc_id = 17064153, menu_id = 505, game_menu_id = 507 }, -- Chocobo Circuit
}

area_1_option_index = 3
area_2_option_index = 19
area_3_option_index = 35
area_4_option_index = 51
area_5_option_index = 67
area_6_option_index = 99
area_7_option_index = 115
area_8_option_index = 131
ack = 227
quit_option_index = 243

zone = nil -- get zone from the incoming and use it for outgoing

game_state = 0 -- 0 = init, 1 = started, 2 = finished
player_turn = true -- assume player go first
game_board = {
	area1 = 3,
	area2 = 3,
	area3 = 3,
	area4 = 3,
	area5 = 3,
	area6 = 3,
	area7 = 3,
	area8 = 3,
}
jingly_cap = 300
ack_delay = 1
waiting_for_ack = 0
time_to_wait_for_ack = 5
current_zone_id = 0
navigation_finished = false
time_between_0x5b = 1
last_0x5b_time = 0
started = false
game_started_time = 0

windower.register_event('addon command', function(...)
	local args = {...}
	if args[1] == "debug" then
		if args[2] then
			if args[2] == "nav" then
				navigation_helper.debugging = not navigation_helper.debugging
				notice("Navigation Debug output: " .. tostring(navigation_helper.debugging))
			elseif args[2] == "print" then
				notice(tostring(opponent_action_start_time) .. tostring(started) .. tostring(navigation_helper.target_menu_option) .. tostring(player_action_started) .. tostring(navigation_helper.resetting) .. tostring(player_action_start_time) .. tostring(player_turn) .. tostring(waiting_for_ack))
			end
		else
			debugging = not debugging
			notice("Debug output: " ..tostring(debugging))
		end
	elseif args[1] == "start" then
		started = true
		if args[2] then
			local jingly_arg = tonumber(args[2])
			if jingly_arg ~= nil then
				jingly_cap = jingly_arg
			end
		end
		if jingly_cap > 0 then notice("Getting " .. jingly_cap .. " jingly.")
		else
			notice("Getting all the jingly.")
		end
	elseif args[1] == "stop" then
		started = false
		game_state = 2
		reset_state()
		notice("Stopping.")
	elseif args[1] == "setdelay" and args[2] and args[3] then
		local number = tonumber(args[3])
		if number then
			if args[2] == "keypress" then
				navigation_helper.delay_between_keypress = number
				notice("Delay Between Keypress:" .. navigation_helper.delay_between_keypress)
			elseif args[2] == "keydownup" then
				navigation_helper.delay_between_key_down_and_up = number
				notice("Delay Between Key Down and Up:" .. navigation_helper.delay_between_key_down_and_up)
			elseif args[2] == "ack" then
				ack_delay = number
				notice("Delay After Ack:" .. ack_delay)
			elseif args[2] == "waitforack" then
				time_to_wait_for_ack = number
				notice("Wait For Ack:" .. time_to_wait_for_ack)
			end
		end
	elseif args[1] == "help" then
		notice("//mmbot start <number_of_jingly_to_get>: Starts automating until you get the amount of jingly specified. 300 is default. Set to 0 automate until you tell it to stop.")
		notice("//mmbot stop: Stops automation")
		notice("//mmbot setdelay <keypress / keydownup / ack / waitforack> <number>: Configures the delay for the various events")
		notice("//mmbot debug: Toggles debug output")
	end
end)

windower.register_event('incoming chunk', function(id, data)
	if id == 0x34 then
		local p = packets.parse('incoming',data)
		if p then
			current_zone_id = p['Zone']
			if npc_ids[current_zone_id] then 
				if p['NPC'] == npc_ids[current_zone_id].npc_id then
					if debugging then notice("Got menu packet menu id " .. p['Menu ID']) end
					if game_state == 0 or game_state == 2 then
						if p['Menu ID'] == npc_ids[current_zone_id].game_menu_id then
							if debugging then notice("Game State Start") end
							game_state = 1
							game_started_time = os.clock()
							reset_state()
						elseif p['Menu ID'] == npc_ids[current_zone_id].menu_id and started and game_state == 2 then
							navigate_to_menu_option(1, 3, true)
						end
					end
				end
			elseif debugging then
				notice("Couldn't find zone_id defined in npc_ids " .. current_zone_id)
			end
		end
	elseif id == 0x02A then
		if npc_ids[current_zone_id] then
			local p = packets.parse('incoming',data)
			if p then
				if p["Player"] == npc_ids[current_zone_id].npc_id then -- game ended
					game_state = 2
					if jingly_cap > 0 and p["Param 2"] >= jingly_cap then 
						started = false
						notice("Got the jingly")
					end
					navigation_finished = false
					if debugging then notice("Game Ended") end
				end
			end
		end
	end
end)

function reset_state()
	if debugging then notice("reset_state") end
	player_turn = true
	game_board = {
		area1 = 3,
		area2 = 3,
		area3 = 3,
		area4 = 3,
		area5 = 3,
		area6 = 3,
		area7 = 3,
		area8 = 3,
	}
	waiting_for_ack = 0
	player_action_started = false
	navigation_helper.reset_key_states()
end

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
	if injected or blocked then return end
	if id == 0x5b then
		local p = packets.parse("outgoing", original)
		if p then
			if npc_ids[current_zone_id] then
				if p['Menu ID'] == npc_ids[current_zone_id].game_menu_id and started then
					if p['Option Index'] == ack then
						if debugging then notice("Ack") end
						waiting_for_ack = os.clock()
						if player_turn then 
							if debugging then notice("scheduling do_player_turn in " .. ack_delay) end
						end
					elseif p['Option Index'] == quit_option_index then
						game_state = 2
					else
						-- sometimes got multiple packets for some reason, so will mess up the board
						-- there should be more than 1 second between these board move messages
						local socket_time = socket.gettime()
						if socket_time - last_0x5b_time >= time_between_0x5b then
							last_0x5b_time = socket.gettime()
							navigation_finished = false
							if p['Option Index'] == area_1_option_index then
								update_game_board(1)
							elseif p['Option Index'] == area_2_option_index then
								update_game_board(2)
							elseif p['Option Index'] == area_3_option_index then
								update_game_board(3)
							elseif p['Option Index'] == area_4_option_index then
								update_game_board(4)
							elseif p['Option Index'] == area_5_option_index then
								update_game_board(5)
							elseif p['Option Index'] == area_6_option_index then
								update_game_board(6)
							elseif p['Option Index'] == area_7_option_index then
								update_game_board(7)
							elseif p['Option Index'] == area_8_option_index then
								update_game_board(8)
							end
						else
							if debugging then notice("Not updating board since only " .. socket_time - last_0x5b_time .. "s have passed.") end
						end
					end
				elseif p["Menu ID"] == npc_ids[current_zone_id].menu_id then
					if p['Option Index'] == 0 and p['_unknown1'] == 16384 then
						notice('Escaped from menu')
						reset_state()
					end
				end
			end
		end
	end
end)

function do_player_turn()
	if game_state ~= 1 or not player_turn then return end
	if debugging then notice("Do Player Turn") end
	local selected_option = false
	if game_board.area5 == 1 then -- multiple turns
		navigate_to_menu_option(5)
		selected_option = true
	elseif game_board.area4 == 2 then
		navigate_to_menu_option(4)
		selected_option = true
	elseif game_board.area3 == 3 then
		navigate_to_menu_option(3)
		selected_option = true
	elseif game_board.area2 == 4 then
		navigate_to_menu_option(2)
		selected_option = true
	elseif game_board.area1 == 5 then
		navigate_to_menu_option(1)
		selected_option = true
	end
	if not selected_option then
		if game_board.area6 == 5 then -- block opponent multiple turn
			if game_board.area5 >= 2 then
				navigate_to_menu_option(5)
				selected_option = true
			elseif game_board.area4 >= 3 then
				navigate_to_menu_option(4)
				selected_option = true
			elseif game_board.area3 >= 4 then
				navigate_to_menu_option(3)
				selected_option = true
			elseif game_board.area2 >= 5 then
				navigate_to_menu_option(2)
				selected_option = true
			elseif game_board.area1 >= 6 then
				navigate_to_menu_option(1)
				selected_option = true
			end
		elseif game_board.area4 == 4 then
			if game_board.area5 >= 3 then
				navigate_to_menu_option(5)
				selected_option = true
			else
				navigate_to_menu_option(4)
				selected_option = true
			end
		elseif game_board.area7 == 3 then
			if game_board.area5 >= 4 then
				navigate_to_menu_option(5)
				selected_option = true
			elseif game_board.area4 >= 5 then
				navigate_to_menu_option(4)
				selected_option = true
			elseif game_board.area3 >= 6 then
				navigate_to_menu_option(3)
				selected_option = true
			elseif game_board.area2 >= 7 then
				navigate_to_menu_option(2)
				selected_option = true
			elseif game_board.area1 >= 8 then
				navigate_to_menu_option(1)
				selected_option = true
			end
		elseif game_board.area2 == 2 then
			if game_board.area5 >= 5 then
				navigate_to_menu_option(5)
				selected_option = true
			elseif game_board.area4 >= 6 then
				navigate_to_menu_option(4)
				selected_option = true
			elseif game_board.area3 >= 7 then
				navigate_to_menu_option(3)
				selected_option = true
			elseif game_board.area4 ~= 3 then
				navigate_to_menu_option(2)
				selected_option = true
			end
		elseif game_board.area8 == 1 then
			if game_board.area5 >= 6 then
				navigate_to_menu_option(5)
				selected_option = true
			elseif game_board.area4 >= 7 then
				navigate_to_menu_option(4)
				selected_option = true
			elseif game_board.area3 >= 8 then
				navigate_to_menu_option(3)
				selected_option = true
			elseif game_board.area2 >= 9 then
				navigate_to_menu_option(2)
				selected_option = true
			elseif game_board.area1 >= 10 then
				navigate_to_menu_option(1)
				selected_option = true
			end
		end
	end
	if not selected_option then -- get points
		if game_board.area5 >= 1 then
			navigate_to_menu_option(5)
			selected_option = true
		elseif game_board.area4 >= 2 then
			navigate_to_menu_option(4)
			selected_option = true
		elseif game_board.area3 >= 3 then
			navigate_to_menu_option(3)
			selected_option = true
		elseif game_board.area2 >= 4 then
			navigate_to_menu_option(2)
			selected_option = true
		elseif game_board.area1 >= 5 then
			navigate_to_menu_option(1)
			selected_option = true
		end
	end
	if not selected_option then -- just move
		if game_board.area2 >= 1 then
			if game_board.area4 ~= 0 and game_board.area3 == 0 and game_board.area5 == 0
			and game_board.area7 == 0 and game_board.area8 == 0 then
				navigate_to_menu_option(4)
				selected_option = true
			else
				navigate_to_menu_option(2)
				selected_option = true
			end
		elseif game_board.area4 >= 1 then
			navigate_to_menu_option(4)
			selected_option = true
		elseif game_board.area5 >= 1 then
			navigate_to_menu_option(5)
			selected_option = true		
		elseif game_board.area3 >= 1 then
			navigate_to_menu_option(3)
			selected_option = true	
		elseif game_board.area1 >= 1 then
			navigate_to_menu_option(1)
			selected_option = true
		end
	end
end

function update_game_board(area_selected)
	if debugging then notice("Area " .. area_selected .. " selected") end
	waiting_for_ack = 0
	local right = player_turn
	local mandies = get_mandies_from_area(area_selected)
	if debugging then notice(mandies .. " from area " .. area_selected) end
	for i = 1, mandies, 1 do
		right, area_selected = put_mandies_in_next_area(right, area_selected)
	end
	if player_turn and area_selected ~= -1 then
		player_turn = not player_turn 
		if debugging then notice("Player Turn: " .. tostring(player_turn)) end		
	elseif not player_turn and area_selected ~= -2 then 	
		player_turn = not player_turn 
		if debugging then notice("Player Turn: " .. tostring(player_turn)) end
	end
	if player_turn then
		opponent_action_start_time = os.clock()
		player_action_started = false
		if game_board.area1 == 0 and game_board.area2 == 0 and game_board.area3 == 0 and game_board.area4 == 0 and game_board.area5 == 0 then
			game_state = 2
			if debugging then notice("Game Ended. Player has no more moves") end
		end
	else
		opponent_action_start_time = 0
		if game_board.area6 == 0 and game_board.area4 == 0 and game_board.area7 == 0 and game_board.area2 == 0 and game_board.area8 == 0 then
			game_state = 2
			if debugging then notice("Game Ended. Opponent has no more moves") end
		end
	end
end

function get_mandies_from_area(area)
	local ret = 0
	if area == 1 then
		ret = game_board.area1
		game_board.area1 = 0
	elseif area == 2 then
		ret = game_board.area2
		game_board.area2 = 0
	elseif area == 3 then
		ret = game_board.area3
		game_board.area3 = 0
	elseif area == 4 then
		ret = game_board.area4
		game_board.area4 = 0
	elseif area == 5 then
		ret = game_board.area5
		game_board.area5 = 0
	elseif area == 6 then
		ret = game_board.area6
		game_board.area6 = 0
	elseif area == 7 then
		ret = game_board.area7
		game_board.area7 = 0
	elseif area == 8 then
		ret = game_board.area8
		game_board.area8 = 0
	end
	return ret
end

function put_mandies_in_next_area(right, area)
	if area == 5 and right then
		if not player_turn then
			add_mandy_to_area(6)
			area = 6
		else
			area = -1
			if debugging then notice("Player scored") end
		end
		return not right, area
	elseif area == 8 and not right then
		if player_turn then
			add_mandy_to_area(1)
			area = 1
		else 
			area = -2
			if debugging then notice("Opponent scored") end
		end
		return not right, area
	else
		if right then
			if area == -2 then
				add_mandy_to_area(1)
				area = 0 -- +1 later at the end
			elseif area == 1 then
				add_mandy_to_area(2)
			elseif area == 2 then
				add_mandy_to_area(3)
			elseif area == 3 then
				add_mandy_to_area(4)
			elseif area == 4 then
				add_mandy_to_area(5)
			end
			area = area + 1
		else
			if area == -1 then
				add_mandy_to_area(6)
				area = 6
			elseif area == 6 then
				add_mandy_to_area(4)
				area = 4
			elseif area == 4 then
				add_mandy_to_area(7)
				area = 7
			elseif area == 7 then
				add_mandy_to_area(2)
				area = 2
			elseif area == 2 then
				add_mandy_to_area(8)
				area = 8
			end
		end	
	end
	return right, area
end

function add_mandy_to_area(area)
	if debugging then notice("Adding mandy to area " .. area) end
	if area == 1 then
		game_board.area1 = game_board.area1 + 1
	elseif area == 2 then
		game_board.area2 = game_board.area2 + 1
	elseif area == 3 then
		game_board.area3 = game_board.area3 + 1
	elseif area == 4 then
		game_board.area4 = game_board.area4 + 1
	elseif area == 5 then
		game_board.area5 = game_board.area5 + 1
	elseif area == 6 then
		game_board.area6 = game_board.area6 + 1
	elseif area == 7 then
		game_board.area7 = game_board.area7 + 1
	elseif area == 8 then
		game_board.area8 = game_board.area8 + 1
	end
end

function navigate_to_menu_option(option_index, override_delay, from_main_menu)
	player_action_start_time = os.clock()
	player_action_started = true
	navigation_helper.navigate_to_menu_option(option_index, override_delay)
end

function update_loop()
	local time_now = os.clock()
	if started and navigation_helper.target_menu_option == 0 and not player_action_started and not navigation_helper.resetting then
		if need_to_reset then
			need_to_reset = false
			player_action_started = false 
			navigation_helper.reset_position()
		elseif game_state == 1 then
			if game_started_time > 0 and time_now - game_started_time > 10 then
				game_started_time = 0
				player_turn = true
				do_player_turn()
			elseif game_started_time == 0 and waiting_for_ack > 0 and time_now - waiting_for_ack > 10 then
				player_turn = true
				do_player_turn()
			elseif game_started_time == 0 and player_turn and waiting_for_ack > 0 and time_now - waiting_for_ack > ack_delay then
				if debugging then notice("doing player turn after ack") end
				do_player_turn()
			elseif game_started_time == 0 and player_turn and waiting_for_ack == 0 and opponent_action_start_time > 0 and time_now - opponent_action_start_time > 10 then
				if debugging then notice("waited too long for ack, doing player turn") end
				do_player_turn()
			end
		end
	elseif started and navigation_helper.target_menu_option == 0 and player_action_started and not navigation_helper.resetting 
	and time_now - player_action_start_time > 10 then
		if game_state == 1 then 
			player_action_started = false -- for cases where tried to input but no action, set this flag to false so that can do player turn again
			navigation_helper.reset_position()
		elseif game_state == 2 then
			navigate_to_menu_option(1)
		end
	else
		navigation_helper.update(time_now)
	end
end

function parse_incoming_text(original, modified, original_mode, modified_mode, blocked)
	if started then
		if original:find("That area has no mandragora to move.") ~= nil then
			player_action_started = false
			navigate_to_menu_option(2)
		elseif original:find("You will forfeit all jingly earned this game") ~= nil then
			navigation_helper.press_enter()
			need_to_reset = true
		elseif original:find("Your Turn (First Player)") ~= nil then
			if debugging then notice("First Player Turn") end
		end
	end
end

windower.register_event('prerender', update_loop)

windower.register_event('zone change', function()
	reset_state()
end)

windower.register_event('incoming text', parse_incoming_text)