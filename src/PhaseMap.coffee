
NamedFunction = require "NamedFunction"
assertType = require "assertType"
has = require "has"

PhaseMap = NamedFunction "PhaseMap", ->
  Object.create PhaseMap.prototype,
    _map: {value: Object.create null}

prototype =

  has: (phase) ->
    has @_map, phase

  get: (phase) ->
    assertType phase, String
    @_map[phase] or @_map[phase] = []

  push: (phase, callback) ->
    assertType phase, String
    assertType callback, Function
    @get(phase).push callback

  unshift: (phase, callback) ->
    assertType phase, String
    assertType callback, Function
    @get(phase).unshift callback

  apply: (phase, context, args) ->
    assertType phase, String
    if callbacks = @_map[phase]
      index = -1
      while ++index < callbacks.length
        callbacks[index].apply context, args
    return

Object.assign PhaseMap.prototype, prototype
module.exports = PhaseMap
