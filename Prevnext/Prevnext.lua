require( 'strict' )

local Prevnext = {}

local metatable = {}
local methodtable = {}


metatable.__index = methodtable


--- Returns true if a page exists
--- @param page string
--- @return boolean
local function pageExists( page )
	local title = mw.title.new( page )
	return title and title.exists
end


--- Creates the prev/next header
---
--- @return string
function methodtable.make( self )
	local function makeLink( dir )
		if not self.frameArgs[ dir ] then
			return
		end

		local arrow = 'ArrowPrevious'
		if dir == 'next' then arrow = 'ArrowNext' end

		local inner = mw.html.create( 'div' )
		inner:addClass( 'template-prevnext__' .. dir )
			:addClass( 'template-prevnext__link' )

		if not pageExists( self.frameArgs[ dir ] ) then
			inner:addClass( 'template-prevnext__link--new' )
		end

		local icon = mw.html.create( 'div' )

		icon:addClass( 'template-prevnext__icon' )
			:wikitext( string.format( '[[File:WikimediaUI-%s-ltr.svg|14px|link=]]', arrow ) )
			:done()

		if dir == 'prev' then
			inner:node( icon )
		end

		local content = inner:tag( 'div' )
			:addClass( 'template-prevnext__content' )
			:tag( 'div' )
			:addClass( 'template-prevnext__title' )
			:wikitext( self.frameArgs[ dir .. 'Title' ] or self.frameArgs[ dir ] )
			:done()

		if self.frameArgs[ dir .. 'Desc' ] then
			content:tag( 'div' )
				:addClass( 'template-prevnext__desc' )
				:wikitext( self.frameArgs[ dir .. 'Desc' ] )
				:done()
		end

		if dir == 'next' then
			inner:node( icon )
		end

		inner:tag( 'div' )
			:addClass( 'template-prevnext__linkoverlay' )
			:wikitext( string.format( '[[%s]]', self.frameArgs[ dir ] ) )
			:allDone()

		return inner
	end

	local div = mw.html.create( 'div' )
	div:addClass( 'template-prevnext' )

	local current = mw.html.create( 'div' )
	current:addClass( 'template-prevnext__current' )

	local content = current:tag( 'div' )
		:addClass( 'template-prevnext__content' )
		:tag( 'div' )
		:addClass( 'template-prevnext__title' )
		:wikitext( self.frameArgs[ 'title' ] or mw.title.getCurrentTitle().subpageText )
		:done()

	if self.frameArgs[ 'desc' ] then
		content:tag( 'div' )
			:addClass( 'template-prevnext__desc' )
			:wikitext( self.frameArgs[ 'desc' ] )
	end

	current:allDone()

	div:node( makeLink( 'prev' ) ):node( current ):node( makeLink( 'next' ) )

	return mw.getCurrentFrame():extensionTag {
		name = 'templatestyles', args = { src = 'Module:Prevnext/styles.css' }
	} .. tostring( div:allDone() )
end

--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end

--- New Instance
function Prevnext.new( self, args )
	local instance = {
		frameArgs = args
	}

	setmetatable( instance, metatable )

	return instance
end

--- Template entry
function Prevnext.main( frame )
	local instance = Prevnext:new()
	instance:setFrame( frame )

	return instance:make()
end

return Prevnext
