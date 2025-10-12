require( 'strict' )

local p = {}

local i18n = require( 'Module:i18n' ):new()

-- TODO: Move this to data.json or something
local order = {
    -- Hull
    'FuelIntake.Fuel',
    'FuelTank.Fuel',
    'QuantumFuelTank.QuantumFuel',
    -- Propulsion
    'PowerPlant.Power',
    'QuantumDrive',
    'JumpDrive',
    'MainThruster',
    'ManneuverThruster.Retro',
    'ManneuverThruster',
    'ManneuverThruster.FixedThruster',
    'ManneuverThruster.FlexThruster',
    'ManneuverThruster.JointThruster',
    -- Avionics
    'Radar.MidRangeRadar',
    'Relay',
    -- Systems
    'Shield',
    'Cooler',
    'LifeSupportGenerator',
    -- Pilot weapons
    'WeaponGun.Gun',
    'Turret.BallTurret',
    'Turret.CanardTurret',
    'Turret.GunTurret',
    'Turret.NoseMounted',
    -- Turrets
    'TurretBase.MannedTurret',
    'Turret.PDCTurret',
    -- Ordnances
    'MissileLauncher.MissileRack',
    'Missile.Missile',
    'Missile.Torpedo',
    'WeaponGun.Rocket',
    'Bomb',
    -- Stations
    'SeatAccess'
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
        if originalTable[key] ~= nil then
            reorderedTable[#reorderedTable + 1] = originalTable[key]
            originalTable[key] = nil
        end
    end

    -- Add remaining elements to the end of the reordered table
    for _, value in pairs( originalTable ) do
        reorderedTable[#reorderedTable + 1] = value
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
            ['item-uuid'] = item.uuid,
            ['item-type'] = data.itemType,
            ['has-item'] = ''
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
            ['has-item'] = ''
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
local function getPortsData( ports, level, parentUUIDTracker )
    --mw.logObject( ports, '📡 [ItemPorts/Vehicle] Load ports from API')
    level = level or 1
    local data = {}
    -- uuidTracker tracks { [portType .. '::' .. uuid] = listIndex } for grouping
    -- Use parentUUIDTracker if provided (for recursion), otherwise initialize
    local uuidTracker = parentUUIDTracker or {}

    for i = 1, #ports do
        local port = ports[i]
        local portData = getPortData( port )
        portData.level = level

        -- Index port by their types
        local portType = portData.itemType or 'Unknown'
        data[portType] = data[portType] or {
            label = getItemTypeLabel( portData.itemType ),
            list = {}
        }

        local childPorts = port.ports
        local hasChildren = childPorts and #childPorts > 0
        local uuid = portData.attr and portData.attr['item-uuid']

        if hasChildren then
            -- Process children recursively, passing a fresh uuidTracker for that level
            local processedChildPorts = getPortsData( childPorts, level + 1, {} )
            -- Assign the processed child ports if the result is not empty
            if next( processedChildPorts ) ~= nil then
                portData.ports = processedChildPorts
            else
                portData.ports = nil
            end
            -- Ports with children are never grouped, always add directly
            table.insert( data[portType].list, portData )
        elseif uuid then
            -- No children, but has UUID: attempt grouping
            local trackingKey = portType .. '::' .. uuid
            local existingIndex = uuidTracker[trackingKey]

            if existingIndex then
                -- Already seen this UUID for this type at this level, increment quantity
                local existingPort = data[portType].list[existingIndex]
                existingPort.quantity = (existingPort.quantity or 1) + 1
            else
                -- First time seeing this UUID for this type at this level
                portData.quantity = 1 -- Initialize quantity
                table.insert( data[portType].list, portData )
                uuidTracker[trackingKey] = #data[portType].list -- Track index for future grouping
            end
        else
            -- No children and no UUID: cannot group, add directly
            table.insert( data[portType].list, portData )
        end
    end

    -- Perform final grouping pass for top-level items
    -- Grouping is now done inline, just return the data structure
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
]] --

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

    if data.quantity and data.quantity > 1 then
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


--- Normalizes a label string (lowercase, trim whitespace).
---
--- @param label string|any
--- @return string|any The normalized string, or original value if not a string.
local function normalizeLabel( label )
    if type(label) ~= 'string' then return label end
    return mw.text.trim( string.lower( label ) )
end


--- Recursively traverses ports data to accumulate total counts for each item type label.
---
--- @param portsData table - The data structure returned by getPortsData.
--- @param countsMap table - A map { [normalizedLabel] = { count=number, displayLabel=string } } to accumulate counts into.
local function accumulateCounts( portsData, countsMap )
    if not portsData or not next( portsData ) then return end -- Base case: empty or nil data

    for _, typeData in pairs( portsData ) do
        local originalLabel = typeData.label
        local normalizedLabel = normalizeLabel( originalLabel )

        -- Initialize entry for this normalized label if first time seen
        if not countsMap[normalizedLabel] then
            countsMap[normalizedLabel] = { count = 0, displayLabel = originalLabel } -- Store first original label encountered
        end

        for _, portItem in ipairs( typeData.list ) do
            -- Get size, default to '-' if nil or empty
            local sizeString = portItem.size
            if not sizeString or sizeString == '' then
                sizeString = '-'
            end

            -- Initialize sizes table if needed
            if not countsMap[normalizedLabel].sizes then
                countsMap[normalizedLabel].sizes = {}
            end

            -- Increment count for this specific size
            local currentQuantity = portItem.quantity or 1
            countsMap[normalizedLabel].sizes[sizeString] = (countsMap[normalizedLabel].sizes[sizeString] or 0) + currentQuantity

            -- Recursively process child ports, if any
            if portItem.ports then
                accumulateCounts( portItem.ports, countsMap )
            end
        end
    end
end


--- Return mw.html object for the entire template
---
--- @param data table
--- @param summaryList table|nil - Optional list of summary items
--- @return mw.html|nil
local function getOutputHTML( data, summaryList )
    local html = mw.html.create( 'div' )
        :addClass( 'template-itemports' )

    -- Add summary section if summaryList is provided and not empty
    if summaryList and #summaryList > 0 then
        local summaryHtml = html:tag( 'div' ):addClass( 'template-itemports-summary' )
        summaryHtml:tag( 'div' ):addClass( 'template-itemports-summary-header' ):wikitext( 'Component Summary' )
        local listHtml = summaryHtml:tag( 'ul' ):addClass( 'template-itemports-summary-list' )
        for _, summaryItem in ipairs( summaryList ) do
            listHtml:tag( 'li' )
                :wikitext( string.format( '%s: %s', summaryItem.label, summaryItem.sizeBreakdown ) )
        end
    end

    html:node( getPortsHTML( data ) )

    return html
end


--- Get vehicle data from the Star Citizen Wiki API
---
--- @param query string - Query (e.g. Name or UUID) used to retrive vehicle data from the API
--- @return table
local function getAPIData( query )
    local api = require( 'Module:Common/Api' )
    local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.fetch(
        'StarCitizenWikiAPI',
        'v3/vehicles/' .. query,
        {
            include = {
                'ports'
            }
        }
    ) )

    if not success or api.checkResponseStructure( json, true, false ) == false then return end
    return api.makeAccessSafe( json.data )
