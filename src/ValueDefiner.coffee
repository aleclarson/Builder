
# This allows for defining values (a) with one function that returns
# a property map or (b) with a property map of constant values & value creators.

{ isType, assertType } = require "type-utils"

NamedFunction = require "NamedFunction"
Property = require "Property"

module.exports =
ValueDefiner = NamedFunction "ValueDefiner", (options) ->

  return (createValues) ->

    prop = Property options

    if isType createValues, Function
      @_initInstance (args) ->
        values = createValues.apply this, args
        assertType values, Object
        for key, value of values
          prop.define this, key, value
        return
      return

    assertType createValues, Object
    @_initInstance (args) ->
      for key, value of createValues
        if isType value, Function
          if value.length
            prop.define this, key, value.apply this, args
          else prop.define this, key, value.call this
        else prop.define this, key, value
      return
    return
