require ('strict');
local p = {}

p.trim = function(frame)
    return mw.text.trim(frame.args[1] or "")
end

p.sentence = function (frame)
    -- {{lc:}} is strip-marker safe, string.lower is not.
    frame.args[1] = frame:callParserFunction('lc', frame.args[1])
    return p.ucfirst(frame)
end

p.ucfirst = function (frame )
    local s = frame.args[1];
    if not s or '' == s or s:match ('^%s+$') then								-- when <s> is nil, empty, or only whitespace
        return s;																-- abandon because nothing to do
    end

    s =  mw.text.trim( frame.args[1] or "" )
    local s1 = ""

    local prefix_patterns_t = {													-- sequence of prefix patterns
        '^\127[^\127]*UNIQ%-%-%a+%-%x+%-QINU[^\127]*\127',						-- stripmarker
        '^([%*;:#]+)',															-- various list markup
        '^(\'\'\'*)',															-- bold / italic markup
        '^(%b<>)',																-- html-like tags because some templates render these
        '^(&%a+;)',																-- html character entities because some templates render these
        '^(&#%d+;)',															-- html numeric (decimal) entities because some templates render these
        '^(&#x%x+;)',															-- html numeric (hexadecimal) entities because some templates render these
        '^(%s+)',																-- any whitespace characters
        '^([%(%)%-%+%?%.%%!~!@%$%^&_={}/`,‘’„“”ʻ|\"\'\\]+)',					-- miscellaneous punctuation
    }

    local prefixes_t = {};														-- list, bold/italic, and html-like markup, & whitespace saved here

    local function prefix_strip (s)												-- local function to strip prefixes from <s>
        for _, pattern in ipairs (prefix_patterns_t) do							-- spin through <prefix_patterns_t>
            if s:match (pattern) then											-- when there is a match
                local prefix = s:match (pattern);								-- get a copy of the matched prefix
                table.insert (prefixes_t, prefix);								-- save it
                s = s:sub (prefix:len() + 1);									-- remove the prefix from <s>
                return s, true;													-- return <s> without prefix and flag; force restart at top of sequence because misc punct removal can break stripmarker
            end
        end
        return s;																-- no prefix found; return <s> with nil flag
    end

    local prefix_removed;														-- flag; boolean true as long as prefix_strip() finds and removes a prefix

    repeat																		-- one by one remove list, bold/italic, html-like markup, whitespace, etc from start of <s>
        s, prefix_removed = prefix_strip (s);
    until (not prefix_removed);													-- until <prefix_removed> is nil

    s1 = table.concat (prefixes_t);												-- recreate the prefix string for later reattachment

    local first_text = string.match (s, '^%[%[[^%]]+%]%]');					-- extract wikilink at start of string if present; TODO: this can be string.match()?

    local upcased;
    if first_text then
        if first_text:match ('^%[%[[^|]+|[^%]]+%]%]') then						-- if <first_text> is a piped link
            upcased = string.match (s, '^%[%[[^|]+|%W*(%w)');				-- get first letter character
            upcased = string.upper (upcased);								-- upcase first letter character
            s = string.gsub (s, '^(%[%[[^|]+|%W*)%w', '%1' .. upcased);		-- replace
        else																	-- here when <first_text> is a wikilink but not a piped link
            upcased = string.match (s, '^%[%[%W*%w');						-- get '[[' and first letter
            upcased = string.upper (upcased);								-- upcase first letter character
            s = string.gsub (s, '^%[%[%W*%w', upcased);						-- replace; no capture needed here
        end

    elseif s:match ('^%[%S+%s+[^%]]+%]') then									-- if <s> is a ext link of some sort; must have label text
        upcased = string.match (s, '^%[%S+%s+%W*(%w)');						-- get first letter character
        upcased = string.upper (upcased);									-- upcase first letter character
        s = string.gsub (s, '^(%[%S+%s+%W*)%w', '%1' .. upcased);			-- replace

    elseif s:match ('^%[%S+%s*%]') then											-- if <s> is a ext link without label text; nothing to do
        return s1 .. s;															-- reattach prefix string (if present) and done

    else																		-- <s> is not a wikilink or ext link; assume plain text
        upcased = string.match (s, '^%W*%w');								-- get the first letter character
        upcased = string.upper (upcased);									-- upcase first letter character
        s = string.gsub (s, '^%W*%w', upcased);								-- replace; no capture needed here
    end

    return s1 .. s;																-- reattach prefix string (if present) and done
