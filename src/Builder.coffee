
require "isDev"

{ Null
  ArrayOf
  isType
  setType
  setKind
  assert
  assertType
  validateTypes } = require "type-utils"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
Property = require "Property"
define = require "define"
sync = require "sync"

ValueDefiner = require "./ValueDefiner"

createObject = -> {}

module.exports =
Builder = NamedFunction "Builder", ->

  self = setType {}, Builder

  Builder.props.define self

  return self

Builder.props = Property.Map

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

  createInstance: (createInstance) ->

    assertType createInstance, Function
    assert not @_createInstance, "'createInstance' is already defined!"

    @_createInstance = (args) ->
      createInstance.apply null, args

    return

  defineValues: ValueDefiner
    needsValue: yes

  defineFrozenValues: ValueDefiner
    needsValue: yes
    frozen: yes

  defineReactiveValues: ValueDefiner
    needsValue: yes
    reactive: yes

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, Property

    @_initInstance ->
      for key, prop of props
        prop.define this, key
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
      sync.each keys, (key) =>
        method = this[key]
        assertType method, Function, key
        this[key] = => method.apply this, arguments
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
    constructType = @__createConstructor()

    type = @__createType ->
      constructType type, transformArgs arguments

    define type, "_builder", this if isDev

    @_executePhase "didBuild", null, [ type ]

    @_cachedBuild = type

    return type

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

  __createArgTransformer: ->
    emptyFunction.thatReturnsArgument

  __createConstructor: ->

    willCreate = @_createPhaseExecutor "willCreate"
    createInstance = @_createInstance
    didCreate = @_createPhaseExecutor "didCreate"
    initInstance = @_createPhaseExecutor "initInstance"

    return (type, args) ->
      willCreate null, arguments
      self = createInstance.call null, args
      didCreate self, arguments
      initInstance self, [ args ]
      return self

  __createType: (type) ->
    setKind type, @_kind
    return type
