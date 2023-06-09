-- Unit tests for [[Module:VehicleHardpoint]]
local module = require( 'Module:VehicleHardpoint' )
local ScribuntoUnit = require( 'Module:ScribuntoUnit' )
local suite = ScribuntoUnit:new()


--- module.evalRule tests
function suite:testSimpleEqRuleTrue()
    local rule = [[
        [ "sub_type:FixedThruster" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( true, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testSimpleEqRuleFalse()
    local rule = [[
        [ "sub_type:FixedThruster" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FooBar',
    }

    self:assertEquals( false, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testSimpleMatchRuleTrue()
    local rule = [[
        [ "sub_type:match:Fixed.*" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( true, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testSimpleMatchRuleFalse()
    local rule = [[
        [ "sub_type:match:^StartFixed.+" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
    }

    self:assertEquals( false, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testSimpleAndEqRuleTrue()
    local rule = [[
        [ "sub_type:FixedThruster", "and", "name:vtol" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
        name = 'vtol'
    }

    self:assertEquals( true, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testSimpleAndEqRuleFalse()
    local rule = [[
        [ "sub_type:FixedThruster", "and", "name:vtol" ]
    ]]
    rule = mw.text.jsonDecode( rule )

    local hardpoint = {
        sub_type = 'FixedThruster',
        name = 'FooBar'
    }

    self:assertEquals( false, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
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

    self:assertEquals( true, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
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

    self:assertEquals( true, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
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

    self:assertEquals( false, module.evalRule( rule, hardpoint ) )
end


--- module.evalRule tests
function suite:testApplyFixVtolThruster()
    local fixes = [[
      [
        {
          "type": [ "ManneuverThruster", "MainThruster" ],
          "modification": [
            {
              "if": [
                [ "sub_type:FixedThruster", "or", "sub_type:UNDEFINED" ],
                "and",
                [ "name:match:vtol" ]
              ],
              "then": "sub_type=VtolThruster"
            },
            {
              "if": [
                [ "sub_type:FixedThruster", "or", "sub_type:UNDEFINED" ],
                "and",
                [ "name:match:retro" ]
              ],
              "then": "sub_type=RetroThruster"
            },
            {
              "if": [
                [ "sub_type:JointThruster", "or", "sub_type:UNDEFINED" ],
                "and",
                [ "name:match:vtol" ]
              ],
              "then": "sub_type=GravLev"
            },
            {
              "if": [ "type:MainThruster" ],
              "then": "sub_type=Main+sub_type"
            }
          ]
        }
      ]
    ]]
    fixes = mw.text.jsonDecode( fixes )

    local hardpoint = {
        type = 'ManneuverThruster',
        sub_type = 'FixedThruster',
        name = 'hardpoint_mav_vtol_thruster'
    }

    module.fixTypes( hardpoint, fixes )

    self:assertEquals( 'VtolThruster', hardpoint.sub_type )
end



return suite
