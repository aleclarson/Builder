
# This allows for defining values with:
#   - A function that returns a property map
#   - A property map of constant values & value creators

NamedFunction = require "NamedFunction"
assertType = require "assertType"
Property = require "Property"
isType = require "isType"

module.exports = NamedFunction "PropertyMapper", (options) -> (createValues) ->

  prop = Property options

  if isType createValues, Function
    @_initInstance.push (args) ->
      values = createValues.apply this, args
      assertType values, Object
      for key, value of values
        prop.define this, key, value
      return
    return

  assertType createValues, Object
  @_initInstance.push (args) ->
    for key, value of createValues
      if isType value, Function
        if value.length
          prop.define this, key, value.apply this, args
        else prop.define this, key, value.call this
      else prop.define this, key, value
    return
  return
