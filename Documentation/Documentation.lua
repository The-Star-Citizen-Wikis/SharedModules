-- <nowiki>
local dependencyList = require( 'Module:DependencyList' )
local hatnote = require( 'Module:Hatnote' )._hatnote
local mbox = require( 'Module:Mbox' )._mbox
local TNT = require( 'Module:Translate' ):new()
local lang = mw.getContentLanguage()
local p = {}


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, ... )
	local success, translation = pcall( TNT.format, 'Module:Documentation/i18n.json', key or '', ... )

	if not success or translation == nil then
		return key
	end

	return translation
end


function p.doc( frame )
    local title = mw.title.getCurrentTitle()
    local args = frame:getParent().args
    local page = args[1] or mw.ustring.gsub( title.fullText, '/[Dd]o[ck]u?$', '' )
    local ret, cats, ret1, ret2, ret3
    local pageType = title.namespace == 828 and translate( 'module' ) or translate( 'template' )

    -- subpage header
    if title.subpageText == 'doc' then
		ret = mbox(
			translate( 'message_subpage_title', page ),
			translate( 'message_subpage_desc', page, pageType ),
			{ icon = 'WikimediaUI-Notice.svg' }
    	)

        if title.namespace == 10 then -- Template namespace
            cats = '[[Category:' .. translate( 'category_template_documentation' ) .. '|' .. title.baseText .. ']]'
            ret2 = dependencyList._main()
        elseif title.namespace == 828 then -- Module namespace
            cats = '[[Category:' .. translate( 'category_module_documentation' ) .. '|' .. title.baseText .. ']]'
            ret2 = dependencyList._main()
            ret2 = ret2 .. require('Module:Module toc').main()
        else
            cats = ''
            ret2 = ''
        end

        return tostring( ret ) .. ret2 .. cats
    end

    -- template header
    -- don't use mw.html as we aren't closing the main div tag
    ret1 = '<div class="documentation">'

    ret2 = mw.html.create( nil )
        :tag( 'div' )
            :addClass( 'documentation-header' )
            :tag( 'span' )
                :addClass( 'documentation-title' )
                :wikitext( lang:ucfirst( translate('message_documentation_title', pageType ) ) )
                :done()
            :tag( 'span' )
                :addClass( 'documentation-links plainlinks' )
                :wikitext(
                    '[[' .. tostring( mw.uri.fullUrl( page .. '/doc', {action='view'} ) ) .. ' view]]' ..
                    '[[' .. tostring( mw.uri.fullUrl( page .. '/doc', {action='edit'} ) ) .. ' edit]]' ..
                    '[[' .. tostring( mw.uri.fullUrl( page .. '/doc', {action='history'} ) ) .. ' history]]' ..
                    '[<span class="jsPurgeLink">[' .. tostring( mw.uri.fullUrl( title.fullText, { action = 'purge' } ) ) .. ' purge]</span>]'
                )
                :done()
            :done()
        :tag( 'div' )
            :addClass( 'documentation-subheader' )
            :tag( 'span' )
                :addClass( 'documentation-documentation' )
                :wikitext( translate( 'message_transclude_desc', page ) )
                :done()
            :wikitext( frame:extensionTag{ name = 'templatestyles', args = { src = 'Module:Documentation/styles.css'} } )
            :done()

    ret3 = {}

    if args.scwShared then
    	--- Message box
    	table.insert( ret3,
    		mbox(
	    		translate(
					'message_shared_across',
					title.fullText,
					mw.uri.encode( title.rootText, 'PATH' )
				),
				translate(
					'message_shared_across_subtext',
					pageType
				),
				{ icon = 'WikimediaUI-ArticleDisambiguation-ltr.svg' }
			)
	   )
	   --- Set category
	   table.insert( ret3, '[[Category:' .. translate( 'category_shared_across', lang:ucfirst( pageType ) ) .. ']]' )
		--- Interlanguage link
		--- TODO: Make this into a for loop when there are more wikis
		for _, code in pairs{ 'de', 'en' } do
			if lang:getCode() ~= code then
	    		table.insert( ret3, mw.ustring.format( '[[%s:%s]]', code, title.fullText ) )
			end
		end
    end

    if args.fromWikipedia then
    	table.insert( ret3,
    		mbox(
	    		translate(
					'message_from_wikipedia',
					title.fullText,
					mw.uri.encode( page, 'WIKI' ),
					page
				),
				translate(
					'message_from_wikipedia_subtext',
					pageType
				),
				{ icon = 'WikimediaUI-Logo-Wikipedia.svg' }
			)
	   )
	   --- Set category
	   table.insert( ret3, '[[Category:' .. translate( 'category_from_wikipedia', lang:ucfirst( pageType ) ) .. ']]' )
    end

    if title.namespace == 828 then
    	-- Has config
    	if mw.title.new( title.fullText .. '/config.json', 'Module' ).exists then
			table.insert( ret3,
				mbox(
		    		translate(
		    			'message_module_configuration',
		    			title.fullText,
		    			title.fullText
		    		),
		    		translate( 'message_module_configuration_subtext' ),
		    		{ icon = 'WikimediaUI-Settings.svg' }
		    	)
			)
    	end

    	-- Has localization
    	if mw.title.new( title.fullText .. '/i18n.json', 'Module' ).exists then
			table.insert( ret3,
				mbox(
		    		translate(
		    			'message_module_i18n',
		    			title.fullText,
		    			title.fullText
		    		),
		    		translate( 'message_module_i18n_subtext' ),
		    		{ icon = 'WikimediaUI-Language.svg' }
		    	)
			)
    	end

    	-- Testcase page
    	if title.subpageText == 'testcases' then
    		table.insert( ret3,
		    	hatnote(
		    		translate( 'message_module_tests', title.baseText ),
		    		{ icon = 'WikimediaUI-LabFlask.svg' }
		    	)
		    )
		end

		table.insert( ret3, mw.ustring.format( '[[Category:%s]]', translate( 'category_module' ) ) )
    end

    --- Dependency list
    table.insert( ret3, dependencyList._main( nil, args.category, args.isUsed ) )

    -- Has templatestyles
	if mw.title.new( title.fullText .. '/styles.css' ).exists then
		table.insert( ret3,
			hatnote(
	    		translate( 'message_styles', title.fullText, title.fullText ),
	    		{ icon = 'WikimediaUI-Palette.svg' }
	    	)
		)
	end

    --- Module stats bar
    if title.namespace == 828 then
		table.insert( ret3, '<div class="documentation-modulestats">' )

		-- Function list
		table.insert( ret3, require( 'Module:Module toc' ).main() )

		-- Unit tests
		local testcaseTitle = title.baseText .. '/testcases'
		if mw.title.new( testcaseTitle, 'Module' ).exists then
			-- There is probably a better way :P
			table.insert( ret3, frame:preprocess( '{{#invoke:' .. testcaseTitle .. '|run}}' ) )
    	end

    	table.insert( ret3, '</div>' )
    end

    return ret1 .. tostring( ret2 ) .. '<div class="documentation-content">' .. table.concat( ret3 )
end

return p

-- </nowiki>
