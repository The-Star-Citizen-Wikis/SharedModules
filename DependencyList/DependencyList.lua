require("strict");

local p = {}
local libraryUtil = require( 'libraryUtil' )
local arr = require( 'Module:Array' )
local yn = require( 'Module:Yesno' )
local param = require( 'Module:Paramtest' )
local userError = require("Module:User error")
local mHatnote = require('Module:Hatnote')
local mHatlist = require('Module:Hatnote list')
local TNT = require( 'Module:Translate' ):new()

local moduleIsUsed = false
local COLLAPSE_LIST_LENGTH_THRESHOLD = 1
local dynamicRequireListQueryCache = {}

local moduleNSName =  mw.site.namespaces[ 828 ].name
local templateNSName = mw.site.namespaces[ 10 ].name


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, ... )
    local success, translation = pcall( TNT.format, 'Module:DependencyList/i18n.json', key or '', ... )

    if not success or translation == nil then
        return key
    end

    return translation
end


local builtins = {
	[ "strict" ] = {
		link = "mw:Special:MyLanguage/Extension:Scribunto/Lua reference manual#strict",
		categories = { translate( 'category_strict_mode_modules' ) },
	},
}


--- Used in case 'require( varName )' is found. Attempts to find a string value stored in 'varName'.
---@param content string    The content of the module to search in
---@param varName string
---@return string
local function substVarValue( content, varName )
    local res = content:match( varName .. '%s*=%s*(%b""%s-%.*)' ) or content:match( varName .. "%s*=%s*(%b''%s-%.*)" ) or ''
    if res:find( '^(["\'])[Mm]odule?:[%S]+%1' ) and not res:find( '%.%.' ) and not res:find( '%%%a' ) then
        return mw.text.trim( res )
    else
        return ''
    end
end


---@param capture string
---@param content string    The content of the module to search in
---@return string
local function extractModuleName( capture, content )
    capture = capture:gsub( '^%(%s*(.-)%s*%)$', '%1' )

    if capture:find( '^(["\']).-%1$' ) then -- Check if it is already a pure string
        return capture
    elseif capture:find( '^[%a_][%w_]*$' ) then -- Check if if is a single variable
        return substVarValue( content, capture )
    end

    return capture
end


---@param str string
---@return string
local function formatPageName( str )
    local name = mw.text.trim( str )
        :gsub( '^([\'\"])(.-)%1$', function( _, x ) return x end ) -- Only remove quotes at start and end of string if both are the same type
        :gsub( '_', ' ' )
        :gsub( '^.', string.upper )
        :gsub( ':.', string.upper )

    return name
end


