-- This comment enforces unit-test coverage for this file:
-- coverage: 0

local datastore = require 'summit.datastore'
local email     = require 'summit.email'
local json      = require 'json'
local recording = require 'summit.recording'
local sms       = require 'summit.sms'
local time      = require 'summit.time'


function dial_number(options, info)
	local destination = options.destination
	local dial_options = options.dial_options

	-- Perform dialing with the specified destination and options
	-- from the action.
	local ref = channel.dial(destination, dial_options)

	return ref.hangupCause == 'normal'
end

function send_email(options, info)
	-- If options and info exist and are both Tables, set options as the
	-- metatable index of info, so that email parameters can be overridden.
	if type(options) == 'table' and type(info) == 'table' then
		setmetatable(info, {__index = options})
	end
	local parameters = info and info or options

	-- Get the email parameters
	local to_addr = parameters.to_addr
	local from_addr = parameters.from_addr
	local subject = parameters.subject
	local body = parameters.body
	local email_opts = parameters.files and {files=parameters.files} or nil

	local success, err = email.send(to_addr, from_addr, subject, body, email_opts)
	if err then info['error'] = err end
	return success, info
end

function send_sms(options, info)
	-- If options and info exist and are both Tables, set options as the
	-- metatable index of info, so that email parameters can be overridden.
	if type(options) == 'table' and type(info) == 'table' then
		setmetatable(info, {__index = options})
	end
	local parameters = info and info or options

	-- Get the sms parameters
	local to = parameters.to
	local from = parameters.from
	local message = parameters.message

	local success, err = sms.send(to, from, message)
	if err then info['error'] = err end
	return success, info
end

function register_callback(options, info)
	return true
end

function record_voicemail(options, info)
	channel.say('Please leave a message after the beep. Press any key when you are finished.')
	record_result = channel.record()
	voicemail = recording(record_result.id)

	if voicemail then
		if info == nil then info = {} end
		info.voicemail = voicemail
		info.files = {['voicemail.wav'] = voicemail}
		return true, info
	else
		return false
	end
end

function say_hours_of_operation(options, info)
	-- Get the time zone and hours of operation from the organization table.
	local org = datastore.get_table('Organization', 'map')
	local operating_hours = org:get_row_by_key('operating_hours').data
	local timezone = org:get_row_by_key('timezone').data

	-- Determine default hours and today's hours
	local now = time.now(timezone.default)
	local now_weekday_name = time.weekday_name(now)
	local default_hours = json:decode(operating_hours.default)
	local today_hours = operating_hours[now_weekday_name] and json:decode(operating_hours[now_weekday_name]) or default_hours

	-- Adjust the hours based on the menu stack (TBD).
	-- Use the menu stack to determine adjustments on the overall
	-- hours of operation. For example, support might have different
	-- hours than the overall organization.

	-- Determine how best to give the operating hours, based on how many exceptions
	-- to the default hours there are, and whether they are on work days or weekend days.
	local typical_workweek_days = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday'}
	local typical_weekend_days = {'saturday', 'sunday'}

	local workweek_exceptions = {}
	local weekend_exceptions = {}
 
	for k, day in ipairs(typical_workweek_days) do
		if operating_hours[day] ~= nil then table.insert(workweek_exceptions, day) end
	end
	for k, day in ipairs(typical_weekend_days) do
		if operating_hours[day] ~= nil then table.insert(weekend_exceptions, day) end
	end
	
	-- Assemble phrases that will be joined together to form the
	-- hours of operation message.
	local phrases = {}

	-- If the number of exceptions for weekdays is less than 3, then say the
	-- hours for all workdays, followed by up to 2 exceptions. Otherwise, say
	-- the hours for each work day separately.
	for k, opts in ipairs({
		{workweek_exceptions, 3, typical_workweek_days, 'weekdays'},
		{weekend_exceptions, 0, typical_weekend_days, 'weekends'}
	}) do
		local exception_days, exception_limit, all_days, type_of_days = unpack(opts)

		if #exception_days < exception_limit then
			local exception_conjunctions = {'Except', 'And'}
			table.insert(phrases, string.format('We are open monday to friday from %s to %s.', default_hours[1], default_hours[2]))
			for k, day in ipairs(exception_days) do
				local exception_hours = json:decode(operating_hours[day])
				if #exception_hours == 2 then
					table.insert(phrases, string.format('%s, %s from %s to %s.', exception_conjunctions[k], day, exception_hours[1], exception_hours[2]))
				else
					table.insert(phrases, string.format('%s, closed %s', exception_conjunctions[k], day))
				end
			end
		else
			table.insert(phrases, 'We are open')
			for k, day in ipairs(all_days) do
				if k == #all_days then table.insert(phrases, 'And,') end
				local day_hours = operating_hours[day] and json:decode(operating_hours[day]) or default_hours
				if #day_hours == 2 then
					table.insert(phrases, string.format('%s from %s to %s.', day, day_hours[1], day_hours[2]))
				else
					table.insert(phrases, string.format('Closed %s.', day))
				end
			end
		end
	end

	-- Say the complete hours of operation to the caller.
	channel.say(table.concat(phrases, ' '))

	return true
end

function say_location(options, info)
	-- Get the location from the organization table.
	local org = datastore.get_table('Organization', 'map')
	local location = org:get_row_by_key('location').data

	-- Form a sentence for the location and say it to the caller.
	local sentence = string.format('We are located at %s, %s, %s, %s.', location.street, location.city, location.province, location.country)
	channel.say(sentence)

	return true
end

function cant_answer_out_partying(options, info)
	channel.say('Sorry, we are unable to assist you at this time. Please try again later.')

	return true
end

function say_greeting(options, info)
	-- Get the greeting message from the configuration table.
	local config = datastore.get_table('IVR Configuration2', 'string')
	local greeting = config:get_row_by_key('greeting')

	if greeting then
		channel.say(greeting.data)
	end

	return true
end

function say_closing(options, info)
	-- Get the closing message from the configuration table.
	local config = datastore.get_table('IVR Configuration2', 'string')
	local closing = config:get_row_by_key('closing')

	if closing then
		channel.say(closing.data)
	end

	return true
end


-- Map from action names to action functions. It's possible to
-- just get them from _G, but then it'd just be a big glaring
-- security hole.
actions_by_name = 
{
	['dial_number'] = dial_number,
	['send_email'] = send_email,
	['send_sms'] = send_sms,
	['register_callback'] = register_callback,
	['record_voicemail'] = record_voicemail,
	['say_hours_of_operation'] = say_hours_of_operation,
	['say_location'] = say_location,
	['cant_answer_out_partying'] = cant_answer_out_partying,
	['say_greeting'] = say_greeting,
	['say_closing'] = say_closing
}
