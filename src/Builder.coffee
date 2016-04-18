
require "isDev"

{ Null
  ArrayOf
  isType
  setType
  setKind
  assert
  assertType
  validateTypes } = require "type-utils"

isEnumerableKey = require "isEnumerableKey"
NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
define = require "define"
sync = require "sync"

defaultValues =
  createInstance: -> {}
  didCreate: (type) -> setType this, type

module.exports =
Builder = NamedFunction "Builder", ->

  self = setType {}, Builder

  define self, { enumerable: no },
    _buildResult: null
    _kind: Object
    _willCreate: emptyFunction
    _createInstance: defaultValues.createInstance
    _didCreate: defaultValues.didCreate
    _phases: value: {
      build: []
      initType: []
      initInstance: []
    }

  return self

define Builder.prototype,

  createInstance: (createInstance) ->
    assertType createInstance, Function
    @_createInstance = (args) ->
      createInstance.apply null, args
    return

  defineProperties: (props) ->
    assertType props, Object
    @_phases.initInstance.push ->
      for key, prop of props
        if isDev and (prop.enumerable is undefined)
          prop.enumerable = isEnumerableKey key
        define this, key, prop
      return
    return

  definePrototype: (prototype) ->
    assertType prototype, Object
    @_phases.initType.push (type) ->
      for key, value of prototype
        if isEnumerableKey key then type.prototype[key] = value
        else define type.prototype, key, { value, enumerable: no }
      return
    return

  defineStatics: (statics) ->
    assertType statics, Object
    @_phases.initType.push (type) ->
      for key, prop of statics
        prop = { value: prop } unless isType prop, Object
        if isDev and (prop.enumerable is undefined)
          prop.enumerable = isEnumerableKey key
        define type, key, prop
      return
    return

  createValues: (createValues) ->
    assertType createValues, Function
    @_phases.initInstance.push (args) ->
      values = createValues.apply this, args
      assert (isType values, Object), "'createValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        if isEnumerableKey key then this[key] = value
        else define this, key, { value, enumerable: no }
      return
    return

  createFrozenValues: (createFrozenValues) ->
    assertType createFrozenValues, Function
    @_phases.initInstance.push (args) ->
      values = createFrozenValues.apply this, args
      assert (isType values, Object), "'createFrozenValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        if isDev then define this, key, { value, frozen: yes, enumerable: isEnumerableKey key }
        else this[key] = value
      return
    return

  createReactiveValues: (createReactiveValues) ->
    assertType createReactiveValues, Function
    @_phases.initInstance.push (args) ->
      values = createReactiveValues.apply this, args
      assert (isType values, Object), "'createReactiveValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        define this, key, { value, reactive: yes, enumerable: isEnumerableKey key }
      return
    return

  bindMethods: (keys) ->
    assert (isType keys, ArrayOf String), "'bindMethods' must be passed an array of strings!"
    @_phases.initInstance.push ->
      sync.each keys, (key) =>
        value = this[key]
        assertType value, Function, { key: @constructor.name + "." + key, instance: this }
        this[key] = => value.apply this, arguments
    return

  exposeGetters: (keys) ->
    assert (isType keys, ArrayOf String), "'exposeGetters' must be passed an array of strings!"
    @_phases.initInstance.push ->
      sync.each keys, (key) =>
        internalKey = "_" + key
        define this, key, get: -> this[internalKey]
    return

  exposeLazyGetters: (keys) ->
    assert (isType keys, ArrayOf String), "'exposeGetters' must be passed an array of strings!"
    @_phases.initInstance.push ->
      sync.each keys, (key) =>
        internalKey = "_" + key
        define this, key, get: -> this[internalKey].get()
    return

  addMixins: (mixins) ->
    assertType mixins, Array
    for mixin in mixins
      mixin this
    return

  init: (init) ->
    assertType init, Function
    @_phases.initInstance.push (args) ->
      init.apply this, args
    return

  build: ->

    if @_buildResult
      return @_buildResult

    if @_phases.build.length
      for phase in @_phases.build
        phase.call this

    transformArgs = @__createArgTransformer()
    constructType = @__createConstructor()

    type = @__createType ->
      constructType type, transformArgs arguments

    @__initType type

    @_buildResult = type
    return type

define Builder.prototype, { enumerable: no },

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
    if phases.length
      for phase in phases
        phase.call null, type
    return
