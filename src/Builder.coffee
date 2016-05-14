
require "isDev"

{ throwFailure } = require "failure"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
assertType = require "assertType"
bindMethod = require "bindMethod"
Property = require "Property"
ArrayOf = require "ArrayOf"
setType = require "setType"
setKind = require "setKind"
Tracer = require "tracer"
isType = require "isType"
define = require "define"
assert = require "assert"
guard = require "guard"
sync = require "sync"

PropertyMapper = require "./PropertyMapper"

createObject = -> {}

module.exports =
Builder = NamedFunction "Builder", ->

  self = setType {}, Builder

  Builder.props.define self

  return self

Builder.props = Property.Map

  _traceInit: -> Tracer "Builder", skip: 2

  _cachedBuild: null

  _kind: null

  _createInstance: null

  _phases: ->
    willBuild: []
    didBuild: []
    willCreate: []
    didCreate: []
    initInstance: []

define Builder.prototype,

  defineValues: PropertyMapper { needsValue: yes }

  defineFrozenValues: PropertyMapper { frozen: yes, needsValue: yes }

  defineReactiveValues: PropertyMapper { reactive: yes, needsValue: yes }

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, Property

    @_initInstance ->
      for key, prop of props
        prop.define this, key
      return
    return

  definePrototype: (props) ->

    assertType props, Object

    props = sync.map props, (prop) ->
      assertType prop, Object
      assertType prop.get, Function
      assert not isType prop.set, Function
      return Property prop

    @didBuild (type) ->
      for key, prop of props
        prop.define type.prototype, key
      return
    return

  defineMethods: (methods) ->

    assertType methods, Object

    props = sync.map methods, (value, key) ->
      assertType value, Function, key
      Property { value }

    @didBuild (type) ->
      for key, prop of props
        prop.define type.prototype, key
      return
    return

  defineStatics: (statics) ->

    assertType statics, Object

    props = sync.map statics, (options, key) ->

      unless isType options, Object
        options = { value: options }

      Property options

    @didBuild (type) ->
      for key, prop of props
        prop.define type, key
      return
    return

  bindMethods: (keys) ->
    assert (isType keys, ArrayOf String), "'bindMethods' must be passed an array of strings!"
    @_initInstance ->
      for key in keys
        this[key] = bindMethod this, key
      return
    return

  exposeGetters: (keys) ->

    assertType keys, Array

    props = {}
    sync.each keys, (key) ->
      internalKey = "_" + key
      props[key] = Property
        get: -> this[internalKey]
        enumerable: yes

    @_initInstance ->
      for key, prop of props
        prop.define this, key
      return
    return

  exposeLazyGetters: (keys) ->

    assertType keys, Array

    props = {}
    sync.each keys, (key) ->
      internalKey = "_" + key
      props[key] = Property
        get: -> this[internalKey].get()
        enumerable: yes

    @_initInstance ->
      for key, prop of props
        prop.define this, key
      return
    return

  createInstance: (createInstance) ->

    assertType createInstance, Function
    assert not @_createInstance, "'createInstance' is already defined!"

    @_createInstance = (args) ->
      createInstance.apply null, args

    return

  initInstance: (init) ->
    assertType init, Function
    @_initInstance (args) ->
      init.apply this, args
    return

  willCreate: (fn) ->
    assertType fn, Function
    @_phases.willCreate.push fn
    return

  didCreate: (fn) ->
    assertType fn, Function
    @_phases.didCreate.push fn
    return

  addMixins: (mixins) ->
    assertType mixins, Array
    for mixin in mixins
      mixin this
    return

  willBuild: (fn) ->
    assertType fn, Function
    @_phases.willBuild.push fn
    return

  didBuild: (fn) ->
    assertType fn, Function
    @_phases.didBuild.push fn
    return

  build: ->

    if @_cachedBuild
      return @_cachedBuild

    @_executePhase "willBuild", this

    unless @_createInstance
      @_kind = Object
      @_createInstance = createObject

    transformArgs = @__createArgTransformer()
    constructType = @__wrapConstructor @__createConstructor @_createInstance

    type = @__createType ->
      constructType type, transformArgs arguments

    define type, "_builder", this if isDev

    @_executePhase "didBuild", null, [ type ]

    @_cachedBuild = type

    return type

  construct: ->
    @build().apply null, arguments

  _initInstance: (init) ->
    assertType init, Function
    @_phases.initInstance.push init
    return

  _executePhase: (phaseName, scope, args) ->
    callbacks = @_phases[phaseName]
    return unless callbacks.length
    @_executeCallbacks callbacks, scope, args

  _executeCallbacks: (callbacks, scope, args) ->
    if args
      for callback in callbacks
        callback.apply scope, args
    else
      for callback in callbacks
        callback.call scope
    return

  _createPhaseExecutor: (phaseName) ->
    callbacks = @_phases[phaseName]
    return emptyFunction unless callbacks.length
    @_executeCallbacks.bind null, callbacks

  __createType: (type) ->
    setKind type, @_kind
    return type

  __createArgTransformer: ->
    emptyFunction.thatReturnsArgument

  __wrapConstructor: (createInstance) ->

    willCreate = @_createPhaseExecutor "willCreate"
    didCreate = @_createPhaseExecutor "didCreate"
    initInstance = @_createPhaseExecutor "initInstance"

    return (type, args) ->
      tracer = Tracer "construct()"
      guard ->
        willCreate null, arguments
        self = createInstance type, args
        didCreate self, arguments
        initInstance self, [ args ]
        return self
      .fail (error) ->
        stack = tracer()
        throwFailure error, { stack }

  __createConstructor: (createInstance) ->
    return (type, args) ->
      instance = createInstance.call null, args
      setType instance, type
