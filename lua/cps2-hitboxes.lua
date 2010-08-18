print("CPS-2 hitbox display")
print("August 18, 2010")
print("http://code.google.com/p/mame-rr/") print()

local DRAW_DELAY            = 2
local SCREEN_WIDTH          = 384
local SCREEN_HEIGHT         = 224
local MAX_GAME_PROJECTILES  = 14
local AXIS_COLOUR           = 0xFFFFFFFF
local MINI_AXIS_COLOUR      = 0xFFFF00FF
local AXIS_SIZE             = 25
local MINI_AXIS_SIZE        = 2
local HITBOX_VULNERABILITY  = 0
local HITBOX_ATTACK         = 1
local HITBOX_PUSH           = 2
local HITBOX_VULNERABILITY_COLOUR = 0x0000FF40
local HITBOX_ATTACK_COLOUR  = 0xFF000040
local HITBOX_PUSH_COLOUR    = 0x00FF0040
local GAME_PHASE_NOT_PLAYING= 0

local profile = {
	{
		games = {"sfa2","sfz2al"},
		address = {
			player1          = 0x00FF8400,
			player2          = 0x00FF8800,
			projectile       = 0x00FF9B00,
			left_screen_edge = 0x00FF8026,
			top_screen_edge  = 0x00FF8028,
			game_phase       = 0x00FF812D,
		},
		offset = {
			v_hb_addr_table  = 0x110,
			v_hb_curr_id     = 0x08,
			a_hb_addr_table  = 0x11c,
			a_hb_curr_id     = 0x0b,
			p_hb_addr_table  = 0x120,
			p_hb_curr_id     = 0x0c,
			use_animation_ptr= true,
			projectile_ptr   = 0x60,
			projectile_space = 0x80,
		},
	},
	{
		games = {"sfa3"},
		address = {
			player1          = 0x00FF8400,
			player2          = 0x00FF8800,
			projectile       = 0x00FF9F00,
			left_screen_edge = 0x00FF8026,
			top_screen_edge  = 0x00FF8028,
			game_phase       = 0x00FF812D,
		},
		offset = {
			v_hb_addr_table  = 0x90,
			v_hb_curr_id     = 0xC8,
			a_hb_addr_table  = 0xA0,
			a_hb_curr_id     = 0x09,
			p_hb_addr_table  = 0x9c,
			p_hb_curr_id     = 0xCB,
			use_animation_ptr= false,
			projectile_ptr   = nil,
			projectile_space = 0x100,
		},
	},
	{
		games = {"vsav","vhunt2"},
		address = {
			player1          = 0x00FF8400,
			player2          = 0x00FF8800,
			projectile       = 0x00FF9400,
			left_screen_edge = 0x00FF8026,
			top_screen_edge  = 0x00FF8028,
			game_phase       = 0x00FF812D,
		},
		offset = {
			v_hb_addr_table  = 0x80,
			v_hb_curr_id     = 0x94,
			a_hb_addr_table  = 0x8c,
			a_hb_curr_id     = 0x0A,
			p_hb_addr_table  = 0x90,
			p_hb_curr_id     = 0x97,
			use_animation_ptr= false,
			projectile_ptr   = nil,
			projectile_space = 0x100,
		},
	},
}

local address, offset
local globals = {
	game_phase       = 0,
	left_screen_edge = 0,
	top_screen_edge  = 0,
	num_projectiles  = 0
}
local player1     = {}
local player2     = {}
local projectiles = {}
local frame_buffer_array = {}
for f = 1, DRAW_DELAY + 1 do
	frame_buffer_array[f] = {}
	frame_buffer_array[f][projectiles] = {}
end

function update_globals()
	globals.left_screen_edge = memory.readword(address.left_screen_edge)
	globals.top_screen_edge  = memory.readword(address.top_screen_edge)
	globals.game_phase       = memory.readword(address.game_phase)
end


