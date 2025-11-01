# Module:Entity

A modular, compositional system for handling in-game entities in Star Citizen. Provides automatic API integration, flexible parameter resolution, and type-specific rendering.

## Overview

The Entity module system is designed around three layers:

1. **Entity.lua** - Base module and entry point for all entities
2. **Type modules** (e.g., Item.lua) - Handle specific entity types
3. **Subtype modules** (e.g., WeaponGun.lua, Food.lua) - Handle specialized rendering for item subtypes

## Architecture

### Entity.lua (Base Module)

The main entry point that:
- Defines universal parameters (`uuid`, `name`, `className`)
- Manages API configuration and fetching (two-phase fetch for subtype-specific APIs)
- Loads appropriate type modules based on entity type
- Provides utility functions for parameter resolution

### Item.lua (Type Module)

Handles all item-type entities:
- Defines item-specific parameters (dimensions, mass)
- Detects item subtypes from API response
- Loads subtype modules dynamically
- Orchestrates rendering with automatic Engineering section (heat/power/distortion/durability)
- Renders base infobox sections (volume, dimensions, development)

### Subtype Modules

Specialized modules for specific item types:
- **WeaponGun.lua** - Ship weapons (damage, DPS, fire rate, range, capacity)
- **WeaponPersonal.lua** - Personal weapons (damage, fire rate, magazine size)
- **QuantumDrive.lua** - Quantum drives (fuel requirement, speed, cooldown, acceleration)
- **PowerPlant.lua** - Power plants (power output)
- **Food.lua** - Food items (NDR, effects)
- **Drink.lua** - Drink items (HEI, NDR, effects)

## Usage

### Basic Usage

```lua
{{#invoke:Entity|main|uuid=<uuid>}}
```

### With Manual Overrides

```lua
{{#invoke:Entity|main
|uuid=02d4cd2e-fa98-4086-aee1-6b2dfce8ea27
|name=Custom Name Override
|length=10
|width=5
}}
```

### Manual Entry (No API)

```lua
{{#invoke:Entity|main
|name=Upcoming Item
|length=10
|width=5
|height=2
|mass=100
}}
```

## Parameter System

### Parameter Definition

Parameters are defined in configuration tables with:
- `name` - Parameter name
- `sources` - Priority-ordered list of data sources (`local`, `api`, `page_title`)
- `apiField` - Dot-separated path to API field (e.g., `dimension.length`)
- `apiConfig` - Which API to fetch from (e.g., `starCitizenWiki`)

### Parameter Resolution Priority

For each parameter, sources are checked in order:
1. **local** - Wikitext template argument
2. **api** - API response data
3. **page_title** - Current page title (for `name` only)

### Universal Parameters (Entity.lua)

- `uuid` - Entity UUID (local only, used to fetch API)
- `name` - Entity name (local → API → page title)
- `className` - Game class name (API only)

### Item Parameters (Item.lua)

- `length`, `width`, `height` - Dimensions (local → API)
- `volume` - Volume in SCU (API only)
- `mass` - Mass in kg (local → API)

## API Integration

### Two-Phase API Fetching

1. **Phase 1**: Fetch base API using `uuid`
2. **Phase 2**: If subtype module defines additional APIs, fetch those too

### API Configuration

```lua
p.API_CONFIGS = {
	starCitizenWiki = {
		name = 'StarCitizenWikiAPI',
		endpoint = 'v2/items/%s',
		params = { locale = 'en_EN' },
		responseDataPath = 'data'
	}
}
```

### Nested Data Access

API fields support dot notation for nested data:
- `dimension.length` → `apiData.dimension.length`
- `vehicle_weapon.damage_per_shot` → `apiData.vehicle_weapon.damage_per_shot`

## Rendering

### Infobox Structure

All items render an infobox with sections in this order:
1. **Main** - Volume (if available)
2. **Key stats** - Subtype-specific stats (collapsible)
3. **Engineering** - Heat, Power, Distortion, Durability (collapsed, data-driven)
4. **Dimensions** - Length, width, height, mass (collapsed)
5. **Development** - Class name, UUID (collapsed)

### Data-Driven Engineering Section

The Engineering section is automatically generated based on API data presence:
- **Heat**: Max temperature, overheat temperature, cooling rate
- **Power**: Power draw, EM signature
- **Distortion**: Maximum, decay rate
- **Durability**: Health, max lifetime, repairable, salvageable

Only appears if at least one subsection has data.

## Extending the System

### Creating a New Subtype Module

1. Create `Entity/Item/YourType.lua`
2. Implement `p.getAdditionalSections(paramValues, context)`
3. Return table of sections with items
4. The system will automatically load it based on API `type` field

Example structure:

```lua
require( 'strict' )

local p = {}

--- Optional: Define subtype-specific parameters
p.PARAMETERS = {
	{
		name = 'yourField',
		sources = { 'api' },
		apiField = 'your_api_field',
		apiConfig = 'starCitizenWiki'
	}
}

--- Optional: Define additional APIs to fetch
p.API_CONFIGS = {
	yourApi = {
		name = 'YourAPI',
		endpoint = 'v2/yourtype/%s',
		params = { locale = 'en_EN' },
		responseDataPath = 'data'
	}
}

--- Build your type-specific section
local function buildYourSection( apiData )
	local items = {}
	
	if apiData.your_field then
		table.insert( items, {
			label = 'Your Label',
			content = tostring( apiData.your_field )
		} )
	end
	
	if #items > 0 then
		return {
			label = 'Key stats',
			collapsible = true,
			columns = 2,
			items = items
		}
	end
	
	return nil
end

--- Return sections for rendering
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki
	
	if not apiData then
		return sections
	end
	
	local yourSection = buildYourSection( apiData.your_type_data )
	if yourSection then
		table.insert( sections, yourSection )
	end
	
	return sections
end

return p
```

## File Structure

```
Entity/
├── Entity.lua              # Base module (entry point)
├── Item.lua                # Item type module
├── Item/
│   ├── WeaponGun.lua       # Ship weapon subtype
│   ├── WeaponPersonal.lua  # Personal weapon subtype
│   ├── QuantumDrive.lua    # Quantum drive subtype
│   ├── PowerPlant.lua      # Power plant subtype
│   ├── Food.lua            # Food subtype
│   └── Drink.lua           # Drink subtype
└── README.md               # This file
```