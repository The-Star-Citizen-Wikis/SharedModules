require( 'strict' )

local p = {}

local i18n = require( 'Module:i18n' ):new()

-- TODO: Move this to data.json or something
local order = {
    -- Pilot weapons
    'WeaponGun.Gun',
    'Turret.BallTurret',
    'Turret.CanardTurret',
    'Turret.GunTurret',
    'Turret.NoseMounted',
    -- Ordnances
    'MissileLauncher.MissileRack',
    'Missile.Missile',
    'Missile.Torpedo',
    'WeaponGun.Rocket',
    'Bomb',
    -- System
    'Shield',
    'PowerPlant.Power',
    'Cooler',
    -- Propulsion
    "QuantumDrive"
}


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- FIXME: Should this go into Module:i18n?
local function hasI18n( key )
    return t( key ) ~= key
end


--- Reorder table by the key listed in order
--- TODO: Move to Module:Common as it can be shared
---
--- @param originalTable table - Table to use
--- @param order table - Table of keys to indicate the order
--- @return table
local function reorderTable( originalTable, order )
    local reorderedTable = {}
    local remainingValues = {}

    -- Iterate over the order table
    for _, key in ipairs( order ) do
        if originalTable[ key ] ~= nil then
            reorderedTable[ #reorderedTable + 1 ] = originalTable[ key ]
            originalTable[ key ] = nil
        end
    end

    -- Add remaining elements to the end of the reordered table
    for _, value in pairs( originalTable ) do
        reorderedTable[ #reorderedTable + 1 ] = value
    end

    return reorderedTable
end


--- Utility function to handle displaying item port size
---
--- @param size any
--- @return string
local function getSize( size )
    if not size then return '-' end
    local sizeText = ''
    if type( size ) == 'string' then
        sizeText = size
    elseif type( size ) == 'number' then
        sizeText = tostring( size )
    elseif type( size ) == 'table' then
        if not size.min and not size.max then return '-' end
        if not size.min then
            sizeText = tostring( size.max )
        elseif not size.max then
            sizeText = tostring( size.min )
        elseif size.min ~= size.max then
            sizeText = string.format( '%d–%d', size.min, size.max )
        else
            sizeText = tostring( size.max )
        end
    end
    return 'S' .. sizeText
end


--- Utilty function to handle item type
---
--- @param type string 
--- @param subtype string|nil
--- @return string
local function getType( type, subtype )
    local key = type
    if subtype and subtype ~= 'UNDEFINED' then
        key = key .. '.' .. subtype
    end
    return key
end


--- Utilty function to get item type label from i18n
---
--- @param type string |nil
--- @return string
local function getItemTypeLabel( type )
    if not type then return 'Unknown' end
    local key = 'label_itemtype_' .. string.lower( type )
    if hasI18n( key ) then
        return t( key )
    end
    return type
end


--- Utility function to get display name of an item
---
--- @param item table
--- @return string
local function getItemName( item )
    if item.name == '<= PLACEHOLDER =>' then
        return item.class_name
    end
    return item.name or item.class_name
end


--- Map port data from API to data format for the template
---
--- @param port table
--- @return table
local function getPortData( port )
    local data = {}
    local item = port.equipped_item
    local itemClassName = port.class_name

    data.portName = port.name

    if item then
        data.itemType = getType( item.type, item.sub_type )
        data.size = getSize( item.size )
        data.title = getItemName( item )
        data.attr = {
            [ 'item-uuid' ] = item.uuid,
            [ 'item-type' ] = data.itemType,
            [ 'has-item' ] = ''
        }
    -- For items that are either placeholder or not parsed by API
    elseif itemClassName and itemClassName ~= '' then
        data.size = getSize( port.sizes )
        -- Try to get size from class name
        if data.size == '-' then
            -- Convert to number first to get rid of the zero-padded number
            local sizeNumFromClassName = tonumber( itemClassName:match( '_S(%d%d)_' ) )
            data.size = getSize( sizeNumFromClassName )
        end
        data.title = itemClassName
        data.attr = {
            [ 'has-item' ] = ''
        }
    else
        data.size = getSize( port.sizes )
        data.pretitle = port.name
        data.title = 'No item equipped'
    end
    return data
end


--- Map ports data from API to data format for the template
--- Ports data are retrieved from game data
---
--- @param ports table
--- @param level number|nil
--- @return table
local function getPortsData( ports, level )
    --mw.logObject( ports, '📡 [ItemPorts/Vehicle] Load ports from API')
    level = level or 1
    local data = {}
    for i = 1, #ports do
        local port = ports[ i ]
        local portData = getPortData( port )
        portData.level = level
        local childPorts = port.ports
        if childPorts and #childPorts > 0 then
            portData.ports = getPortsData( childPorts, level + 1 )
        end
        -- Index port by their types
        local portType = portData.itemType or 'Unknown'
        data[ portType ] = data[ portType ] or {
            label = getItemTypeLabel( portData.itemType ),
            list = {}
        }
        table.insert( data[ portType ].list, portData )
    end
    return data
end

--[[
--- Map component data from API to data format for the template
---
--- @param port table
--- @return table
local function getComponentData( port )
    local data = {
        title = port.name,
        itemType = port.type,
    }
    if port.component_size and tonumber( port.component_size ) then
        data.size = getSize( port.component_size )
    elseif port.component_size ~= '' then
        -- Convert alphabetical size to numeric size
        local sizenumMap = {
            V = 0,
            S = 1,
            M = 2,
            L = 3,
            C = 4
        }
        data.size = getSize( sizenumMap[ port.component_size ] )
    else
        data.size = port.component_size or '-'
    end
    if port.manufacturer ~= '' then
        data.subtitle = port.manufacturer
    else
        -- Always output TBD if empty because CIG is inconsistent
        data.subtitle = 'TBD'
    end
    if port.mounts and port.mounts > 1 then
        data.quantity = port.mounts
    end
    return data
end


--- Map components data from API to data format for the template
--- Components data are retrieved from the Ship Matrix
---
--- @param components table
--- @param level number|nil
--- @return table
local function getComponentsData( components, level )
    local data = {}
    level = level or 1
    for i = 1, #components do
        local port = components[ i ]
        local hasChildPorts = port.quantity and port.quantity > 1
        local portData = getComponentData( port )
        portData.level = level
        if hasChildPorts then
            if port.type == 'missiles' then
                portData.title = 'Missile launcher'
                portData.itemType = 'Missile launcher'
            elseif port.type == 'turrets' then
                portData.title = 'Turret'
                portData.itemType = 'Turret'
            elseif port.type == 'weapons' then
                portData.title = 'Weapon mount'
                portData.itemType = 'Weapon mount'
            else
                portData.title = 'Mount'
                portData.itemType = 'Mount'
            end
            portData.manufacturer = 'TBD'

            local childPorts = {
                {
                    name = port.name,
                    size = port.component_size,
                    manufacturer = port.manufacturer,
                    mounts = port.quantity,
                    type = port.type
                }
            }
            portData.ports = getComponentsData( childPorts, level + 1 )
        end
        -- Index port by their types
        local portType = portData.itemType or 'Unknown'
        data[ portType ] = data[ portType ] or {
            label = portType,
            list = {}
        }
        table.insert( data[ portType ].list, portData )
    end
    return data
end
]]--

--- Return mw.html object for each item port
---
--- @param data table
--- @return mw.html
local function getPortHTML( data )
    local html = mw.html.create( 'div' )
        :addClass( 'template-itemport' )

    local port = html:tag( 'div' )
        :addClass( 'template-itemport-port' )

    local item = html:tag( 'div' )
        :addClass( 'template-itemport-item' )

    if data.attr and next( data.attr ) ~= nil then
        for k, v in pairs( data.attr ) do
            html:attr( 'data-itemport-' .. k, v )
        end
    end

    port:attr( 'title', data.portName )

    if data.quantity then
        port:tag( 'div' )
            :addClass( 'template-itemport-text-subtle' )
            :wikitext( data.quantity .. 'x' )
    end

    if data.size then
        port:tag( 'div' )
            :addClass( 'template-itemport-size' )
            :wikitext( data.size )
    end

    if data.pretitle then
        item:tag( 'div' )
            :addClass( 'template-itemport-text-subtle' )
            :wikitext( data.pretitle )
    end

    item:tag( 'div' )
        :addClass( 'template-itemport-text-emphasized' )
        :wikitext( data.title )

    if data.subtitle then
        item:tag( 'div' )
            :addClass( 'template-itemport-text-subtle' )
            :wikitext( data.subtitle )
    end

    return html
end


--- Return mw.html object for all the item ports
---
--- @param data table
--- @param level number
--- @return mw.html|nil
local function getPortsHTML( data, level )
    level = level or 1
    local html = mw.html.create()

    for _, ports in pairs( data ) do
        local groupHTML = html:tag( 'div' )
            :addClass( 'template-itemports-group' )
            :tag( 'div' )
                :addClass( 'template-itemports-group-label' )
                :wikitext( ports.label )
                :done()

        local listHTML = groupHTML:tag( 'ul' )
            :addClass( 'template-itemports-list' )

        for _, port in pairs( ports.list ) do
            if port.level == level then
                local listItemHTML = mw.html.create( 'li' )
                    :addClass( 'template-itemports-list-item' )

                listItemHTML:node( getPortHTML( port ) )

                local childPorts = port.ports
                if childPorts and next( childPorts ) ~= nil then
                    listItemHTML:node( getPortsHTML( childPorts, level + 1 ) )
                end

                listHTML:node( listItemHTML )
            end

            if port.level < level then
                return
            end
        end
    end

    return html
end


--- Return mw.html object for the entire template
---
--- @param data table
--- @return mw.html|nil
local function getOutputHTML( data )
    local html = mw.html.create( 'div' )
        :addClass( 'template-itemports' )

    html:node( getPortsHTML( data ) )

    return html
end


--- Get vehicle data from the Star Citizen Wiki API
---
--- @param query string - Query (e.g. Name or UUID) used to retrive vehicle data from the API
--- @return table
local function getAPIData( query )
    local api = require( 'Module:Common/Api' )
    local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.get_raw( 'v3/vehicles/' .. query, {
        include = {
            'ports'
        }
    } ) )

    if not success or api.checkResponseStructure( json, true, false ) == false then return end
    return api.makeAccessSafe( json.data )
end


function p.main( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local query = args[ 1 ] or mw.title.getCurrentTitle().text
    local data = getAPIData( query )

    -- TODO: Better error template
    if not data then
        return string.format( '[ItemPort/Vehicle] No API data found for %s', query )
    end

    if not data.ports then
        return string.format( '[ItemPort/Vehicle] No ports data found for %s', query )
    end

    local portsData = getPortsData( data.ports )
    portsData = reorderTable( portsData, order )

    return tostring( getOutputHTML( portsData ) ) .. frame:extensionTag{
        name = 'templatestyles', args = { src = 'User:Alistair3149/sandbox/itemport2/styles.css' }
    }
end


--- Type p.test( 'SHIPNAME' ) to debug in Lua console
---
--- @param query string - Name or UUID of the vehicle
--- @return nil
function p.test( query )
    query = query or 'b9bc6679-81ad-472b-8b98-866c72fe6a89'
    local data = getAPIData( query )

    if not data then
        mw.log( string.format( '[ItemPort/Vehicle] No API data found for %s', query ) )
        return
    end

    --mw.logObject( data )

    if not data.ports then
        return string.format( '[ItemPort/Vehicle] No ports data found for %s', query )
    end

    local portsData = getPortsData( data.ports )
    portsData = reorderTable( portsData, order )
    mw.logObject( portsData )

    return
end

return p
