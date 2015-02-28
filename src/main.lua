-- This comment enforces unit-test coverage for this file:
-- coverage: 0

-- Main entry point for the app
function main()
	channel.answer()
	channel.say("This is an example application. Enter any number followed by the pound sign.")
	local digits = channel.gather()
	channel.say(digits)
	channel.hangup()
end

-- Kick off the app
main()
