require( 'strict' )

local ItemVariants = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local MODULE_NAME = 'Module:ItemVariants'
local config = mw.loadJsonData( MODULE_NAME .. '/config.json' )

local TNT = require( 'Module:Translate' ):new()


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    return TNT:translate( MODULE_NAME .. '/i18n.json', config, key, addSuffix, { ... } ) or key
end

--- Escape magic characters in Lua for use in regex
--- TODO: This should be move upstream to Module:Common
---
--- @param str string string to escape
--- @return string
local function escapeMagicCharacters( str )
    local magicCharacters = { "%", "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?" }
    for _, magicChar in ipairs( magicCharacters ) do
        str = str:gsub( "%" .. magicChar, "%%" .. magicChar )
    end
    return str
end

--- Find common words between two strings
--- TODO: This should be move upstream to Module:Common
---
--- @param str1 string
--- @param str2 string
--- @return table
local function findCommonWords( str1, str2 )
    local words1 = {}
    local words2 = {}
    local commonWords = {}

    -- Split the first string into words and store in a table
    for word in str1:gmatch( '%S+' ) do
        words1[ word ] = true
    end

    -- Split the second string into words and store in a table
    for word in str2:gmatch( '%S+' ) do
        words2[ word ] = true
    end

    -- Find common words
    for word in pairs( words1 ) do
        if words2[ word ] then
            table.insert( commonWords, word )
        end
    end

    return commonWords
end


--- Remove all occurances of words from string
---
--- @param str string the string to be removed from
--- @param wordsToRemove table the table of strings containing the words to remove
--- @return string
local function removeWords( str, wordsToRemove )
    if type( wordsToRemove ) ~= 'table' or next( wordsToRemove ) == nil then
        return str
    end

    for _, word in ipairs( wordsToRemove ) do
        str = string.gsub( str, escapeMagicCharacters( word ), '' )
    end
    return mw.text.trim( str )
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table|string
local function makeSmwQueryObject( page )
    local smwItemBaseVariantName = translate( 'SMW_ItemBaseVariantName' )
    local smwName = translate( 'SMW_Name' )

    -- 1. On variant page, select variants of base item
    -- 2. On variant page, select base item
    -- 3. On base item page, select variants of base item
    -- 4. On base item page, select base item
    local query = {
        '[[:+]]',
        mw.ustring.format(
            '[[%s::<q>[[-%s::%s]]</q>]] || [[-%s::%s]] || [[%s::%s]] || [[%s::%s]]',
            smwItemBaseVariantName,
            smwItemBaseVariantName,
            page,
            smwItemBaseVariantName,
            page,
            smwItemBaseVariantName,
            page,
            smwName,
            page
        ),
        '?#-=page',
        '?' .. smwName .. '#-=name',
        '?Page Image#-=image'
    }

    return query
end


--- Queries the SMW Store
--- @return table|nil
function methodtable.getSmwData( self, page )
    --mw.logObject( self.smwData, 'cachedSmwData' )
    -- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

    local smwData = mw.smw.ask( makeSmwQueryObject( page ) )

    if smwData == nil or smwData[ 1 ] == nil then
        return nil
    end

    mw.logObject( smwData, 'getSmwData' )
    self.smwData = smwData

    return self.smwData
end

--- Generates wikitext needed for the template
--- @return string
function methodtable.out( self )
    local smwData = self:getSmwData( self.page )

    if smwData == nil then
        local msg = mw.ustring.format( translate( 'error_no_variants_found' ), self.page )
        return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
    end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-itemVariants' )
    local placeholderImage = 'File:' .. config.placeholder_image

    local baseVariantWords = {}

    if smwData[ 1 ] and smwData[ 1 ].name and smwData[ 2 ] and smwData[ 2 ].name then
        baseVariantWords = findCommonWords( smwData[ 1 ].name, smwData[ 2 ].name )
        mw.logObject( baseVariantWords, 'baseVariantWords' )
    end

    for i, variant in ipairs( smwData ) do
        local displayName = ''

        if next( baseVariantWords ) ~= nil then
            displayName = removeWords( variant.name, baseVariantWords )
        end

        -- Sometimes base variant does have a variant name
        if displayName == '' then
            if i == 1 then
                displayName = '(Base)'
            else
                displayName = variant.name
            end
        end

        mw.log( displayName, variant.name )

        local variantHtml = mw.html.create( 'div' ):addClass( 'template-itemVariant' )

        if variant.name == mw.title.getCurrentTitle().fullText then
            variantHtml:addClass( 'template-itemVariant--selected' )
        end

        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-fakelink' )
            :wikitext( mw.ustring.format( '[[%s|%s]]', variant.page, variant.name ) )
        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-image' )
            :wikitext( mw.ustring.format( '[[%s|200px|link=]]', variant.image or placeholderImage ) )
        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-title' )
            :wikitext( displayName )
        containerHtml:node( variantHtml )
    end

    return tostring( containerHtml ) .. mw.getCurrentFrame():extensionTag {
        name = 'templatestyles', args = { src = MODULE_NAME .. '/styles.css' }
    }
end

--- New Instance
---
--- @return table ItemVariants
function ItemVariants.new( self, page )
    local instance = {
        page = page or nil
    }

    setmetatable( instance, metatable )

    return instance
end

--- Parser call for generating the table
function ItemVariants.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or mw.title.getCurrentTitle().rootText

    local instance = ItemVariants:new( page )
    local out = instance:out()

    return out
end

--- For debugging use
---
--- @param page string page name on the wiki
--- @return string
function ItemVariants.test( page )
    local instance = ItemVariants:new( page )
    local out = instance:out()

    return out
end

return ItemVariants