end


function p.main( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local query = args[1] or mw.title.getCurrentTitle().text
    local data = getAPIData( query )

    -- TODO: Better error template
    if not data then
        return string.format( '[ItemPort/Vehicle] No API data found for %s', query )
    end

    if not data.ports then
        return string.format( '[ItemPort/Vehicle] No ports data found for %s', query )
    end

    -- 1. Get the raw, nested port data structure
    local rawPortsData = getPortsData( data.ports, 1, {} )

    -- 2. Calculate the total counts for all items recursively
    local countsMap = {}
    accumulateCounts( rawPortsData, countsMap )

    -- 3. Create the ordered summary list using normalized counts and preferred labels from 'order'
    -- Helper function to format size breakdown
    local function formatSizeBreakdown( sizesMap )
        if not sizesMap or not next( sizesMap ) then return '' end

        local sizeList = {}
        for sizeStr, count in pairs( sizesMap ) do
            table.insert( sizeList, { size = sizeStr, count = count } )
        end

        -- Sort sizes: Sx numerically descending, then ranges, then '-', then others alphabetically
        table.sort( sizeList, function(a, b)
            local aNum = tonumber( a.size:match( '^S(%d+)$' ) )
            local bNum = tonumber( b.size:match( '^S(%d+)$' ) )

            if aNum and bNum then return aNum > bNum end -- Both are Sx (Descending)
            if aNum then return true end -- a is Sx, b is not
            if bNum then return false end -- b is Sx, a is not

            -- Handle ranges (e.g., S1–S2) - treat them as less than '-' but greater than Sx
            local aIsRange = a.size:find( '–' )
            local bIsRange = b.size:find( '–' )
            if aIsRange and bIsRange then return a.size < b.size end
            if aIsRange then return true end
            if bIsRange then return false end

            if a.size == '-' and b.size == '-' then return false end -- Equal
            if a.size == '-' then return true end -- a is '-', b is not Sx/Range
            if b.size == '-' then return false end -- b is '-', a is not Sx/Range

            return a.size < b.size -- Default alphabetical for others
        end)

        local parts = {}
        for _, item in ipairs( sizeList ) do
            table.insert( parts, string.format( '%dx %s', item.count, item.size ) )
        end

        return table.concat( parts, ', ' )
    end

    local summaryList = {}
    local processedNormalizedLabels = {}

    -- Pass 1: Add items based on the global 'order' table
    for _, itemTypeKey in ipairs( order ) do
        local preferredOriginalLabel = getItemTypeLabel( itemTypeKey )
        local normalizedLabel = normalizeLabel( preferredOriginalLabel )

        if countsMap[normalizedLabel] and not processedNormalizedLabels[normalizedLabel] then
            table.insert( summaryList, {
                label = preferredOriginalLabel,
                sizeBreakdown = formatSizeBreakdown( countsMap[normalizedLabel].sizes )
            } )
            processedNormalizedLabels[normalizedLabel] = true
        end
    end

    -- Pass 2: Add remaining items not covered by the 'order' list
    local remainingItems = {}
    for normalizedLabel, data in pairs( countsMap ) do
        if not processedNormalizedLabels[normalizedLabel] then
            table.insert( remainingItems, {
                label = data.displayLabel,
                sizeBreakdown = formatSizeBreakdown( data.sizes )
            } )
        end
    end

    -- Sort remaining items alphabetically by label for consistent ordering
    table.sort( remainingItems, function(a, b) return a.label < b.label end )

    -- Append sorted remaining items to the main summary list
    for _, item in ipairs( remainingItems ) do
        table.insert( summaryList, item )
    end

    -- 4. Order the main ports data for display
    local orderedPortsData = reorderTable( rawPortsData, order )

    return frame:extensionTag {
        name = 'templatestyles', args = { src = 'User:Alistair3149/sandbox/itemport2/styles.css' }
    } .. tostring( getOutputHTML( orderedPortsData, summaryList ) )
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

    -- Get raw data
    local rawPortsData = getPortsData( data.ports, 1, {} )
    mw.logObject( rawPortsData, 'Raw Ports Data' )

    -- Calculate summary
    local countsMap = {}
    accumulateCounts( rawPortsData, countsMap )
    mw.logObject( countsMap, 'Counts Map' )

    -- Create ordered summary list (mirroring main logic for debugging)
    -- Re-declare helper function for testing scope
    local function formatSizeBreakdownForTest( sizesMap )
        if not sizesMap or not next( sizesMap ) then return '' end
        local sizeList = {}
        for sizeStr, count in pairs( sizesMap ) do table.insert( sizeList, { size = sizeStr, count = count } ) end
        table.sort( sizeList, function(a, b)
            local aNum = tonumber( a.size:match( '^S(%d+)$' ) ); local bNum = tonumber( b.size:match( '^S(%d+)$' ) )
            if aNum and bNum then return aNum > bNum end; if aNum then return true end; if bNum then return false end -- Descending Sx
            local aIsRange = a.size:find( '–' ); local bIsRange = b.size:find( '–' )
            if aIsRange and bIsRange then return a.size < b.size end; if aIsRange then return true end; if bIsRange then return false end
            if a.size == '-' and b.size == '-' then return false end; if a.size == '-' then return true end; if b.size == '-' then return false end
            return a.size < b.size
        end)
        local parts = {}; for _, item in ipairs( sizeList ) do table.insert( parts, string.format( '%dx %s', item.count, item.size ) ) end
        return table.concat( parts, ', ' )
    end

    local summaryList = {}
    local processedNormalizedLabels = {}

    -- Pass 1: Order table
    for _, itemTypeKey in ipairs( order ) do
        local preferredOriginalLabel = getItemTypeLabel( itemTypeKey )
        local normalizedLabel = normalizeLabel( preferredOriginalLabel )

        if countsMap[normalizedLabel] and not processedNormalizedLabels[normalizedLabel] then
            table.insert( summaryList, {
                label = preferredOriginalLabel,
                sizeBreakdown = formatSizeBreakdownForTest( countsMap[normalizedLabel].sizes )
            } )
            processedNormalizedLabels[normalizedLabel] = true
        end
    end

    -- Pass 2: Remainder
    local remainingItems = {}
    for normalizedLabel, data in pairs( countsMap ) do
        if not processedNormalizedLabels[normalizedLabel] then
            table.insert( remainingItems, {
                label = data.displayLabel,
                sizeBreakdown = formatSizeBreakdownForTest( data.sizes )
            } )
        end
    end

    table.sort( remainingItems, function(a, b) return a.label < b.label end )

    for _, item in ipairs( remainingItems ) do
        table.insert( summaryList, item )
    end

    mw.logObject( summaryList, 'Ordered Summary List' )

    -- Order main data
    local orderedPortsData = reorderTable( rawPortsData, order )
    mw.logObject( portsData )

    return
end

return p
