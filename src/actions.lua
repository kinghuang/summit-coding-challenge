-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local datastore = require 'summit.datastore'
local json      = require 'json'


function dial_number(options)
	local destination = options.destination
	local dial_options = options.dial_options

	-- Perform dialing with the specified destination and options
	-- from the action.
	local ref = channel.dial(destination, dial_options)

	-- If the call result was not normal and this action has a failure
	-- target defined, perform the specified target.
	if ref.hangupCause ~= 'normal' and options.on_failure ~= nil then
		channel.say('Sorry, your call could not be connected.')
		perform_target(options.on_failure.target, options.on_failure.target_options)
	end
end

function send_email(options)

end

function register_callback(options)

end

function say_hours_of_operation(options)

end

function say_greeting(options)
	-- Get the greeting message from the configuration table.
	local config = datastore.get_table('IVR Configuration2', 'string')
	local greeting = config:get_row_by_key('greeting')

	if greeting then
		channel.say(greeting.data)
	end
end

function say_closing(options)
	-- Get the closing message from the configuration table.
	local config = datastore.get_table('IVR Configuration2', 'string')
	local closing = config:get_row_by_key('closing')

	if closing then
		channel.say(closing.data)
	end
end


-- Map from action names to action functions. It's possible to
-- just get them from _G, but then it'd just be a big glaring
-- security hole.
actions_by_name = 
{
	['dial_number'] = dial_number,
	['send_email'] = send_email,
	['register_callback'] = register_callback,
	['say_hours_of_operation'] = say_hours_of_operation,
	['say_greeting'] = say_greeting,
	['say_closing'] = say_closing
}