end


p.title = function (frame )
    -- http://grammar.yourdictionary.com/capitalization/rules-for-capitalization-in-titles.html
    -- recommended by The U.S. Government Printing Office Style Manual:
    -- "Capitalize all words in titles of publications and documents,
    -- except a, an, the, at, by, for, in, of, on, to, up, and, as, but, or, and nor."
    local alwayslower = {['a'] = 1, ['an'] = 1, ['the'] = 1,
                         ['and'] = 1, ['but'] = 1, ['or'] = 1, ['for'] = 1,
                         ['nor'] = 1, ['on'] = 1, ['in'] = 1, ['at'] = 1, ['to'] = 1,
                         ['from'] = 1, ['by'] = 1, ['of'] = 1, ['up'] = 1 }
    local res = ''
    local s =  mw.text.trim( frame.args[1] or "" )
    local words = mw.text.split( s, " ")
    for i, s in ipairs(words) do
        -- {{lc:}} is strip-marker safe, string.lower is not.
        s = frame:callParserFunction('lc', s)
        if i == 1 or alwayslower[s] ~= 1 then
            s = mw.getContentLanguage():ucfirst(s)
        end
        words[i] = s
    end
    return table.concat(words, " ")
end

-- findlast finds the last item in a list
-- the first unnamed parameter is the list
-- the second, optional unnamed parameter is the list separator (default = comma space)
-- returns the whole list if separator not found
p.findlast = function(frame)
    local s =  mw.text.trim( frame.args[1] or "" )
    local sep = frame.args[2] or ""
    if sep == "" then sep = ", " end
    local pattern = ".*" .. sep .. "(.*)"
    local a, b, last = s:find(pattern)
    if a then
        return last
    else
        return s
    end
end

-- stripZeros finds the first number and strips leading zeros (apart from units)
-- e.g "0940" -> "940"; "Year: 0023" -> "Year: 23"; "00.12" -> "0.12"
p.stripZeros = function(frame)
    local s = mw.text.trim(frame.args[1] or "")
    local n = tonumber( string.match( s, "%d+" ) ) or ""
    s = string.gsub( s, "%d+", n, 1 )
    return s
end

-- nowiki ensures that a string of text is treated by the MediaWiki software as just a string
-- it takes an unnamed parameter and trims whitespace, then removes any wikicode
p.nowiki = function(frame)
    local str = mw.text.trim(frame.args[1] or "")
    return mw.text.nowiki(str)
end

-- split splits text at boundaries specified by separator
-- and returns the chunk for the index idx (starting at 1)
-- #invoke:String2 |split |text |separator |index |true/false
-- #invoke:String2 |split |txt=text |sep=separator |idx=index |plain=true/false
-- if plain is false/no/0 then separator is treated as a Lua pattern - defaults to plain=true
p.split = function(frame)
    local args = frame.args
    if not(args[1] or args.txt) then args = frame:getParent().args end
    local txt = args[1] or args.txt or ""
    if txt == "" then return nil end
    local sep = (args[2] or args.sep or ""):gsub('"', '')
    local idx = tonumber(args[3] or args.idx) or 1
    local plain = (args[4] or args.plain or "true"):sub(1,1)
    plain = (plain ~= "f" and plain ~= "n" and plain ~= "0")
    local splittbl = mw.text.split( txt, sep, plain )
    if idx < 0 then idx = #splittbl + idx + 1 end
    return splittbl[idx]
end

-- val2percent scans through a string, passed as either the first unnamed parameter or |txt=
-- it converts each number it finds into a percentage and returns the resultant string.
p.val2percent = function(frame)
    local args = frame.args
    if not(args[1] or args.txt) then args = frame:getParent().args end
    local txt = mw.text.trim(args[1] or args.txt or "")
    if txt == "" then return nil end
    local function v2p (x)
        x = (tonumber(x) or 0) * 100
        if x == math.floor(x) then x = math.floor(x) end
        return x .. "%"
    end
    txt = txt:gsub("%d[%d%.]*", v2p) -- store just the string
    return txt
