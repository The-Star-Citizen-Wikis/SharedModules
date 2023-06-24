-- Imported from: https://runescape.wiki/w/Module:Logger

-- <nowiki>
local p = {}

function p.log(obj)
	if type(obj) ~= 'table' then
		mw.log('Argument is a '..type(obj)..', not a table')
		return
	end
	for i,v in pairs(obj) do
		mw.log(tostring(i)..'\t'..tostring(v))
	end
end

local function deep_log(obj, prefix)
	local pfix = ''
	if prefix then
		pfix = prefix..'.'
	end

	for i,v in pairs(obj) do
		mw.log(string.format('%s%s\t%s',pfix,tostring(i),tostring(v)))
		if type(v) == 'table' then
			deep_log(v,pfix..tostring(i))
		end
	end
end

function p.deep_log(obj)
	if type(obj) ~= 'table' then
		mw.log('Argument is a '..type(obj)..', not a table')
		return
	end
	deep_log(obj, nil)
end

local function default( input, defaults )
    input = input or {}
    local res = {}

    for k, v in pairs( input ) do
        res[k] = v
    end

    for k, v in pairs( defaults ) do
        if res[k] == nil then
            res[k] = v
        end
    end

    return res
end

local function isCleanName( str )
    return not (string.find( str, '^%d' ) or string.find( str, '[^_%w]' ))
end

