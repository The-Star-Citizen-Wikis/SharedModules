--- Based on Module:DependencyList from RuneScape Wiki
--- Modified to use SMW instead of DPL
--- @see https://runescape.wiki/w/Module:DependencyList

require("strict");

local p = {}
local libraryUtil = require( 'libraryUtil' )
local arr = require( 'Module:Array' )
local yn = require( 'Module:Yesno' )
local param = require( 'Module:Paramtest' )
local userError = require("Module:User error")
local hatnote = require('Module:Hatnote')._hatnote
local mHatlist = require('Module:Hatnote list')
local mbox = require( 'Module:Mbox' )._mbox
local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()

-- Toggle query mode between SemanticMediaWiki (smw) and DynamicPageList3 (dpl)
-- For SMW, you will need the SemanticExtraSpecialProperties extension and enable the 'Links to' property
local QUERY_MODE = 'smw'

local moduleIsUsed = false
local shouldAddCategories = false
local COLLAPSE_LIST_LENGTH_THRESHOLD = 5
local dynamicRequireListQueryCache = {}

local NS_MODULE_NAME =  mw.site.namespaces[ 828 ].name
local NS_TEMPLATE_NAME = mw.site.namespaces[ 10 ].name


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


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
    ["libraryUtil"] = {
        link = "mw:Special:MyLanguage/Extension:Scribunto/Lua reference manual#libraryUtil",
        categories = {},
    },
	[ "strict" ] = {
		link = "mw:Special:MyLanguage/Extension:Scribunto/Lua reference manual#strict",
		categories = { t( 'category_strict_mode_modules' ) },
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
---@param allowBuiltins? boolean
---@return string
local function formatModuleName( str, allowBuiltins )
	if allowBuiltins then
		local name = mw.text.trim( str )
			-- Only remove quotes at start and end of string if both are the same type
            :gsub([[^(['"])(.-)%1$]], '%2')

        if builtins[name] then
            return name
        end
	end

    local module = formatPageName( str )

    if not string.find( module, '^[Mm]odule?:' ) then
        module = NS_MODULE_NAME .. ':' .. module
    end

    return module
end


local function dualGmatch( str, pat1, pat2 )
    local f1 = string.gmatch( str, pat1 )
    if pat2 then
        local f2 = string.gmatch( str, pat2 )
        return function()
            return f1() or f2()
        end
    else
        return f1
    end
end

local function isDynamicPath( str )
    return string.find( str, '%.%.' ) or string.find( str, '%%%a' )
end


--- Used in case a construct like 'require( "Module:wowee/" .. isTheBest )' is found.
--- Will return a list of pages which satisfy this pattern where 'isTheBest' can take any value.
---@param query string
---@return string[]
local function getDynamicRequireList( query )
    if query:find( '%.%.' ) then
        query = mw.text.split( query, '..', true )
        query = arr.map( query, function( x ) return mw.text.trim( x ) end )
        query = arr.map( query, function( x ) return ( x:match('^[\'\"](.-)[\'\"]$') or '%') end )
        query = table.concat( query )
    else
        local _, _query = query:match( '(["\'])(.-)%1' )
        query = _query:gsub( '%%%a', '%%' )
    end
    query = query:gsub( '^[Mm]odule:', '' )

    if dynamicRequireListQueryCache[ query ] then
        return dynamicRequireListQueryCache[ query ];
    end

    return {};
end


--- Returns a list of modules loaded and required by module 'moduleName'.
---@param moduleName string
---@param searchForUsedTemplates boolean|nil
---@return table<string, string[]>
local function getRequireList( moduleName, searchForUsedTemplates )
    local content = mw.title.new( moduleName ):getContent()
    local requireList = arr{}
    local loadDataList = arr{}
    local loadJsonDataList = arr{}
    local usedTemplateList = arr{}
    local dynamicRequirelist = arr{}
    local dynamicLoadDataList = arr{}
    local dynamicLoadJsonDataList = arr{}
    local extraCategories = arr{}

    assert( content ~= nil, translate( 'message_not_exists', moduleName ) )

    content = content:gsub( '%-%-%[(=-)%[.-%]%1%]', '' ):gsub( '%-%-[^\n]*', '' ) -- Strip comments

    local function getList( pat1, pat2, list, dynList )
        for match in dualGmatch( content, pat1, pat2 ) do
            match = mw.text.trim( match )
            local name = extractModuleName( match, content )

            if isDynamicPath( name ) then
                dynList:insert( getDynamicRequireList( name ), true )
            elseif name ~= '' then
                name = formatModuleName( name, true )
                table.insert( list, name )

                if builtins[name] then
                    extraCategories = extraCategories:insert( builtins[name].categories, true )
                end
            end
        end
    end

    getList( 'require%s*(%b())', 'require%s*((["\'])%s*[Mm]odule:.-%2)', requireList, dynamicRequirelist )
    getList( 'mw%.loadData%s*(%b())', 'mw%.loadData%s*((["\'])%s*[Mm]odule:.-%2)', loadDataList, dynamicLoadDataList )
    getList( 'mw%.loadJsonData%s*(%b())', 'mw%.loadJsonData%s*((["\'])%s*[Mm]odule:.-%2)', loadJsonDataList, dynamicLoadJsonDataList )
    getList( 'pcall%s*%(%s*require%s*,([^%),]+)', nil, requireList, dynamicRequirelist )
    getList( 'pcall%s*%(%s*mw%.loadData%s*,([^%),]+)', nil, loadDataList, dynamicLoadDataList )
    getList( 'pcall%s*%(%s*mw%.loadJsonData%s*,([^%),]+)', nil, loadJsonDataList, dynamicLoadJsonDataList )

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

    requireList = requireList .. dynamicRequirelist
    requireList = requireList:unique()
    loadDataList = loadDataList .. dynamicLoadDataList
    loadDataList = loadDataList:unique()
    loadJsonDataList = loadJsonDataList .. dynamicLoadJsonDataList
    loadJsonDataList = loadJsonDataList:unique()
    usedTemplateList = usedTemplateList:unique()
    extraCategories = extraCategories:unique()
    table.sort( extraCategories )

    return {
        requireList = requireList,
        loadDataList = loadDataList,
        loadJsonDataList = loadJsonDataList,
        usedTemplateList = usedTemplateList,
        extraCategories = extraCategories
    }
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

---@return string
local function messageBoxUnused()
	local category = shouldAddCategories and '[[Category:' .. t( 'category_unused_module' ) .. ']]' or ''

	return mbox(
		translate( 'message_unused_module_title' ),
		translate( 'message_unused_module_desc' ),
		{ icon = 'WikimediaUI-Alert.svg' }
	) .. category
end

--- Returns the wikitext for the message template (mbox/hatnote)
---@param msgKey string message key in /i18n.json
---@param pageName string page name used for the message
---@param list table
---@param listType string type of the page list used for the message
---@return string
local function getDependencyListWikitext( msgKey, pageName, list, listType )
    local listLabel = string.format( '%d %s', #list, listType )
    local listContent = mHatlist.andList( list, false )

    --- Return mbox
    if #list > COLLAPSE_LIST_LENGTH_THRESHOLD then
        return mbox(
            translate( msgKey, pageName, listLabel ),
            listContent,
            { icon = 'WikimediaUI-Code.svg' }
        )
    --- Return hatnote
    else
        return hatnote(
            translate( msgKey, pageName, listContent ),
            { icon='WikimediaUI-Code.svg' }
        )
    end
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

--- Helper function to return the wikitext of the templates and categories
---@param currentPageName string
---@param pageList table|nil
---@param pageType string
---@param message string
---@param category string|nil
---@return string
local function formatDependencyList( currentPageName, pageList, pageType, message, category )
    local res = {}

    if type( pageList ) == 'table' and #pageList > 0 then
        table.sort( pageList )
        table.insert( res, getDependencyListWikitext( message, currentPageName, pageList, pageType ) )

        if shouldAddCategories and category then
            table.insert( res, string.format( '[[Category:%s]]', category ) )
        end
    end

    return table.concat( res )
end


---@param templateName string
---@param invokeList table<string, string>[]    @This is the list returned by getInvokeCallList()
---@return string
local function formatInvokeCallList( templateName, invokeList )
    local category = shouldAddCategories and '[[Category:' .. t( 'category_lua_based_template' ) .. ']]' or ''
    local res = {}

    for _, item in ipairs( invokeList ) do
        local msg = translate(
                'message_invokes_function',
    		templateName,
    		item.funcName,
    		item.moduleName
    	)
        table.insert( res, hatnote( msg, { icon = 'WikimediaUI-Code.svg' } ) )
    end

    if #invokeList > 0 then
        table.insert( res, category )
    end

    return table.concat( res )
end


---@param moduleName string
---@param whatLinksHere table    @A list generated by a dpl of pages in the Template namespace which link to moduleName.
---@return string
local function formatInvokedByList( moduleName, whatLinksHere )
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
            --- NOTE: Somehow only templates aren't linked properly, not sure why
            table.insert( invokedByList, translate( 'message_function_invoked_by', invoke.funcName, '[[' .. template.templateName .. ']]' ) )
        end
    end

    if #invokedByList > 0 then
        moduleIsUsed = true
    end

    return formatDependencyList(
        moduleName,
        invokedByList,
        translate( 'list_type_templates' ),
        'message_module_functions_invoked_by',
        t( 'category_template_invoked_modules' )
    )
end


---@param moduleName string
---@param whatLinksHere table      @A list generated by a dpl of pages in the Module namespace which link to moduleName.
---@return string
local function formatRequiredByList( moduleName, whatLinksHere )
    local childModuleData = arr.map( whatLinksHere, function ( title )
        local lists = getRequireList( title )
        return { name = title, requireList = lists.requireList, loadDataList = lists.loadDataList .. lists.loadJsonDataList }
    end )

    local requiredByList = arr.map( childModuleData, function ( item )
        if arr.any( item.requireList, function( x ) return x:lower() == moduleName:lower() end ) then
            if item.name:find( '%%' ) then
                return formatDynamicQueryLink( item.name )
            else
                return '[[' .. item.name .. ']]'
            end
        end
    end )

    local loadedByList = arr.map( childModuleData, function ( item )
        if arr.any( item.loadDataList, function( x ) return x:lower() == moduleName:lower() end ) then
            if item.name:find( '%%' ) then
                return formatDynamicQueryLink( item.name )
            else
                return '[[' .. item.name .. ']]'
            end
        end
    end )

    if #requiredByList > 0 or #loadedByList > 0 then
        moduleIsUsed = true
    end

    local res = {}

    table.insert( res,
        formatDependencyList(
            moduleName,
            requiredByList,
            translate( 'list_type_modules' ),
            'message_required_by',
            t( 'category_modules_required_by_modules' )
        )
    )

    table.insert( res,
        formatDependencyList(
            moduleName,
            loadedByList,
            translate( 'list_type_modules' ),
            'message_loaded_by',
            t( 'category_module_data' )
        )
    )

    return table.concat( res )
end


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


---@param pageName string
---@return table
function p.getWhatTemplatesLinkHere( pageName )
    local whatTemplatesLinkHere = {}

    local templatesRes = mw.smw.ask({
        '[[Links to::' .. pageName .. ']]',
        '[[' .. NS_TEMPLATE_NAME .. ':+]]',
        'sort=Links to',
        'order=asc',
        'mainlabel=from'
    }) or {}

    whatTemplatesLinkHere = arr.new( arr.condenseSparse( arr.map( templatesRes, function ( link )
        return cleanFrom( link[ 'from' ] )
    end ) ) ):unique()

    return whatTemplatesLinkHere
end


---@param pageName string
---@return table
function p.getWhatModulesLinkHere( pageName )
    local whatModulesLinkHere = {}

    local moduleRes = mw.smw.ask( {
        '[[Links to::' .. pageName .. ']]',
        '[[' .. NS_MODULE_NAME .. ':+]]',
        'sort=Links to',
        'order=asc',
        'mainlabel=from'
    } ) or {}

    whatModulesLinkHere = arr.new( arr.condenseSparse( arr.map( moduleRes, function ( link )
        return cleanFrom( link[ 'from' ] )
    end ) ) ):unique():reject( { pageName } )

    return whatModulesLinkHere
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
        ( not arr.contains( { NS_MODULE_NAME, NS_TEMPLATE_NAME }, title.nsText ) ) then
        return ''
    end

    currentPageName = param.default_to( currentPageName, title.fullText )
    currentPageName = string.gsub( currentPageName, '/[Dd]o[ck]u?$', '' )
    currentPageName = formatPageName( currentPageName )
    moduleIsUsed = yn( param.default_to( isUsed, false ) )
    shouldAddCategories = yn( param.default_to( addCategories, title.subpageText~='doc' ) )

    -- Don't show sandbox and testcases modules as unused
    if title.text:lower():find( 'sandbox' ) or title.text:lower():find( 'testcases' ) then
    	moduleIsUsed = true
    end

    if currentPageName:find( '^' .. NS_TEMPLATE_NAME .. ':' ) then
        local ok, invokeList = pcall( getInvokeCallList, currentPageName )
		if ok then
        	return formatInvokeCallList( currentPageName, invokeList )
        else
			return userError( invokeList )
		end
    end

    local ok, lists = pcall( getRequireList, currentPageName, true )
    if not ok then
        return userError( lists )
    end

    local requireList = arr.map( lists.requireList, function ( moduleName )
        if moduleName:find( '%%' ) then
            return formatDynamicQueryLink( moduleName )
        elseif builtins[moduleName] then
            return '[[' .. builtins[moduleName].link .. '|' .. moduleName .. ']]'
        else
            return '[[' .. moduleName .. ']]'
        end
    end )

    local loadDataList = arr.map( lists.loadDataList, function ( moduleName )
        if moduleName:find( '%%' ) then
            return formatDynamicQueryLink( moduleName )
        else
            return '[[' .. moduleName .. ']]'
        end
    end )

    local loadJsonDataList = arr.map( lists.loadJsonDataList, function ( moduleName )
        if moduleName:find( '%%' ) then
            return formatDynamicQueryLink( moduleName )
        else
            return '[[' .. moduleName .. ']]'
        end
    end )

    local usedTemplateList = arr.map( lists.usedTemplateList, function( templateName )
        if string.find( templateName, ':' ) then -- Real templates are prefixed by a namespace, magic words are not
            return '[['..templateName..']]'
        else
            return "'''&#123;&#123;"..templateName.."&#125;&#125;'''" -- Magic words don't have a page so make them bold instead
        end
    end )

    local res = {}

    table.insert( res, formatInvokedByList( currentPageName, p.getWhatTemplatesLinkHere( currentPageName ) ) )
    table.insert( res, formatDependencyList( currentPageName, requireList, translate( 'list_type_modules' ), 'message_requires', t( 'category_modules_required_by_modules' ) ) )
    table.insert( res, formatDependencyList( currentPageName, loadDataList, translate( 'list_type_modules' ), 'message_loads_data_from', t( 'category_modules_using_data' ) ) )
    table.insert( res, formatDependencyList( currentPageName, loadJsonDataList, translate( 'list_type_modules' ), 'message_loads_data_from', t( 'category_modules_using_data' ) ) )
    table.insert( res, formatDependencyList( currentPageName, usedTemplateList, translate( 'list_type_templates' ), 'message_transcludes', nil ) )
    table.insert( res, formatRequiredByList( currentPageName, p.getWhatModulesLinkHere( currentPageName ) ) )

	if shouldAddCategories then
		local extraCategories = arr.map( lists.extraCategories, function( categoryName )
			return "[[Category:" .. categoryName .. "]]";
		end )

		table.insert( res, table.concat( extraCategories ) );
	end

    if not moduleIsUsed then
        table.insert( res, 1, messageBoxUnused() )
    end

    return table.concat( res )
end


return p
-- </nowiki>