end

-- one2a scans through a string, passed as either the first unnamed parameter or |txt=
-- it converts each occurrence of 'one ' into either 'a ' or 'an ' and returns the resultant string.
p.one2a = function(frame)
    local args = frame.args
    if not(args[1] or args.txt) then args = frame:getParent().args end
    local txt = mw.text.trim(args[1] or args.txt or "")
    if txt == "" then return nil end
    txt = txt:gsub(" one ", " a "):gsub("^one", "a"):gsub("One ", "A "):gsub("a ([aeiou])", "an %1"):gsub("A ([aeiou])", "An %1")
    return txt
end

-- findpagetext returns the position of a piece of text in a page
-- First positional parameter or |text is the search text
-- Optional parameter |title is the page title, defaults to current page
-- Optional parameter |plain is either true for plain search (default) or false for Lua pattern search
-- Optional parameter |nomatch is the return value when no match is found; default is nil
p._findpagetext = function(args)
    -- process parameters
    local nomatch = args.nomatch or ""
    if nomatch == "" then nomatch = nil end
    --
    local text = mw.text.trim(args[1] or args.text or "")
    if text == "" then return nil end
    --
    local title = args.title or ""
    local titleobj
    if title == "" then
        titleobj = mw.title.getCurrentTitle()
    else
        titleobj = mw.title.new(title)
    end
    --
    local plain = args.plain or ""
    if plain:sub(1, 1) == "f" then plain = false else plain = true end
    -- get the page content and look for 'text' - return position or nomatch
    local content = titleobj and titleobj:getContent()
    return content and string.find(content, text, 1, plain) or nomatch
end
p.findpagetext = function(frame)
    local args = frame.args
    local pargs = frame:getParent().args
    for k, v in pairs(pargs) do
        args[k] = v
    end
    if not (args[1] or args.text) then return nil end
    -- just the first value
    return (p._findpagetext(args))
end

-- returns the decoded url. Inverse of parser function {{urlencode:val|TYPE}}
-- Type is:
-- QUERY decodes + to space (default)
-- PATH does no extra decoding
-- WIKI decodes _ to space
p._urldecode = function(url, type)
    url = url or ""
    type = (type == "PATH" or type == "WIKI") and type
    return mw.uri.decode( url, type )
