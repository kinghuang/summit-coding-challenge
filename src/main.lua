-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local datastore = require 'summit.datastore'
local target    = require 'target'


-- Main entry point for the app
function main()
	-- Get the configuration table for thea app.
	local config = datastore.get_table('IVR Configuration2', 'string')

	-- Get the greeting and first target. The first target is typically a menu.
	local greeting = config:get_row_by_key('greeting')
	local first_target = config:get_row_by_key('first_target')

	channel.answer()
	if greeting then
		channel.say(greeting.data)
	end
	assert(first_target ~= nil, 'first_target is not specified')
	perform_target(first_target.data)
	perform_target('action:goodbye')
	channel.hangup()
end


-- Kick off the app
main()
