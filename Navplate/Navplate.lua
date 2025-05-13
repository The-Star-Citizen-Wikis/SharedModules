--------------------------------------------------------------------------------
-- Module:Navplate                                                            --
-- This module implements {{Navplate}}                                        --
-- Based on Module:Infobox                                                    --
-- This is a work in progress                                                 --
--------------------------------------------------------------------------------

local p = {}
local args = {}
local origArgs = {}

local function union( t1, t2 )
	-- Returns the union of the values of two tables, as a sequence.
	local vals = {}
	for k, v in pairs( t1 ) do
		vals[ v ] = true
	end
	for k, v in pairs( t2 ) do
		vals[ v ] = true
	end
	local ret = {}
	for k, v in pairs( vals ) do
		table.insert( ret, k )
	end
	return ret
end

-- Returns a table containing the numbers of the arguments that exist
-- for the specified prefix. For example, if the prefix was 'data', and
-- 'data1', 'data2', and 'data5' exist, it would return {1, 2, 5}.
local function getArgNums( prefix )
	local nums = {}
	for k, v in pairs( args ) do
		local num = tostring( k ):match( '^' .. prefix .. '([1-9]%d*)$' )
		if num then table.insert( nums, tonumber( num ) ) end
	end
	table.sort( nums )
	return nums
end

--- Get the string of the <details> element
--- TODO: Perhaps we should turn this into another module
---
--- @param data table
--- @param frame table
--- @return string
local function getDetailsHTML( data, frame )
	local summary = frame:extensionTag {
		name = 'summary',
		content = data.summary.content,
		args = {
			class = data.summary.class
		}
	}
	local details = frame:extensionTag {
		name = 'details',
		content = summary .. data.details.content,
		args = {
			class = data.details.class,
			role = data.details.role,
			open = data.details.open or 'no'
		}
	}
	return details
end


--- @param rowArgs table
--- @return mw.html
local function getRowHTML( rowArgs )
	local html = mw.html.create()
	-- Adds a row to the navplate, with either a header
	-- or a label/list combination.
	if rowArgs.header then
		html
			:tag( 'div' )
			:addClass( 'template-navplate__groupheader' )
			:wikitext( rowArgs.header )
	elseif rowArgs.list then
		html
			:tag( 'div' )
			:addClass( 'template-navplate-item' )
			:tag( 'div' )
			:addClass( 'template-navplate-item__label' )
			:wikitext( rowArgs.label )
			:done()
			:tag( 'div' )
			:addClass( 'template-navplate-item__list' )
			:wikitext( rowArgs.list )
	end
	return html
end


--- @return mw.html
local function getTitleHTML()
	local html = mw.html.create( 'div' )
	html:addClass( 'template-navplate__headerContent' )

	if not args.title then return end
	if args.subtitle then
		html
			:tag( 'div' )
			:addClass( 'template-navplate__subtitle' )
			:wikitext( args.subtitle )
			:done()
	end
	html
		:tag( 'div' )
		:addClass( 'template-navplate__title' )
		:wikitext( args.title )

	return html
end


--- @return mw.html
local function getRowsHTML()
	local html = mw.html.create()
	-- Gets the union of the header and list argument numbers,
	-- and renders them all in order using addRow.
	local rownums = union( getArgNums( 'header' ), getArgNums( 'list' ) )
	table.sort( rownums )
	for _, num in ipairs( rownums ) do
		html:node( getRowHTML( {
			header = args[ 'header' .. tostring( num ) ],
			label = args[ 'label' .. tostring( num ) ],
			list = args[ 'list' .. tostring( num ) ]
		} ) )
	end
	return html
end

-- If the argument exists and isn't blank, add it to the argument table.
-- Blank arguments are treated as nil to match the behaviour of ParserFunctions.
local function preprocessSingleArg( argName )
	if origArgs[ argName ] and origArgs[ argName ] ~= '' then
		args[ argName ] = origArgs[ argName ]
	end
end