function hitbox_load(obj, i, type, facing_dir, offset_x, offset_y, addr)
	local hval    = memory.readwordsigned(addr + 0)
	local vval    = memory.readwordsigned(addr + 2)
	local hrad    = memory.readwordsigned(addr + 4)
	local vrad    = memory.readwordsigned(addr + 6)

	if facing_dir == 1 then
		hval  = -hval
	end

	local left   = offset_x + hval - hrad
	local top    = offset_y + vval - vrad
	local right  = offset_x + hval + hrad
	local bottom = offset_y + vval + vrad

	if type == HITBOX_VULNERABILITY then
		obj[HITBOX_VULNERABILITY][i] = {
			left   = left,
			right  = right,
			bottom = bottom,
			top    = top,
			hval   = offset_x+hval,
			vval   = offset_y+vval,
			type   = type
		}
	else
		obj[type] = {
			left   = left,
			right  = right,
			bottom = bottom,
			top    = top,
			hval   = offset_x+hval,
			vval   = offset_y+vval,
			type   = type
		}
	end
end


function update_game_object(obj, base, is_projectile)
	obj.facing_dir   = memory.readbyte(base + 0xB)
	obj.pos_x        = memory.readword(base + 0x10)
	obj.pos_y        = memory.readword(base + 0x14)
	obj.opponent_dir = memory.readbyte(base + 0x5D)

	local animation_ptr   = memory.readdword(base + 0x1C)
	local base_id
	if offset.use_animation_ptr then
		base_id = animation_ptr
	else
		base_id = base
	end

	-- Load the vulnerability hitboxes
	obj[HITBOX_VULNERABILITY] = {}
	for i = 0, 2 do
		local v_hb_addr_table
		if is_projectile and offset.projectile_ptr then
			v_hb_addr_table = memory.readdword(base + offset.projectile_ptr)
			v_hb_addr_table = memory.readword(v_hb_addr_table) + v_hb_addr_table
		else
			v_hb_addr_table = memory.readdword(base + offset.v_hb_addr_table + (i*4))
		end
		local v_hb_curr_id    = memory.readbyte(base_id + offset.v_hb_curr_id + i)
		hitbox_load(obj, i, HITBOX_VULNERABILITY, obj.facing_dir, obj.pos_x, obj.pos_y, v_hb_addr_table+(v_hb_curr_id*8))
	end

	-- Load the attack hitbox
	local a_hb_addr_table
	if is_projectile and offset.projectile_ptr then
		a_hb_addr_table = memory.readdword(base + offset.projectile_ptr)
		a_hb_addr_table = memory.readword(a_hb_addr_table+2) + a_hb_addr_table
	else
		a_hb_addr_table = memory.readdword(base + offset.a_hb_addr_table)
	end
	local a_hb_curr_id    = memory.readbyte(animation_ptr + offset.a_hb_curr_id)
	hitbox_load(obj, 0, HITBOX_ATTACK, obj.facing_dir, obj.pos_x, obj.pos_y, a_hb_addr_table+(a_hb_curr_id*0x20))

	-- Load the push hitbox
	local p_hb_addr_table = memory.readdword(base + offset.p_hb_addr_table)
	local p_hb_curr_id    = memory.readbyte(base_id + offset.p_hb_curr_id)
	hitbox_load(obj, 0, HITBOX_PUSH, obj.facing_dir, obj.pos_x, obj.pos_y, p_hb_addr_table+(p_hb_curr_id*8))
end


function read_projectiles()
	globals.num_projectiles = 0
	for i = 0,MAX_GAME_PROJECTILES do
		local base = address.projectile + (i * offset.projectile_space)

		if memory.readbyte(base) ~= 0 then
			projectiles[globals.num_projectiles] = {}
			update_game_object(projectiles[globals.num_projectiles], base, true)
			globals.num_projectiles = globals.num_projectiles+1
		end
	end
end


function game_x_to_mame(x)
	return (x - globals.left_screen_edge)
end


function game_y_to_mame(y)
	-- Why subtract 17? No idea, the game driver does the same thing.
	return (SCREEN_HEIGHT - (y - 17) + globals.top_screen_edge)
