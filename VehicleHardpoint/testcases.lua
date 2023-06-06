-- Unit tests for [[Module:VehicleHardpoint]]
local module = require( 'Module:VehicleHardpoint' )
local ScribuntoUnit = require( 'Module:ScribuntoUnit' )
local suite = ScribuntoUnit:new()


--- module.parseRule tests
function suite:testSimpleEqRuleTrue()
    local rule = [[
        [ "sub_type:FixedThruster" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( true, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testSimpleEqRuleFalse()
    local rule = [[
        [ "sub_type:FixedThruster" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FooBar',
    }

    self:assertEquals( false, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testSimpleMatchRuleTrue()
    local rule = [[
        [ "sub_type:match:Fixed.*" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( true, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testSimpleMatchRuleFalse()
    local rule = [[
        [ "sub_type:match:^StartFixed.+" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( false, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testSimpleAndEqRuleTrue()
    local rule = [[
        [ "sub_type:FixedThruster", "and", "name:vtol" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
        name = 'vtol'
    }

    self:assertEquals( true, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testSimpleAndEqRuleFalse()
    local rule = [[
        [ "sub_type:FixedThruster", "and", "name:vtol" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
        name = 'FooBar'
    }

    self:assertEquals( false, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testNestedRuleTrue()
    local rule = [[
          [
            [ "sub_type:CountermeasureLauncher", "or", "sub_type:UNDEFINED" ],
            "and",
            [
              [ "class_name:find:decoy" ],
              "or",
              [ "class_name:find:flare" ]
            ]
          ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'CountermeasureLauncher',
        class_name = 'DecoyLauncher'
    }

    self:assertEquals( true, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testNestedRuleTrue2()
    local rule = [[
          [
            [ "sub_type:CountermeasureLauncher", "or", "sub_type:UNDEFINED" ],
            "and",
            [
              [ "class_name:find:decoy" ],
              "or",
              [ "class_name:find:flare" ]
            ]
          ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'CountermeasureLauncher',
        class_name = 'FlareLauncher'
    }

    self:assertEquals( true, module.parseRule( rule, hardpoint ) )
end


--- module.parseRule tests
function suite:testNestedRuleFalse()
    local rule = [[
          [
            [ "sub_type:CountermeasureLauncher", "or", "sub_type:UNDEFINED" ],
            "and",
            [
              [ "class_name:find:decoy" ],
              "or",
              [ "class_name:find:flare" ]
            ]
          ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'CountermeasureLauncher',
        class_name = 'FooLauncher'
    }

    self:assertEquals( false, module.parseRule( rule, hardpoint ) )
end



return suite