-- Assign the parameters with the given prefixes to the args table, in order, in
-- batches of the step size specified. This is to prevent references etc. from
-- appearing in the wrong order. The prefixTable should be an array containing
-- tables, each of which has two possible fields, a "prefix" string and a
-- "depend" table. The function always parses parameters containing the "prefix"
-- string, but only parses parameters in the "depend" table if the prefix
-- parameter is present and non-blank.
local function preprocessArgs( prefixTable, step )
	if type( prefixTable ) ~= 'table' then
		error( 'Non-table value detected for the prefix table', 2 )
	end
	if type( step ) ~= 'number' then
		error( 'Invalid step value detected', 2 )
	end

	-- Get arguments without a number suffix, and check for bad input.
	for i, v in ipairs( prefixTable ) do
		if type( v ) ~= 'table' or type( v.prefix ) ~= 'string' or
			(v.depend and type( v.depend ) ~= 'table') then
			error( 'Invalid input detected to preprocessArgs prefix table', 2 )
		end
		preprocessSingleArg( v.prefix )
		-- Only parse the depend parameter if the prefix parameter is present
		-- and not blank.
		if args[ v.prefix ] and v.depend then
			for j, dependValue in ipairs( v.depend ) do
				if type( dependValue ) ~= 'string' then
					error( 'Invalid "depend" parameter value detected in preprocessArgs' )
				end
				preprocessSingleArg( dependValue )
			end
		end
	end

	-- Get arguments with number suffixes.
	local a = 1 -- Counter variable.
	local moreArgumentsExist = true
	while moreArgumentsExist == true do
		moreArgumentsExist = false
		for i = a, a + step - 1 do
			for j, v in ipairs( prefixTable ) do
				local prefixArgName = v.prefix .. tostring( i )
				if origArgs[ prefixArgName ] then
					-- Do another loop if any arguments are found, even blank ones.
					moreArgumentsExist = true
					preprocessSingleArg( prefixArgName )
				end
				-- Process the depend table if the prefix argument is present
				-- and not blank, or we are processing "prefix1" and "prefix" is
				-- present and not blank, and if the depend table is present.
				if v.depend and (args[ prefixArgName ] or (i == 1 and args[ v.prefix ])) then
					for j, dependValue in ipairs( v.depend ) do
						local dependArgName = dependValue .. tostring( i )
						preprocessSingleArg( dependArgName )
					end
				end
			end
		end
		a = a + step
	end
end

local function parseDataParameters()
	preprocessSingleArg( 'id' )
	preprocessSingleArg( 'subtitle' )
	preprocessSingleArg( 'title' )
	preprocessArgs( {
		{ prefix = 'header' },
		{ prefix = 'list',  depend = { 'label' } },
	}, 50 )
end

local function _navplate()
	local frame = mw.getCurrentFrame()

	local summaryHTML = mw.html.create()
		:tag( 'div' )
		:addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
		:done()
		:node( getTitleHTML() )

	local contentHTML = mw.html.create( 'div' )
		:addClass( 'template-navplate__content' )
		-- TODO: Remove this once TemplateStylesExtender supports content-visibility
		:css( 'content-visibility', 'auto' )
		:node( getRowsHTML() )

	local output = getDetailsHTML( {
		details = {
			class = 'template-navplate',
			content = tostring( contentHTML )
		},
		summary = {
			class = 'template-navplate__header',
			content = tostring( summaryHTML )
		}
	}, frame )

	return frame:extensionTag {
		name = 'templatestyles', args = { src = 'Module:Navplate/styles.css' }
	} .. output
end

-- If called via #invoke, use the args passed into the invoking template.
-- Otherwise, for testing purposes, assume args are being passed directly in.
function p.navplate( frame )
	if frame == mw.getCurrentFrame() then
		origArgs = frame:getParent().args
	else
		origArgs = frame
	end

	parseDataParameters()

	return _navplate()
end

-- For calling via #invoke within a template
function p.navplateTemplate( frame )
	origArgs = {}
	for k, v in pairs( frame.args ) do origArgs[ k ] = mw.text.trim( v ) end

	parseDataParameters()

	return _navplate()
end

return p