---@param str string
---@return string
local function formatModuleName( str, allowBuiltins )
	if allowBuiltins then
		local name = mw.text.trim( str )
			-- Only remove quotes at start and end of string if both are the same type
			:gsub( [[^(['"])(.-)%1$]], function( _, x ) return x end );

		local builtin = builtins[ name ];
		if builtin then
			return builtin.link .. "|" .. name, builtin;
		end
	end

    local module = formatPageName( str )

    if not string.find( module, '^[Mm]odule?:' ) then
        module = moduleNSName .. ':' .. module
    end

    return module
end


local function dualGmatch( str, pat1, pat2 )
    local f1 = string.gmatch( str, pat1 )
    local f2 = string.gmatch( str, pat2 )
    return function()
        return f1() or f2()
    end
end


--- Used in case a construct like 'require( "Module:wowee/" .. isTheBest )' is found.
--- Will return a list of pages which satisfy this pattern where 'isTheBest' can take any value.
---@param query string
---@return string[]     Sequence of strings
local function getDynamicRequireList( query )
	local isDynamic = true;

    if query:find( '%.%.' ) then
        query = mw.text.split( query, '..', true )
        query = arr.map( query, function( x ) return mw.text.trim( x ) end )
        query = arr.map( query, function( x ) return ( x:match('^[\'\"](.-)[\'\"]$') or '%') end )
        query = table.concat( query )
    else
        local _; _, query = query:match( '(["\'])(.-)%1' )
        local replacements;
        query, replacements = query:gsub( '%%%a', '%%' )
		if replacements == 0 then
			isDynamic = false;
		end
    end

    query = query:gsub( '^[Mm]odule?:', '' )

    if dynamicRequireListQueryCache[ query ] then
        return dynamicRequireListQueryCache[ query ], isDynamic;
    end

    return {}, isDynamic;
end


--- Returns a list of modules loaded and required by module 'moduleName'.
---@param moduleName string
---@param searchForUsedTemplates boolean|nil
---@return string[], string[], string[], string[]
local function getRequireList( moduleName, searchForUsedTemplates )
    local content = mw.title.new( moduleName ):getContent()
    local requireList = arr{}
    local loadDataList = arr{}
    local usedTemplateList = arr{}
    local dynamicRequirelist = arr{}
    local dynamicLoadDataList = arr{}
    local extraCategories = arr{}

    assert( content ~= nil, translate( 'message_not_exists', moduleName ) )

    content = content:gsub( '%-%-%[(=-)%[.-%]%1%]', '' ):gsub( '%-%-[^\n]*', '' ) -- Strip comments

    for match in dualGmatch( content, 'require%s*(%b())', 'require%s*((["\'])%s*[Mm]odule?:.-%2)' ) do
        match = mw.text.trim( match )
        match = extractModuleName( match, content )

        if match:find( '%.%.' ) or match:find( '%%%a' ) then
            for _, x in ipairs( getDynamicRequireList( match ) ) do
                table.insert( dynamicRequirelist, x )
            end
        elseif match ~= '' then
        	local builtin;
            match, builtin = formatModuleName( match, true )
            table.insert( requireList, match )

			if builtin then
				local builtinCategories = builtin.categories;
				if type( builtinCategories ) == 'table' then
					for _, x in ipairs( builtinCategories ) do
						table.insert( extraCategories, x );
					end
				end
			end
        end
    end

    for match in dualGmatch( content, 'mw%.loadData%s*(%b())', 'mw%.loadData%s*((["\'])%s*[Mm]odule?:.-%2)' ) do
        match = mw.text.trim( match )
        match = extractModuleName( match, content )

        if match:find( '%.%.' ) or match:find( '%%%a' ) then
            for _, x in ipairs( getDynamicRequireList( match ) ) do
                table.insert( dynamicLoadDataList, x )
            end
        elseif match ~= '' then
            match = formatModuleName( match, true )
            table.insert( loadDataList, match )
        end
    end

    for match in dualGmatch( content, 'mw%.loadJsonData%s*(%b())', 'mw%.loadJsonData%s*((["\'])%s*[Mm]odule?:.-%2)' ) do
        match = mw.text.trim( match )
        match = extractModuleName( match, content )

        if match:find( '%.%.' ) or match:find( '%%%a' ) then
            for _, x in ipairs( getDynamicRequireList( match ) ) do
                table.insert( dynamicLoadDataList, x )
            end
        elseif match ~= '' then
            match = formatModuleName( match, true )
            table.insert( loadDataList, match )
        end
    end

    for func, match in string.gmatch( content, 'pcall%s*%(([^,]+),([^%),]+)' ) do
        func = mw.text.trim( func )
        match = mw.text.trim( match )

		local dynList, isDynamic;
        if func == 'require' then
			dynList, isDynamic = getDynamicRequireList( match );

			if ( isDynamic == false and #dynList == 1 ) then
				table.insert( requireList, dynList[ 1 ] );
			else
                for _, x in ipairs( dynList ) do
                    table.insert( dynamicRequirelist, x )
			    end
            end
        elseif func == 'mw.loadData' then
			dynList, isDynamic = getDynamicRequireList( match );

			if ( isDynamic == false and #dynList == 1 ) then
				table.insert( loadDataList, dynList[ 1 ] );
			else
                for _, x in ipairs( dynList ) do
                    table.insert( dynamicLoadDataList, x )
			    end
            end
        end
    end

    if searchForUsedTemplates then
        for preprocess in string.gmatch( content, ':preprocess%s*(%b())' ) do
            local function recursiveGMatch( str, pat )
                local list = {}
                local i = 0

                repeat
                    for match in string.gmatch( list[ i ] or str, pat ) do
                        table.insert( list, match )
                    end
                    i =  i + 1
                until i > #list or i > 100

                i = 0
                return function()
                    i = i + 1
                    return list[ i ]
                end
            end

            for template in recursiveGMatch( preprocess, '{(%b{})}' ) do
                local name = string.match( template, '{(.-)[|{}]' )
                if name ~= '' then
                    if name:find( ':' ) then
                        local ns = name:match( '^(.-):' )
                        if arr.contains( { '', 'template', 'user' }, ns:lower() ) then
                            table.insert( usedTemplateList, name )
                        elseif ns == ns:upper() then
                            table.insert( usedTemplateList, ns ) -- Probably a magic word
                        end
                    else
                        if name:match( '^%u+$' ) or name == '!' then
                            table.insert( usedTemplateList, name ) -- Probably a magic word
                        else
                            table.insert( usedTemplateList, 'Template:'..name )
                        end
                    end
                end
            end
        end
    end

    requireList = requireList .. dynamicRequirelist:reject( loadDataList )
    requireList = requireList:unique()
    loadDataList = loadDataList .. dynamicLoadDataList:reject( requireList )
    loadDataList = loadDataList:unique()
    usedTemplateList = usedTemplateList:unique()
    extraCategories = extraCategories:unique()
    table.sort( requireList )
    table.sort( loadDataList )
    table.sort( usedTemplateList )
    table.sort( extraCategories )

    return requireList, loadDataList, usedTemplateList, extraCategories
end


--- Returns a list with module and function names used in all '{{#Invoke:moduleName|funcName}}' found on page 'templateName'.
---@param templateName string
---@return table<string, string>[]
local function getInvokeCallList( templateName )
    local content = mw.title.new( templateName ):getContent()
    local invokeList = {}

    assert( content ~= nil, translate( 'message_not_exists', templateName ) )

    for moduleName, funcName in string.gmatch( content, '{{[{|safeubt:}]-#[Ii]nvoke:([^|]+)|([^}|]+)[^}]*}}' ) do
        moduleName = formatModuleName( moduleName )
        funcName = mw.text.trim( funcName )
        if string.find( funcName, '^{{{' ) then
        	funcName = funcName ..  '}}}'
        end
        table.insert( invokeList, { moduleName = moduleName, funcName = funcName } )
    end

    invokeList = arr.unique( invokeList, function( x ) return x.moduleName..x.funcName end )
    table.sort( invokeList, function( x, y ) return x.moduleName..x.funcName < y.moduleName..y.funcName end )

    return invokeList
end

---@param pageName string
---@param addCategories boolean
---@return string
local function messageBoxUnused( pageName, addCategories )
	local mbox = require( 'Module:Mbox' )._mbox

	local category = addCategories and '[[Category:' .. translate( 'category_unused_module' ) .. ']]' or ''

	return mbox(
		translate( 'message_unused_module_title' ),
		translate( 'message_unused_module_desc' ),
		{ icon = 'WikimediaUI-Alert.svg' }
	) .. category
end


local function collapseList( list, id, listType )
    local text = string.format( '%d %s', #list, listType )
    local button = '<span>' .. text .. ':</span>&nbsp;'
    local content = mHatlist.andList( list, false )

    return { tostring( button ) .. tostring( content ) }
end


--- Creates a link to [[Special:Search]] showing all pages found by getDynamicRequireList() in case it found more than MAX_DYNAMIC_REQUIRE_LIST_LENGTH pages.
---@param query string      @This will be in a format like 'Module:Wowee/%' or 'Module:Wowee/%/data'
---@return string
local function formatDynamicQueryLink( query )
    local prefix = query:match( '^([^/]+)' )
    local linkText = query:gsub( '%%', '&lt; ... &gt;' )

    query = query:gsub( '^Module?:',  '' )

    query = query:gsub( '([^/]+)/?', function ( match )
        if match == '%' then
            return '\\/[^\\/]+'
        else
            return '\\/"' .. match .. '"'
        end
    end )

    query = query:gsub( '^\\/', '' )

    query = string.format(
        'intitle:/%s%s/i -intitle:/%s\\/""/i -intitle:doc prefix:"%s"',
        query,
        query:find( '"$' ) and '' or '""',
        query,
        prefix
    )

    return string.format( '<span class="plainlinks">[%s %s]</span>', tostring( mw.uri.fullUrl( 'Special:Search', { search = query } ) ), linkText )
end


---@param templateName string
---@param addCategories boolean
---@param invokeList table<string, string>[]    @This is the list returned by getInvokeCallList()
---@return string
local function formatInvokeCallList( templateName, addCategories, invokeList )
    local category = addCategories and '[[Category:' .. translate( 'category_lua_based_template' ) .. ']]' or ''
    local res = {}

    for _, item in ipairs( invokeList ) do
        local msg = translate(
                'message_invokes_function',
    		templateName,
    		item.funcName,
    		item.moduleName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    if #invokeList > 0 then
        table.insert( res, category )
    end

    return table.concat( res )
end


---@param moduleName string
---@param addCategories boolean
---@param whatLinksHere string    @A list generated by a dpl of pages in the Template namespace which link to moduleName.
---@return string
local function formatInvokedByList( moduleName, addCategories, whatLinksHere )
    local function lcfirst( str )
		return string.gsub( str, '^[Mm]odule?:.', string.lower )
	end

    local templateData = arr.map( whatLinksHere, function( x ) return { templateName = x, invokeList = getInvokeCallList( x ) } end )
    templateData = arr.filter( templateData, function( x )
        return arr.any( x.invokeList, function( y )
            return lcfirst( y.moduleName ) == lcfirst( moduleName )
        end )
    end )

    local invokedByList = {}

    for _, template in ipairs( templateData ) do
        for _, invoke in ipairs( template.invokeList ) do
            table.insert( invokedByList, translate( 'message_function_invoked_by', invoke.funcName, template.templateName ) )
        end
    end

    table.sort( invokedByList)

    local res = {}

    if #invokedByList > COLLAPSE_LIST_LENGTH_THRESHOLD then
    	local msg = translate(
        'message_function_invoked_by',
            moduleName,
    		collapseList( invokedByList, 'invokedBy', translate( 'list_type_templates' ) )[ 1 ]
    	)

        table.insert( res, mHatnote._hatnote( msg, { icon='WikimediaUI-Code.svg' } ) )
    else
	    for _, item in ipairs( invokedByList ) do
	    	local msg = string.format(
	    		"'''%s's''' %s.",
	    		moduleName,
	    		item
	    	)
        	table.insert( res, mHatnote._hatnote( msg, { icon='WikimediaUI-Code.svg' } ) )
	    end
    end

    if #templateData > 0 then
        moduleIsUsed = true
        table.insert( res, ( addCategories and '[[Category:' .. translate( 'category_template_invoked_modules' ) .. ']]' or '' ) )
    end

    return table.concat( res )
end


---@param moduleName string
---@param addCategories boolean
---@param whatLinksHere string      @A list generated by a dpl of pages in the Module namespace which link to moduleName.
---@return string
local function formatRequiredByList( moduleName, addCategories, whatLinksHere )
    local childModuleData = arr.map( whatLinksHere, function ( title )
        local requireList, loadDataList = getRequireList( title )
        return { name = title, requireList = requireList, loadDataList = loadDataList }
    end )

    local requiredByList = arr.map( childModuleData, function ( item )
        if arr.any( item.requireList, function( x )
            return x:lower():gsub( '^module?:', 'module' ) == moduleName:lower():gsub( '^module?:', 'module' )
        end ) then
            if item.name:find( '%%' ) then
                return formatDynamicQueryLink( item.name )
            else
                return '[[' .. item.name .. ']]'
            end
        end
    end )

    local loadedByList = arr.map( childModuleData, function ( item )
        if arr.any( item.loadDataList, function( x )
            return x:lower():gsub( '^module?:', 'module' ) == moduleName:lower():gsub( '^module?:', 'module' )
        end ) then
            if item.name:find( '%%' ) then
                return formatDynamicQueryLink( item.name )
            else
                return '[[' .. item.name .. ']]'
            end
        end
    end )

    if #requiredByList > 0 or #loadedByList > 0 then
        moduleIsUsed  = true
    end

    if #requiredByList > COLLAPSE_LIST_LENGTH_THRESHOLD then
        requiredByList = collapseList( requiredByList, 'requiredBy', translate( 'list_type_modules' ) )
    end

    if #loadedByList > COLLAPSE_LIST_LENGTH_THRESHOLD then
        loadedByList = collapseList( loadedByList, 'loadedBy', translate( 'list_type_modules' ) )
    end

    local res = {}

    for _, requiredByModuleName in ipairs( requiredByList ) do
    	local msg = translate(
    		'message_required_by',
    		moduleName,
    		requiredByModuleName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    if #requiredByList > 0 then
        table.insert( res, ( addCategories and '[[Category:' .. translate( 'category_modules_required_by_modules' ) .. ']]' or '' ) )
    end

    for _, loadedByModuleName in ipairs( loadedByList ) do
    	local msg = translate(
    		'message_loaded_by',
    		moduleName,
            loadedByModuleName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon='WikimediaUI-Code.svg' } ) )
    end

    if #loadedByList > 0 then
        table.insert( res, ( addCategories and '[[Category:' .. translate( 'category_module_data' ) .. ']]' or '' ) )
    end

    return table.concat( res )
end


local function formatRequireList( currentPageName, addCategories, requireList )
    local res = {}

    if #requireList > COLLAPSE_LIST_LENGTH_THRESHOLD then
        requireList = collapseList( requireList, 'require', translate( 'list_type_modules' ) )
    end

    for _, requiredModuleName in ipairs( requireList ) do
    	local msg = translate(
    		'message_requires',
    		currentPageName,
    		requiredModuleName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    if #requireList > 0 then
        table.insert( res, (addCategories and '[[Category:' .. translate( 'category_modules_required_by_modules' ) .. ']]' or '') )
    end

    return table.concat( res )
end


local function formatLoadDataList( currentPageName, addCategories, loadDataList )
    local res = {}

    if #loadDataList > COLLAPSE_LIST_LENGTH_THRESHOLD then
        loadDataList = collapseList( loadDataList, 'loadData', translate( 'list_type_modules' ) )
    end

    for _, loadedModuleName in ipairs( loadDataList ) do
    	local msg = translate(
    		'message_loads_data_from',
    		currentPageName,
    		loadedModuleName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    if #loadDataList > 0 then
        table.insert( res, ( addCategories and '[[Category:' .. translate( 'category_modules_using_data' ) .. ']]' or '' ) )
    end

    return table.concat( res )
end


local function formatUsedTemplatesList( currentPageName, addCategories, usedTemplateList )
    local res = {}

    if #usedTemplateList > COLLAPSE_LIST_LENGTH_THRESHOLD then
        usedTemplateList = collapseList( usedTemplateList, 'usedTemplates', translate( 'list_type_templates' ) )
    end

    for _, templateName in ipairs( usedTemplateList ) do
    	local msg = translate(
    		'message_transcludes',
    		currentPageName,
    		templateName
    	)
        table.insert( res, mHatnote._hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    return table.concat( res )
end


function p.main( frame )
    local args = frame:getParent().args
    return p._main( args[ 1 ], args.category, args.isUsed )
end


---@param currentPageName string|nil
---@param addCategories boolean|string|nil
---@return string
function p._main( currentPageName, addCategories, isUsed )
    libraryUtil.checkType( 'Module:RequireList._main', 1, currentPageName, 'string', true )
    libraryUtil.checkTypeMulti( 'Module:RequireList._main', 2, addCategories, { 'boolean', 'string', 'nil' } )
    libraryUtil.checkTypeMulti( 'Module:RequireList._main', 3, isUsed, { 'boolean', 'string', 'nil' } )

    local title = mw.title.getCurrentTitle()

    -- Leave early if not in module or template namespace
    if param.is_empty( currentPageName ) and
        ( not arr.contains( { moduleNSName, templateNSName }, title.nsText ) ) then
        return ''
    end

    currentPageName = param.default_to( currentPageName, title.fullText )
    currentPageName = string.gsub( currentPageName, '/[Dd]o[ck]u?$', '' )
    currentPageName = formatPageName( currentPageName )
    addCategories = yn( param.default_to( addCategories, title.subpageText~='doc' ) )
    moduleIsUsed = yn( param.default_to( isUsed, false ) )

    if title.text:lower():find( 'sandbox' ) then
    	moduleIsUsed = true -- Don't show sandbox modules as unused
    end

    if currentPageName:find( '^' .. templateNSName .. ':' ) then
        local ok, invokeList = pcall( getInvokeCallList, currentPageName )
		if ok then
        	return formatInvokeCallList( currentPageName, addCategories, invokeList )
        else
			return userError( invokeList )
		end
    end

    local whatTemplatesLinkHere = {}
    local whatModulesLinkHere = {}

    local function cleanFrom( from )
        from = from or ''
        local parts = mw.text.split( from, '|', true )

        if #parts == 2 then
            local name = string.gsub( parts[ 1 ], '%[%[:', '' )
            name = string.gsub( name, '/[Dd]o[ck]u?', '' )

            return name
        end

        return nil
    end

    local templatesRes = mw.smw.ask({
        '[[Links to::' .. currentPageName .. ']]',
        '[[Template:+]]',
        'sort=Links to',
        'order=asc',
        'mainlabel=from'
    }) or {}

    whatTemplatesLinkHere = arr.new( arr.condenseSparse( arr.map( templatesRes, function ( link )
        return cleanFrom( link[ 'from' ] )
    end ) ) ):unique()

    local moduleRes = mw.smw.ask( {
        '[[Links to::' .. currentPageName .. ']]',
        '[[Module:+]]',
        'sort=Links to',
        'order=asc',
        'mainlabel=from'
    } ) or {}

    whatModulesLinkHere = arr.new( arr.condenseSparse( arr.map( moduleRes, function ( link )
        return cleanFrom( link[ 'from' ] )
    end ) ) ):unique():reject( { currentPageName } )

    local requireList, loadDataList, usedTemplateList, extraCategories;
    do
        local ok;
        ok, requireList, loadDataList, usedTemplateList, extraCategories = pcall( getRequireList, currentPageName, true );
        if not ok then
            return userError( requireList );
        end
    end

    requireList = arr.map( requireList, function ( moduleName )
        if moduleName:find( '%%' ) then
            return formatDynamicQueryLink( moduleName )
        else
            return '[[' .. moduleName .. ']]'
        end
    end )

    loadDataList = arr.map( loadDataList, function ( moduleName )
        if moduleName:find( '%%' ) then
            return formatDynamicQueryLink( moduleName )
        else
            return '[[' .. moduleName .. ']]'
        end
    end )

    usedTemplateList = arr.map( usedTemplateList, function( templateName )
        if string.find( templateName, ':' ) then -- Real templates are prefixed by a namespace, magic words are not
            return '[['..templateName..']]'
        else
            return "'''&#123;&#123;"..templateName.."&#125;&#125;'''" -- Magic words don't have a page so make them bold instead
        end
    end )

    local res = {}

    table.insert( res, formatInvokedByList( currentPageName, addCategories, whatTemplatesLinkHere ) )
    table.insert( res, formatRequireList( currentPageName, addCategories, requireList ) )
    table.insert( res, formatLoadDataList( currentPageName, addCategories, loadDataList ) )
    table.insert( res, formatUsedTemplatesList( currentPageName, addCategories, usedTemplateList ) )
    table.insert( res, formatRequiredByList( currentPageName, addCategories, whatModulesLinkHere ) )

	if addCategories then
		extraCategories = arr.map( extraCategories, function( categoryName )
			return "[[Category:" .. categoryName .. "]]";
		end )

		table.insert( res, table.concat( extraCategories ) );
	end

    if not moduleIsUsed then
        table.insert( res, 1, messageBoxUnused( currentPageName:gsub( 'Module:', '' ), addCategories ) )
    end

    return table.concat( res )
end


return p
-- </nowiki>
