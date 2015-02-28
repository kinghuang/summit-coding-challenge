-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local datastore = require 'summit.datastore'


local menus = datastore.get_table('IVR Menus', 'map')
local actions = datastore.get_table('IVR Actions', 'map')


-- Main entry point for the app
function main()
	channel.answer()
	channel.say("This is an example application. Enter any number followed by the pound sign.")
	local digits = channel.gather()
	channel.say(digits)
	channel.hangup()
end

function perform_target(target)
	target_type, target_name = select(3, target:find('([^:]*):([^:]*)'))
	assert(target_type, 'invalid target: ' .. target)
	assert((target_type == 'menu' or target_type == 'action'), 'invalid target type: ' .. target_type)

	-- Fetch and link the target item with the target type's default item. The default
	-- item is used as a fallback table for the target item. This allows the default
	-- item to provide standard values that the target items can optionally override.
	local target_table = target_type == 'menu' and menus or actions
	local default_item = target_table.get_row_by_key('default')
	local target_item = target_table.get_row_by_key(target_name)
	setmetatable(target_item.data, {__index = default_item.data})

	-- Invoke the appropriate item to process the target item
	local handler = target_type == 'menu' and play_menu or perform_action
	handler(target_item)
end

function play_menu(menu)

end

function perform_action(action)

end


-- Kick off the app
main()
