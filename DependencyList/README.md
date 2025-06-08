# Module:DependencyList

This module generates a list of dependencies used by template and module documentation.

## Requirements
- [Semantic MediaWiki](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) + [Semantic Extra Special Properties](https://github.com/SemanticMediaWiki/SemanticExtraSpecialProperties) or [DynamicPageList3](https://www.mediawiki.org/wiki/Extension:DynamicPageList3) + `Module:DPLlua`
- Any other modules listed on https://starcitizen.tools/Module:DependencyList

## Installation
1. Create `Module:DependencyList`
2. Upload all icons from the `SharedIcons/wikimedia` repository
3. Change the message `MediaWiki:scribunto-doc-page-name` to `Module:$1/doc`

### Using with Semantic MediaWiki

When using SMW, [Extension:SemanticExtraSpecialProperties](https://github.com/SemanticMediaWiki/SemanticExtraSpecialProperties) must be installed.

Enable the `Links to` special property in `localSettings.php`:
```php
$sespgEnabledPropertyList[] = '_LINKSTO';
```

Enable Semantic Data on the Module and Template namespaces:
```php
$smwgNamespacesWithSemanticLinks[NS_TEMPLATE] = true;
$smwgNamespacesWithSemanticLinks[828] = true;
```

Set `QUERY_MODE` to `smw` in Lua module

### Using with DynamicPageList3 (DPL3)

Set `QUERY_MODE` to `dpl` in Lua module

## Configuration
All configuration of this module is handled in `config.json`.