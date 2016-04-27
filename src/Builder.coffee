
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

module.exports =
Builder = NamedFunction "Builder", ->
  self = setType {}, Builder
  Builder.props.define self
  return self

Builder.props = Property.Map

  _cachedBuild: null

  _kind: value: Object

  _willCreate: value: emptyFunction

  _createInstance: value: -> {}

  _didCreate: value: (type) -> setType this, type

  _phases: ->
    build: []
    initType: []
    initInstance: []

define Builder.prototype,

  build: ->

    if @_cachedBuild
      return @_cachedBuild

    if @_phases.build.length
      for phase in @_phases.build
        phase.call this

    transformArgs = @__createArgTransformer()
    constructType = @__createConstructor()

    type = @__createType ->
      constructType type, transformArgs arguments

    @__initType type

    @_cachedBuild = type
    return type

  addMixins: (mixins) ->
    assertType mixins, Array
    for mixin in mixins
      mixin this
    return

  createInstance: (createInstance) ->
    assertType createInstance, Function
    @_createInstance = (args) ->
      createInstance.apply null, args
    return

  init: (init) ->
    assertType init, Function
    @_phases.initInstance.push (args) ->
      init.apply this, args
    return

# This allows for defining values (a) with one function that returns
# a property map or (b) with a property map of constant values & value creators.
createValueDefiner = (options) -> (createValues) ->

  prop = Property options

  if isType createValues, Function
    @_phases.initInstance.push (args) ->
      values = createValues.apply this, args
      assertType values, Object
      for key, value of values
        prop.define this, key, value
      return
    return

  assertType createValues, Object
  @_phases.initInstance.push (args) ->
    for key, value of createValues
      if isType value, Function
        if value.length
          prop.define this, key, value.apply this, args
        else prop.define this, key, value.call this
      else prop.define this, key, value
    return
  return

define Builder.prototype,

  defineValues: createValueDefiner { needsValue: yes }

  defineFrozenValues: createValueDefiner { frozen: yes, needsValue: yes }

  defineReactiveValues: createValueDefiner { reactive: yes, needsValue: yes }

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, Property

    @_phases.initInstance.push ->
      for key, prop of props
        prop.define this, key
      return
    return

  defineMethods: (methods) ->

    assertType methods, Object

    props = sync.map methods, (value, key) ->
      assertType value, Function, key
      Property { value }

    @_phases.initType.push (type) ->
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

    @_phases.initType.push (type) ->
      for key, prop of props
        prop.define type, key
      return
    return

  bindMethods: (keys) ->
    assert (isType keys, ArrayOf String), "'bindMethods' must be passed an array of strings!"
    @_phases.initInstance.push ->
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

    @_phases.initInstance.push ->
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

    @_phases.initInstance.push ->
      for key, prop of props
        prop.define this, key
      return
    return

define Builder.prototype,

  __createArgTransformer: ->
    emptyFunction.thatReturnsArgument

  __createConstructor: ->

    willCreate = @_willCreate
    createInstance = @_createInstance
    initInstance = @__createInitializer()
    didCreate = @_didCreate

    return (type, args) ->
      willCreate.call null, type, args
      self = createInstance.call null, args
      didCreate.call self, type, args
      initInstance self, args
      return self

  __createInitializer: ->

    phases = @_phases.initInstance

    if phases.length is 0
      return emptyFunction

    return (self, args) ->
      for phase in phases
        phase.call self, args
      return

  __createType: (type) ->
    setKind type, @_kind
    return type

  __initType: (type) ->
    phases = @_phases.initType
    define type, "_builder", this if isDev
    if phases.length
      for phase in phases
        phase.call null, type
    return
