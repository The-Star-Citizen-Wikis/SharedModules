-- Imported from: https://runescape.wiki/w/Module:Module%20toc

-- <nowiki>
local p = {}

local function getNewlineLocations( content )
    local locs = {}
    local pos = 0

    repeat
        pos = string.find( content, '\n', pos + 1, true )
        table.insert( locs, pos )
    until not pos

    return locs
end

local function findLineNumber( pos, newLineLocs )
    local max = #newLineLocs
    local min = 1

    repeat
        local i = math.ceil( (max + min) / 2 )
        if newLineLocs[i] < pos then
            min = i
        elseif newLineLocs[i] >= pos then
            max = i
        end
    until newLineLocs[i] > pos and (newLineLocs[i - 1] or 0) < pos

    return max
end

local function getFunctionLocations( content )
    local locs = {}
    local newLineLocs = getNewlineLocations( content )

    local start = 0
    repeat
        local name
        name, start = string.match( content, '%sfunction%s+([^%s%(]+)%s*%(()', start + 1 )
        if start then
            table.insert( locs, { name=name, line=findLineNumber( start, newLineLocs ) } )
        end
    until not start

    start = 0
    repeat
        local name
        name, start = string.match( content, '%s([^%s=])%s*=%s*function%s*%(()', start + 1 )
        if start then
            table.insert( locs, { name=name, line=findLineNumber( start, newLineLocs ) } )
        end
    until not start

    return locs
end

function p.main()
    local title = mw.title.getCurrentTitle()
    local moduleName = string.gsub( title.text, '/[Dd]oc$', '' )

    if
        title.nsText ~= 'Module'
        or string.find( moduleName, '^Exchange/' )
        or string.find( moduleName, '^Exchange historical/' )
        or string.find( moduleName, '^Data/' )
    then
        return ''
    end

    local fullModuleName = string.gsub( title.fullText, '/[Dd]oc$', '' )
    local content = mw.title.new( fullModuleName ):getContent()

    if not content then
        return ''
    end

    local function substMutilineComment( match )
        local lineCount = #getNewlineLocations( match )
        return string.rep( '\n', lineCount ) or ''
    end

    content = content:gsub( '(%-%-%[(=-)%[.-%]%2%])', substMutilineComment ):gsub( '%-%-[^\n]*', '' ) -- Strip comments
    local functionLocs = getFunctionLocations( content )

    table.sort( functionLocs, function(lhs, rhs) return lhs.line < rhs.line end )

    if #functionLocs == 0 then
        return ''
    end

    local res = {}
    for _, func in ipairs( functionLocs ) do
        table.insert( res, string.format( 'L %d &mdash; [%s#L-%d %s]', func.line, title:fullUrl():gsub( '/[Dd]oc$', '' ), func.line,  func.name ) )
    end

    local tbl = mw.html.create( 'table' ):addClass( 'wikitable mw-collapsible mw-collapsed' )
    tbl:tag( 'tr' )
            :tag( 'th' ):wikitext( 'Function list' ):done()
        :tag( 'tr' )
            :tag( 'td' ):wikitext( table.concat( res, '<br>' ) )

    return tostring( tbl )
end

return p
-- </nowiki>