end
-- {{#invoke:String2|urldecode|url=url|type=type}}
p.urldecode = function(frame)
    return mw.uri.decode( frame.args.url, frame.args.type )
end

-- what follows was merged from Module:StringFunc

-- helper functions
p._GetParameters = require('Module:GetParameters')

-- Argument list helper function, as per Module:String
p._getParameters = p._GetParameters.getParameters

-- Escape Pattern helper function so that all characters are treated as plain text, as per Module:String
function p._escapePattern( pattern_str )
    return string.gsub( pattern_str, "([%(%)%.%%%+%-%*%?%[%^%$%]])", "%%%1" )
end

-- Helper Function to interpret boolean strings, as per Module:String
p._getBoolean = p._GetParameters.getBoolean

--[[
Strip

This function Strips characters from string

Usage:
{{#invoke:String2|strip|source_string|characters_to_strip|plain_flag}}

Parameters
	source: The string to strip
	chars:  The pattern or list of characters to strip from string, replaced with ''
	plain:  A flag indicating that the chars should be understood as plain text. defaults to true.

Leading and trailing whitespace is also automatically stripped from the string.
]]
function p.strip( frame )
    local new_args = p._getParameters( frame.args,  {'source', 'chars', 'plain'} )
    local source_str = new_args['source'] or ''
    local chars = new_args['chars'] or '' or 'characters'
    source_str = mw.text.trim(source_str)
    if source_str == '' or chars == '' then
        return source_str
    end
    local l_plain = p._getBoolean( new_args['plain'] or true )
    if l_plain then
        chars = p._escapePattern( chars )
    end
    local result
    result = string.gsub(source_str, "["..chars.."]", '')
    return result
end

--[[
Match any
Returns the index of the first given pattern to match the input. Patterns must be consecutively numbered.
Returns the empty string if nothing matches for use in {{#if:}}

Usage:
	{{#invoke:String2|matchAll|source=123 abc|456|abc}} returns '2'.

Parameters:
	source: the string to search
	plain:  A flag indicating that the patterns should be understood as plain text. defaults to true.
	1, 2, 3, ...: the patterns to search for
]]
function p.matchAny(frame)
    local source_str = frame.args['source'] or error('The source parameter is mandatory.')
    local l_plain = p._getBoolean( frame.args['plain'] or true )
    for i = 1, math.huge do
        local pattern = frame.args[i]
        if not pattern then return '' end
        if string.find(source_str, pattern, 1, l_plain) then
            return tostring(i)
        end
    end
end

--[[--------------------------< H Y P H E N _ T O _ D A S H >--------------------------------------------------

Converts a hyphen to a dash under certain conditions.  The hyphen must separate
like items; unlike items are returned unmodified.  These forms are modified:
	letter - letter (A - B)
	digit - digit (4-5)
	digit separator digit - digit separator digit (4.1-4.5 or 4-1-4-5)
	letterdigit - letterdigit (A1-A5) (an optional separator between letter and
		digit is supported – a.1-a.5 or a-1-a-5)
	digitletter - digitletter (5a - 5d) (an optional separator between letter and
		digit is supported – 5.a-5.d or 5-a-5-d)

any other forms are returned unmodified.

str may be a comma- or semicolon-separated list

]]
function p.hyphen_to_dash( str, spacing )
    if (str == nil or str == '') then
        return str
    end

    local accept

    str = mw.text.decode(str, true )											-- replace html entities with their characters; semicolon mucks up the text.split

    local out = {}
    local list = mw.text.split (str, '%s*[,;]%s*')								-- split str at comma or semicolon separators if there are any

    for _, item in ipairs (list) do												-- for each item in the list
        item = mw.text.trim(item)												-- trim whitespace
        item, accept = item:gsub ('^%(%((.+)%)%)$', '%1')
        if accept == 0 and string.match (item, '^%w*[%.%-]?%w+%s*[%-–—]%s*%w*[%.%-]?%w+$') then	-- if a hyphenated range or has endash or emdash separators
            if item:match ('^%a+[%.%-]?%d+%s*%-%s*%a+[%.%-]?%d+$') or			-- letterdigit hyphen letterdigit (optional separator between letter and digit)
                item:match ('^%d+[%.%-]?%a+%s*%-%s*%d+[%.%-]?%a+$') or			-- digitletter hyphen digitletter (optional separator between digit and letter)
                item:match ('^%d+[%.%-]%d+%s*%-%s*%d+[%.%-]%d+$') or			-- digit separator digit hyphen digit separator digit
                item:match ('^%d+%s*%-%s*%d+$') or								-- digit hyphen digit
                item:match ('^%a+%s*%-%s*%a+$') then							-- letter hyphen letter
                item = item:gsub ('(%w*[%.%-]?%w+)%s*%-%s*(%w*[%.%-]?%w+)', '%1–%2')	-- replace hyphen, remove extraneous space characters
            else
                item = string.gsub (item, '%s*[–—]%s*', '–')				-- for endash or emdash separated ranges, replace em with en, remove extraneous whitespace
            end
        end
        table.insert (out, item)												-- add the (possibly modified) item to the output table
    end

    local temp_str = table.concat (out, ',' .. spacing)							-- concatenate the output table into a comma separated string
    temp_str, accept = temp_str:gsub ('^%(%((.+)%)%)$', '%1')					-- remove accept-this-as-written markup when it wraps all of concatenated out
    if accept ~= 0 then
        temp_str = str:gsub ('^%(%((.+)%)%)$', '%1')							-- when global markup removed, return original str; do it this way to suppress boolean second return value
    end
    return temp_str
end

function p.hyphen2dash( frame )
    local str = frame.args[1] or ''
    local spacing = frame.args[2] or ' ' -- space is part of the standard separator for normal spacing (but in conjunction with templates r/rp/ran we may need a narrower spacing

    return p.hyphen_to_dash(str, spacing)
end

-- Similar to [[Module:String#endswith]]
function p.startswith(frame)
    return (frame.args[1]:sub(1, frame.args[2]:len()) == frame.args[2]) and 'yes' or ''
end

return p