end


function draw_hitbox(hb)
	local left   = game_x_to_mame(hb.left)
	local bottom = game_y_to_mame(hb.bottom)
	local right  = game_x_to_mame(hb.right)
	local top    = game_y_to_mame(hb.top)
	local hval   = game_x_to_mame(hb.hval)
	local vval   = game_y_to_mame(hb.vval)

	if hb.type == HITBOX_VULNERABILITY then
		colour = HITBOX_VULNERABILITY_COLOUR
	elseif hb.type == HITBOX_ATTACK then
		colour = HITBOX_ATTACK_COLOUR
	elseif hb.type == HITBOX_PUSH then
		colour = HITBOX_PUSH_COLOUR
	end

	-- draw mini axis
--	gui.drawline(hval, vval-MINI_AXIS_SIZE, hval, vval+MINI_AXIS_SIZE, MINI_AXIS_COLOUR)
--	gui.drawline(hval-MINI_AXIS_SIZE, vval, hval+MINI_AXIS_SIZE, vval, MINI_AXIS_COLOUR)
	gui.box(left, top, right, bottom, colour)
end


function draw_game_object(obj)
	if not obj then return end

	local x = game_x_to_mame(obj.pos_x)
	local y = game_y_to_mame(obj.pos_y)

	for i = 0, 2 do
		draw_hitbox(obj[HITBOX_VULNERABILITY][i])
	end
	draw_hitbox(obj[HITBOX_ATTACK])
	draw_hitbox(obj[HITBOX_PUSH])

	gui.drawline(x, y-AXIS_SIZE, x, y+AXIS_SIZE, AXIS_COLOUR)
	gui.drawline(x-AXIS_SIZE, y, x+AXIS_SIZE, y, AXIS_COLOUR)
end


local function whatgame()
	if mame ~= nil then DRAW_DELAY = DRAW_DELAY - 1 end
	address, offset = nil, nil
	for n, module in ipairs(profile) do
		for m, shortname in ipairs(module.games) do
			if emu.romname() == shortname or emu.parentname() == shortname then
				print("drawing " .. shortname .. " hitboxes")
				address = module.address
				offset = module.offset
				return
			end
		end
	end
	print("not prepared for " .. emu.romname() .. " hitboxes")
end


local function update_cps2_hitboxes()
	if not address then return end
	update_globals()
	if globals.game_phase == GAME_PHASE_NOT_PLAYING then
		return
	end

	update_game_object(player1, address.player1)
	update_game_object(player2, address.player2)
	read_projectiles()

	for f = 1, DRAW_DELAY do
		frame_buffer_array[f][player1] = copytable(frame_buffer_array[f+1][player1])
		frame_buffer_array[f][player2] = copytable(frame_buffer_array[f+1][player2])
		for i = 0, globals.num_projectiles-1 do
			frame_buffer_array[f][projectiles][i] = copytable(frame_buffer_array[f+1][projectiles][i])
		end
	end

	frame_buffer_array[DRAW_DELAY+1][player1] = copytable(player1)
	frame_buffer_array[DRAW_DELAY+1][player2] = copytable(player2)
	for i = 0, globals.num_projectiles-1 do
		frame_buffer_array[DRAW_DELAY+1][projectiles][i] = copytable(projectiles[i])
	end
end


function render_cps2_hitboxes()
	if not address or globals.game_phase == GAME_PHASE_NOT_PLAYING then
		gui.clearuncommitted()
		return
	end

	draw_game_object(frame_buffer_array[1][player1])
	draw_game_object(frame_buffer_array[1][player2])

	for i = 0, globals.num_projectiles-1 do
		draw_game_object(frame_buffer_array[1][projectiles][i])
	end
end


emu.registerstart( function()
	whatgame()
end)


emu.registerafter( function()
	update_cps2_hitboxes()
end)


gui.register( function()
	render_cps2_hitboxes()
end)