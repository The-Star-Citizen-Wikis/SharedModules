# Module:Vehicle

This module handles data related to vehicles.

On the vehicle page
- Saves template parameters and API data as SMW data
- Set category from SMW data
- Set short description from SMW data
- Display infobox from SMW data
  
On other pages, it can be used to display the infobox of other vehicles.

## Requirements
- [Semantic MediaWiki](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki)
- [Extension:Apiunto](https://github.com/StarCitizenWiki/Apiunto)
- [Extension:TabberNeue](https://github.com/StarCitizenTools/mediawiki-extensions-TabberNeue)
- [Module:Arguments](https://www.mediawiki.org/wiki/Module:Arguments)
- Module:Commodity
- Module:Hatnote
- [Module:InfoboxNeue](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/InfoboxNeue)
- [Module:Manufacturer](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/Manufacturer)
- [Module:Tabber](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/Tabber)
- [Module:Translate](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/Translate)
- [Module:VehicleHardpoint](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/VehicleHardpoint)

## Installation
1. Create `Module:Vehicle/data.json` with the content found in `data.json` on your wiki 
2. Create `Module:Vehicle/config.json` with the content found in `config.json` on your wiki 
3. Create `Module:Vehicle/i18n.json` with the content found in `i18n.json` on your wiki
4. Create `Module:Vehicle`

## Configuration
All configuration of this module is handled in `config.json`.

### `api_locale`
Locale the api should return. If set to null, all languages are returned. Allowed values are 'de_DE' and 'en_EN

### `smw_multilingual_text`
If this flag is set to true, a language suffix is added to the data that is saved to SMW.

### `module_lang`
Manually select the language from the `.tab` page. Also overrides the language suffix that is added to SMW (if active).  
If left empty, the language is guessed based on the content language.

### `set_categories`
Whether the module should automatically set categories.

### `placeholder_image`
Placeholder image to use if no image was found

### `name_suffixes`
A list of suffix to remove from page title

### `role_suffixes`
A list of suffix to remove from role of the vehicles. It is used in short description.
