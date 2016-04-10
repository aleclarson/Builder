
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
isObject = require "isObject"
define = require "define"
isDev = require "isDev"
sync = require "sync"

module.exports =
Builder = NamedFunction "Builder", ->

  self = setType {}, Builder

  define self, { enumerable: no },
    _kind: Object
    _typePhases: []
    _argPhases: []
    _getCacheID: null
    _willCreate: emptyFunction
    _createInstance: createObjectLiteral
    _initPhases: []
    _didCreate: emptyFunction

  return self

define Builder.prototype,

  createInstance: (createInstance) ->
    assertType createInstance, Function
    @_createInstance = (args) ->
      createInstance.apply null, args
    return

  fromCache: (getCacheID) ->
    assertType getCacheID, Function
    @_getCacheID = getCacheID
    @_typePhases.push (type) ->
      type.cache = Object.create null
    return

  createArguments: (createArguments) ->
    assertType createArguments, Function
    @_argPhases.push createArguments
    return

  defineProperties: (props) ->
    assertType props, Object
    @_initPhases.push ->
      for key, prop of props
        if isDev and (prop.enumerable is undefined)
          prop.enumerable = isEnumerable key
        define this, key, prop
      return
    return

  definePrototype: (prototype) ->
    assertType prototype, Object
    @_typePhases.push (type) ->
      for key, value of prototype
        if isEnumerable key then type.prototype[key] = value
        else define type.prototype, key, { value, enumerable: no }
      return
    return

  defineStatics: (statics) ->
    assertType statics, Object
    @_typePhases.push (type) ->
      for key, prop of statics
        assertType prop, Object, "statics." + key
        if isDev and (prop.enumerable is undefined)
          prop.enumerable = isEnumerable key
        define type, key, prop
      return
    return

  createValues: (createValues) ->
    assertType createValues, Function
    @_initPhases.push (args) ->
      values = createValues.apply this, args
      assert (isObject values), "'createValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        if isEnumerable key then this[key] = value
        else define this, key, { value, enumerable: no }
      return
    return

  createFrozenValues: (createFrozenValues) ->
    assertType createFrozenValues, Function
    @_initPhases.push (args) ->
      values = createFrozenValues.apply this, args
      assert (isObject values), "'createFrozenValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        if isDev then define this, key, { value, frozen: yes, enumerable: isEnumerable key }
        else this[key] = value
      return
    return

  createReactiveValues: (createReactiveValues) ->
    assertType createReactiveValues, Function
    @_initPhases.push (args) ->
      values = createReactiveValues.apply this, args
      assert (isObject values), "'createReactiveValues' must return an Object!"
      for key, value of values
        continue if value is undefined
        define this, key, { value, reactive: yes, enumerable: isEnumerable key }
      return
    return

  bindMethods: (keys) ->
    assert (isType keys, ArrayOf String), "'bindMethods' must be passed an array of strings!"
    @_initPhases.push ->
      sync.each keys, (key) =>
        value = this[key]
        assertType value, Function, { key: @constructor.name + "." + key, instance: this }
        this[key] = => value.apply this, arguments
    return

  exposeGetters: (keys) ->
    assert (isType keys, ArrayOf String), "'exposeGetters' must be passed an array of strings!"
    @_initPhases.push ->
      sync.each keys, (key) =>
        internalKey = "_" + key
        define this, key, get: -> this[internalKey]
    return

  addMixins: (mixins) ->
    assertType mixins, Array
    for mixin in mixins
      mixin.call this
    return

  init: (init) ->
    assertType init, Function
    @_initPhases.push (args) ->
      init.apply this, args
    return

  build: ->

    initArgs = @__initArgs @_argPhases
    getCacheId = @_getCacheID
    willCreate = @_willCreate
    createInstance = @_createInstance
    initInstance = @__initInstance @_initPhases
    didCreate = @_didCreate

    type = @__createType ->

      # Initialize the arguments.
      args = initArgs arguments

      # Use an existing instance if possible.
      if getCacheId
        self = getCacheId.apply null, args
        return self if self isnt undefined

      # Allow custom logic before instance creation.
      willCreate.call null, type, args

      # Construct the base object.
      self = createInstance.apply null, args

      # Initialize the instance.
      initInstance self, args

      # Allow custom logic after instance creation.
      didCreate.call self, type, args

      return self

    @__initType type, @_typePhases

    return type

define Builder.prototype, { enumerable: no },

  __initArgs: (argPhases) ->

    if argPhases.length is 0
      return emptyFunction.thatReturnsArgument

    return (initialArgs) ->
      args = [] # The 'initialArgs' should not be leaked.
      args.push arg for arg in initialArgs
      for runPhase in argPhases
        args = runPhase args
      return args

  __initInstance: (initPhases) ->

    if initPhases.length is 0
      return emptyFunction

    return (self, args) ->
      for runPhase in initPhases
        runPhase.apply self, args
      return

  __createType: (type) ->
    setKind type, @_kind
    return type

  __initType: (type, typePhases) ->
    return if typePhases.length is 0
    runPhase type for runPhase in typePhases
    return

#
# Helpers
#

if isDev then isEnumerable = (key) -> key[0] isnt "_"
else isEnumerable = emptyFunction.thatReturnsTrue

createObjectLiteral = -> {}

mergeDefaults = (options, optionDefaults) ->
  for key, defaultValue of optionDefaults
    if isObject defaultValue
      options[key] = {} if options[key] is undefined
      options[key] = mergeDefaults options[key], defaultValue
    else if options[key] is undefined
      options[key] = defaultValue
  return
