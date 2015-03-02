-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local actions   = require 'actions'
local datastore = require 'summit.datastore'
local json      = require 'json'
local speech    = require 'summit.speech'


local menus = datastore.get_table('IVR Menus', 'map')
local actions = datastore.get_table('IVR Actions', 'map')

local menu_stack = {}


function perform_target(target, options, info)
	local target_type, target_name = select(3, target:find('([^:]*):([^:]*)'))
	assert(target_type, 'invalid target: ' .. target)
	assert((target_type == 'menu' or target_type == 'action'), 'invalid target type: ' .. target_type)

	-- Fetch and link the target item with the target type's default item. The default
	-- item is used as a fallback table for the target item. This allows the default
	-- item to provide standard values that the target items can optionally override.
	local target_table = target_type == 'menu' and menus or actions
	local default_item = target_table:get_row_by_key('default')
	local target_item = target_table:get_row_by_key(target_name)
	setmetatable(target_item.data, {__index = default_item.data})

	-- Similarly process the options
	if options == nil then options = {} end
	if target_item.options ~= nil then
		local target_options = json:decode(target_item.options)
		setmetatable(options, {__index = target_options})
	end
	if default_item.options ~= nil then
		local default_options =  json:decode(default_item.options)
		local mt = getmetatable(options)
		if mt ~= nil then
			if mt.__index ~= nil then
				setmetatable(mt.__index, {__index = default_options})
			else
				mt.__index = default_options
			end
			setmetatable(options, mt)
		else
			setmetatable(options, {__index = default_options})
		end
	end

	-- Invoke the appropriate item to process the target item
	local handler = target_type == 'menu' and play_menu or perform_action
	handler(target_item, options, info)
end

function play_menu(menu, options, info)
	-- Push the menu to the menu stack to keep track of the caller's place in the menus.
	table.insert(menu_stack, menu)

	-- Decode the menu choices in json, and build a map of choices associated with
	-- touch tone keys.
	local choices = json:decode(menu.data.choices)
	local choices_by_key = {}
	
	-- Loop through the choices and assign choices that have a specific key defined.
	for index, choice in ipairs(choices) do
		if choice.number ~= nil then
			choice_num = choice.number == 0 and 10 or choice.number
			if choice_num == '*' then choice_num = 11 end
			if choice_num == '#' then choice_num = 12 end
			assert(choice_num >= 1 and choice_num <= 12, 'invalid choice num: ' .. choice.number)

			choices_by_key[choice_num] = choice
		end
	end

	-- Loop through the choices again and assign the remaining choices to the first
	-- available key.
	local next_num = 1
	for index, choice in ipairs(choices) do
		if choice.number == nil then
			while choices_by_key[next_num] ~= nil do
				next_num = next_num + 1
			end
			choice_num = next_num == 0 and 10 or next_num
			assert(choice_num >= 1 and choice_num <= 12, 'there are no more keys available for choices')

			choices_by_key[choice_num] = choice
		end
	end

	-- Generate the spoken phrases for each choice, and also gather a table of
	-- valid key presses. Numbers 10, 11 and 12 are converted to 0, star,
	-- and pound, respectively, when spoken to the user.
	local choice_phrases = {}
	local valid_input = {}
	for key, choice in pairs(choices_by_key) do
		if     key == 10 then spoken_key = 0       pressed_key = '0'
		elseif key == 11 then spoken_key = 'star'  pressed_key = '*' 
		elseif key == 12 then spoken_key = 'pound' pressed_key = '#'
		else                  spoken_key = key     pressed_key = key end

		-- Determine the appropriate preposition to use for the target.
		-- For us used for menus, to is used for actions.
		local target_type, target_name = select(3, choice.target:find('([^:]*):([^:]*)'))
		local preposition = target_type == 'menu' and 'for' or 'to'

		table.insert(choice_phrases, string.format('%s %s %s', spoken_key, preposition, choice.name))
		table.insert(valid_input, pressed_key)
	end
	last_choice_idx = table.maxn(choice_phrases)
	choice_phrases[last_choice_idx] = string.format('or %s.', choice_phrases[last_choice_idx])
	
	-- Combine the choice phrases into a prompt sentence, and the valid keys into
	-- a grep pattern.
	menu_prompt = string.format('Press %s', table.concat(choice_phrases, ', '))
	valid_keys = string.format('[%s]', table.concat(valid_input, ''))

	-- Invoke channel.gather to say the menu choices to the caller and
	-- get the caller's choice.
	if menu.name then
		channel.say(menu.data.name)
	end
	
	local pressed_key = nil
	local loop_count = 0
	while pressed_key == nil and loop_count < 3 do
		pressed_key = channel.gather({play=speech(menu_prompt), minDigits=1, maxDigits=1, regex=valid_keys})
		if pressed_key then
			-- Get the choice that the user made, and invoke the target. Convert 0, *, and # to
			-- 10, 11 and 12, respectively, and everything else from a string to a number.
			if     pressed_key == '0' then pressed_key = 10
			elseif pressed_key == '*' then pressed_key = 11
			elseif pressed_key == '#' then pressed_key = 12
			else                           pressed_key = tonumber(pressed_key) end
			local choice = choices_by_key[pressed_key]

			assert(choice ~= nil, 'caller selected a choice that cannot be found: ' .. pressed_key)
			assert(choice.target ~= nil, 'the selected choice does not have a target: ' .. choice.name)
			perform_target(choice.target, choice.target_options, info)
		else
			loop_count = loop_count + 1
		end
	end
end

function perform_action(action, options, info)
	action_f = actions_by_name[action.key]
	assert(action_f ~= nil, 'could not find a function for action: ' .. action.key)
	result, info = action_f(options, info)

	handler = result and options.on_success or options.on_failure
	if handler ~= nil then
		if handler.message then
			channel.say(handler.message)
		end
		if handler.target then
			perform_target(handler.target, handler.target_options, info)
		end
	end
end
