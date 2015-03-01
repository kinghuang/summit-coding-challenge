-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local datastore = require 'summit.datastore'
local target    = require 'target'


-- Main entry point for the app
function main()
	-- Get the first target from the configuration table.
	-- The first target is typically a menu, but could also be
	-- a special message (eg: a product recall) that then links
	-- to the main menu, or really anything else. It could also
	-- be an action, and not a menu at all.
	local config = datastore.get_table('IVR Configuration2', 'string')
	local first_target = config:get_row_by_key('first_target')
	assert(first_target ~= nil, 'first_target is not specified')

	-- The main flow: answer the call, say the greeting,
	-- perform the first target, say the closing, and
	-- hang up.
	channel.answer()
	perform_target('action:say_greeting')
	perform_target(first_target.data)
	perform_target('action:say_closing')
	channel.hangup()
end


-- Kick off the app
main()
