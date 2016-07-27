
# This allows for defining values with:
#   - A function that returns a property map
#   - A property map of constant values & value creators

NamedFunction = require "NamedFunction"
assertType = require "assertType"
Property = require "Property"
isType = require "isType"

module.exports = NamedFunction "PropertyMapper", (options) -> (values) ->

  prop = Property options

  if isType values, Function
    @_initInstance.push (args) ->
      instValues = values.apply this, args
      assertType instValues, Object
      for key, value of instValues
        prop.define this, key, { value }
      return
    return

  assertType values, Object
  @_initInstance.push (args) ->
    for key, value of values
      if isType value, Function
        if value.length
          value = value.apply this, args
        else value = value.call this
      prop.define this, key, { value }
    return
  return
