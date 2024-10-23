require( 'strict' )

local Common = {}


--- Converts a SMW Query table into a string representation
---
--- @param queryObject table
--- @return string
function Common.convertSmwQueryObject( queryObject )
    if type( queryObject ) ~= 'table' then
        return 'Arg "queryObject" is not a table.'
    end

    local queryParts = {
        restrictions = {},
        output = {},
        other = {}
    }

    for _, part in ipairs( queryObject ) do
        if string.sub( part, 1, 1 ) == '?' then
            table.insert( queryParts.output, part )
        elseif string.sub( part, 1, 5 ) == '+lang' then
            local index = #queryParts.output
            queryParts.output[ index ] = string.format( '%s|%s', queryParts.output[ index ], part )
        elseif string.sub( part, 1, 2 ) == '[[' then
            table.insert( queryParts.restrictions, mw.getCurrentFrame():callParserFunction( '#tag', { 'nowiki', part } ) )
        elseif #part > 0 and part ~= nil then
            table.insert( queryParts.other, part )
        end
    end

    local queryString = string.format(
        'Restrictions:<pre>%s</pre>Outputs:<pre>%s</pre>Other:<pre>%s</pre>',
        table.concat( queryParts.restrictions, "\n" ),
        table.concat( queryParts.output, "\n"),
        table.concat( queryParts.other, "\n")
    )

    return queryString
end


--- Creates collapsed sections containing debug data
---
--- @param sections table Table of tables containing 'title' and 'content' keys
--- @return string
function Common.collapsedDebugSections( sections )
    local html = ''

    for _, section in ipairs( sections ) do
        local content = section.content or 'No content set on the "content" key.'
        if type( content ) == 'table' then
            content = mw.dumpObject( content )
        end

        local tag = 'div'
        if section.tag then
            tag = section.tag
        end

        local sectionOutput = mw.html.create( 'div' )
            :addClass( 'mw-collapsible' )
            :addClass( 'mw-collapsed' )
            :tag( 'h3' ):wikitext( section.title or '' ):done()
            :tag( tag ):addClass( 'mw-collapsible-content' ):wikitext( content ):done()
            :allDone()

        html = html .. tostring( sectionOutput )
    end

    if #html > 0 then
        html = mw.html.create( 'div' )
            :addClass( 'debug' )
            :addClass( 'mw-collapsible' )
            :addClass( 'mw-collapsed' )
            :node( html )
            :done()
    end

    return tostring( html )
end


return Common