function p.dumpObject( object, options )
    options = default( options, {
        clean = false,
        indentSize = 2,
        tabSize = 4,
        collapseLimit = 0,
        collapseArrays = true,
        wrapLongArrays = false,
        collapseObjects = true,
        useTabs = false,
        addEqualSignSpaces = false,
        addBracketSpaces = true,
        numberPrecision = -1
    } )
    local indentChar = options.useTabs and '\t' or ' '
    local doneTable = {}
    local doneObj = {}
    local ct = {}

    local function sorter( a, b )
        local ta, tb = type( a ), type( b )
        if ta ~= tb then
            return ta < tb
        end
        if ta == 'string' or ta == 'number' then
            return a < b
        end
        if ta == 'boolean' then
            return tostring( a ) < tostring( b )
        end
        return false -- Incomparable
    end

    local function _dumpObject( object, indent, expandTable )
        local tp = type( object )
        if tp == 'nil' or tp == 'boolean' then
            return tostring( object )
        elseif tp == 'number' then
            if options.numberPrecision < 0 then
                return tostring( object )
            else
                return (string.format('%.' .. options.numberPrecision .. 'f', object):gsub( '%.?0*$', '' ))
            end
        elseif tp == 'string' then
            return string.format( "%q", object )
        elseif tp == 'table' then
            if not doneObj[object] then
                local s = tostring( object )
                if string.find(s, '^table$') then
                    ct[tp] = ( ct[tp] or 0 ) + 1
                    doneObj[object] = 'table#' .. ct[tp]
                else
                    doneObj[object] = s
                    doneTable[object] = true
                end
            end
            if (doneTable[object] or not expandTable) and not options.clean then
                return doneObj[object]
            end
            doneTable[object] = true

            local colLen = options.useTabs and (options.tabSize * indent) or indent -- Collapsed string length
            local indentIndexes = {}
            local newLineIndexes = {}
            local equalSignIndexes = {}
            local arrayPartEndIndex = 1
            local ret = options.clean and { '', '', '{\n' } or { (doneObj[object] .. ' (#=' .. #object), '', ' {\n' }
            colLen = colLen + #ret[1]

            local function addIndent()
                ret[#ret + 1] = string.rep( indentChar, indent + options.indentSize )
                indentIndexes[#indentIndexes + 1] = #ret
            end

            local function addNewline()
                ret[#ret + 1] = ",\n"
                newLineIndexes[#newLineIndexes + 1] = #ret
            end

            local function addEqualSign()
                ret[#ret + 1] = " = "
                equalSignIndexes[#equalSignIndexes + 1] = #ret
            end

            local mt = getmetatable( object )
            if mt and not options.clean then
                addIndent()
                ret[#ret + 1] = 'metatable = '
                colLen = colLen + #ret[#ret]
                ret[#ret + 1] = _dumpObject( mt, indent + options.indentSize, false )
                colLen = colLen + #ret[#ret]
                addNewline()
            end

            local doneKeys = {}
            local count = 0

            for key, value in ipairs( object ) do
                doneKeys[key] = true
                addIndent()
                ret[#ret + 1] = _dumpObject( value, indent + options.indentSize, true )
                colLen = colLen + #ret[#ret]
                addNewline()

                count = count + 1
            end
            arrayPartEndIndex = #ret

            local keys = {}
            for key in pairs( object ) do
                if not doneKeys[key] then
                    keys[#keys + 1] = key
                    count = count + 1
                end
            end

            table.sort( keys, sorter )
            if not options.clean then ret[2] = ', n=' .. count .. ')' end
            colLen = colLen + #ret[2]

            for i = 1, #keys do
                local key = keys[i]
                addIndent()

                if options.clean and type( key ) == 'string' and isCleanName( key ) then
                    ret[#ret + 1] = key
                    colLen = colLen + #ret[#ret]
                    addEqualSign()
                else
                    ret[#ret + 1] = '['
                    ret[#ret + 1] = _dumpObject( key, nil, false )
                    colLen = colLen + #ret[#ret] + 2 -- +2 for the brackets []
                    ret[#ret + 1] = ']'
                    addEqualSign()
                end

                ret[#ret + 1] = _dumpObject( object[key], indent + options.indentSize, true )
                colLen = colLen + #ret[#ret] + 1
                addNewline()
            end

            ret[#ret + 1] = string.rep( indentChar, indent )
            indentIndexes[#indentIndexes + 1] = #ret
            ret[#ret + 1] = '}'

            colLen = colLen + 2 * (#newLineIndexes - 1) + (options.addBracketSpaces and 4 or 2)

            if
                (options.collapseArrays or options.collapseObjects) and
                colLen <= options.collapseLimit and
                not (options.collapseObjects == false and count > #object) and
                not (options.collapseArrays == false and #object > 0)
            then
                for _, i in ipairs( indentIndexes ) do
                    ret[i] = ''
                end
                for _, i in ipairs( newLineIndexes ) do
                    ret[i] = ', '
                end
                if not options.addEqualSignSpaces then
                    for _, i in ipairs( equalSignIndexes ) do
                        ret[i] = '='
                    end
                end

                ret[#ret - 1] = '' -- Indentation before closing bracket
                ret[3] = (options.addBracketSpaces and count > 0) and '{ ' or '{'
                if count > 0 then
                    if options.addBracketSpaces then ret[#ret] = ' }' end
                    ret[#ret - 2] = '' -- Last ', '
                end
            end

            if colLen > options.collapseLimit and options.collapseArrays and options.wrapLongArrays then
                local totalLen = options.collapseLimit -- Begin with collapse limit so that the first element keeps its indentation
                for _, i in ipairs( newLineIndexes ) do
                    local itemLen = #ret[i - 1] + 2 -- +2 for the ', '
                    if totalLen + itemLen - 1 >= options.collapseLimit then -- -1 to not count the space after the last ,
                        totalLen = indent + options.indentSize + itemLen
                    else
                        totalLen = totalLen + itemLen
                        ret[i - 2] = '' -- indentation
                        ret[i - 3] = ', '
                    end

                    if i >= arrayPartEndIndex then
                        break
                    end
                end
            end

            return table.concat( ret )
        else
            if not doneObj[object] then
                ct[tp] = ( ct[tp] or 0 ) + 1
                doneObj[object] = tostring( object ) .. '#' .. ct[tp]
            end
            return doneObj[object]
        end
    end

    return _dumpObject( object, 0, true )
end

function p.logCleanTable( object, options )
    mw.log( p.dumpObject( object, default( options, {
        clean = true,
        indentSize = 4,
        collapseLimit = 100,
        collapseArrays = true,
        collapseObjects = true,
        addEqualSignSpaces = false,
    } ) ) )
end

function p.logObject( object, options )
    mw.log( p.dumpObject( object, options ) )
end

return p
-- </nowiki>
