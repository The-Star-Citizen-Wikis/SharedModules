-- Imported from: https://en.wikipedia.org/wiki/Module:Error

-- This module implements {{error}}.

local p = {}

local function _error(args)
    local tag = mw.ustring.lower(tostring(args.tag))

    -- Work out what html tag we should use.
    if not (tag == 'p' or tag == 'span' or tag == 'div') then
        tag = 'strong'
    end

    -- Generate the html.
    return tostring(mw.html.create(tag)
        :addClass('error')
        :wikitext(tostring(args.message or args[1] or error('no message specified', 2)))
    )
end

function p.error(frame)
    local args
    if type(frame.args) == 'table' then
        -- We're being called via #invoke. The args are passed through to the module
        -- from the template page, so use the args that were passed into the template.
        args = frame.args
    else
        -- We're being called from another module or from the debug console, so assume
        -- the args are passed in directly.
        args = frame
    end
    -- if the message parameter is present but blank, change it to nil so that Lua will
    -- consider it false.
    if args.message == "" then
        args.message = nil
    end
    return _error(args)
end

return p
