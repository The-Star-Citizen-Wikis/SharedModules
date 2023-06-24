-- Imported from: https://runescape.wiki/w/Module:Paramtest

--[[
{{Helper module
|name=Paramtest
|fname1 = is_empty(arg)
|ftype1 = String
|fuse1 = Returns true if arg is not defined or contains only whitespace
|fname2 = has_content(arg)
|ftype2 = String
|fuse2 = Returns true if arg exists and does not only contain whitespace
|fname3 = default_to(arg1,arg2)
|ftype3 = String, Any value
|fuse3 = If arg1 exists and does not only contain whitespace, the function returns arg1, otherwise returns arg2
|fname4 = defaults{ {arg1,arg2},...}
|ftype4 = {String, Any value}...
|fuse4 = Does the same as <code>default_to()</code> run over every table passed
|fname5 = table_is_empty(arg)
|ftype5 = Table
|fuse5 = Returns true if the table has no content, it does not check if the content of the table contains anything
|fname6 = table_has_content(arg)
|ftype6 = Table
|fuse6 = returns true if the table has content, it does not check if the content of the table contains anything
}}
--]]

local checkType, checkTypeForNamedArg
do
	local _libraryUtil = require("libraryUtil");
	checkType = _libraryUtil.checkType;
	checkTypeForNamedArg = _libraryUtil.checkTypeForNamedArg;
end

--
-- Tests basic properties of parameters
--

local p = {}

--
-- Tests if the parameter is empty, all white space, or undefined
--

function p.is_empty(arg)
	return not string.find(arg or '', '%S')
end

--
-- Tests if the table parameter is empty
--

function p.table_is_empty(arg)
	for _, _ in pairs(arg) do
		return false
	end
	return true
end

--
-- Returns the parameter if it has any content, the default (2nd param)
--

function p.default_to(arg, default)
	if string.find(arg or '', '%S') then
		return arg
	else
		return default
	end
end

--
-- Returns a list of paramaters if it has any content, or the default
--
function p.defaults(args)
	checkType("defaults", 1, args, "table");
	local ret = {}
	for i, v in ipairs(args) do
		checkTypeForNamedArg("defaults", i, v, "table");
		ret[i] = p.default_to(v[1], v[2]);
	end
	return unpack(ret, 1, #args);
end

--
-- Tests if the parameter has content
-- The same as !is_empty, but this is more readily clear
--

function p.has_content(arg)
	return string.find(arg or '', '%S')
end

--
-- Tests if the table parameter has content
-- The same as !table_is_empty, but this is more readily clear
--

function p.table_has_content(arg)
	for _, _ in pairs(arg) do
		return true
	end
	return false
end

--
-- uppercases first letter
--

function p.ucfirst(arg)
	if not arg or arg:len() == 0 then
		return nil
	elseif arg:len() == 1 then
		return arg:upper()
	else
		return arg:sub(1,1):upper() .. arg:sub(2)
	end
end

--
-- uppercases first letter, lowercases everything else
--

function p.ucflc(arg)
	if not arg or arg:len() == 0 then
		return nil
	elseif arg:len() == 1 then
		return arg:upper()
	else
		return arg:sub(1,1):upper() .. arg:sub(2):lower()
	end
end

return p
