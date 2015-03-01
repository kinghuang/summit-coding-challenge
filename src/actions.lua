-- This comment enforces unit-test coverage for this file:
-- coverage: 0


function call_number(options)
	
end

function send_email(options)

end

function register_callback(options)

end

function say_hours_of_operation(options)

end

function goodbye(options)

end


-- Map from action names to action functions. It's possible to
-- just get them from _G, but then it'd just be a big glaring
-- security hole.
actions_by_name = 
{
	['call_number'] = call_number,
	['send_email'] = send_email,
	['register_callback'] = register_callback,
	['say_hours_of_operation'] = hours_of_operation,
	['goodbye'] = goodbye
}
