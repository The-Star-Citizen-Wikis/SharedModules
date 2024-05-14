require( 'strict' )

local VehicleVariants = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local MODULE_NAME = 'Module:VehicleVariants'
local config = mw.loadJsonData( MODULE_NAME .. '/config.json' )

local i18n = require( 'Module:i18n' ):new()


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table|nil
local function makeSmwQueryObject( page )
    local smwName = t( 'SMW_Name' )
    local smwSeries = t( 'SMW_Series' )

    local series = mw.smw.ask( {
    	'[[' .. page .. ']]',
    	'?' .. smwSeries .. '#=value',
    	'?limit=1'
    } )[1].value

    if not series then return end

    local query = {
        '[[:+]]',
        mw.ustring.format( '[[%s::%s]]', smwSeries, series ),
        '[[Category:Ground vehicles||Ships]]',
        '?#-=page',
        '?' .. smwName .. '#-=name',
        '?' .. t( 'SMW_Role' ) .. '#-=role',
        '?Page Image#-=image',
        'sort=',
        'order=asc',
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
        local msg = mw.ustring.format( t( 'message_error_no_variants_found' ), self.page )
        return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
    end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-vehicleVariants' )
    local placeholderImage = 'File:' .. config.placeholder_image

    for i, variant in ipairs( smwData ) do
        if variant.name then
            local variantHtml = mw.html.create( 'div' ):addClass( 'template-vehicleVariant' )

            if variant.name == mw.title.getCurrentTitle().fullText then
                variantHtml:addClass( 'template-vehicleVariant--selected' )
            end

            variantHtml:tag( 'div' )
                :addClass( 'template-vehicleVariant-fakelink' )
                :wikitext( mw.ustring.format( '[[%s|%s]]', variant.page, variant.name ) )
            variantHtml:tag( 'div' )
                :addClass( 'template-vehicleVariant-image' )
                :wikitext( mw.ustring.format( '[[%s|400px|link=]]', variant.image or placeholderImage ) )

            local variantTextHtml = mw.html.create( 'div' )
                :addClass( 'template-vehicleVariant-text' )
                :tag( 'div' )
                    :addClass( 'template-vehicleVariant-title' )
                    :wikitext( variant.name )
                    :done()
            local role = variant.role
            if type( variant.role ) == 'table' then role = table.concat( variant.role, ', ' ) end
            variantTextHtml:tag( 'div' )
                :addClass( 'template-vehicleVariant-subtitle' )
                :wikitext( role )
            variantHtml:node( variantTextHtml )

            containerHtml:node( variantHtml )
        end
    end

    return tostring( containerHtml ) .. mw.getCurrentFrame():extensionTag {
        name = 'templatestyles', args = { src = MODULE_NAME .. '/styles.css' }
    }
end


--- New Instance
---
--- @return table VehicleVariants
function VehicleVariants.new( self, page )
    local instance = {
        page = page or nil
    }

    setmetatable( instance, metatable )

    return instance
end


--- Parser call for generating the table
function VehicleVariants.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or mw.title.getCurrentTitle().text

    local instance = VehicleVariants:new( page )
    local out = instance:out()

    return out
end


--- For debugging use
---
--- @param page string page name on the wiki
--- @return string
function VehicleVariants.test( page )
    local instance = VehicleVariants:new( page )
    local out = instance:out()

    return out
end

return VehicleVariants
