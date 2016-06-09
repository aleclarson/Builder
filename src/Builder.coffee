
require "isDev"

{ throwFailure } = require "failure"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
PureObject = require "PureObject"
applyChain = require "applyChain"
assertType = require "assertType"
bindMethod = require "bindMethod"
wrapValue = require "wrapValue"
Property = require "Property"
inArray = require "in-array"
setType = require "setType"
setKind = require "setKind"
ArrayOf = require "ArrayOf"
Tracer = require "tracer"
isType = require "isType"
define = require "define"
assert = require "assert"
Super = require "Super"
sync = require "sync"

PropertyMapper = require "./PropertyMapper"

mutable = Property()
frozen = Property { frozen: yes }

module.exports =
Builder = NamedFunction "Builder", (name, func) ->

  self = Object.create Builder.prototype

  builderProps.define self

  if name
    assertType name, String
    self._name = name

  if func
    assertType func, Function
    self._kind = Function
    self._createInstance = ->
      instance = -> func.apply instance, arguments
      if isDev then instance.toString = -> func.toString()
      return instance

  if isDev
    self._didBuild.push initTypeCount
    Object.defineProperty self, "_tracer",
      value: Tracer "Builder.construct()", { skip: 2 }

  return self

builderProps = Property.Map

  _name: null

  _kind: null

  _createInstance: null

  _initInstance: -> []

  _willBuild: -> []

  _didBuild: -> []

  _cachedBuild: null

# The base instance in the inheritance chain
# must use this type's prototype with 'Object.create'.
instanceType = null

if isDev

  # The base instance has its '__id' and '__name'
  # created by keeping a unique identifier for each type.
  instanceID = null
  initTypeCount = (type) ->
    type.count = 0

  instanceProps = Property.Map
    __id: -> instanceID
    __name: get: -> @constructor.getName() + "_" + @__id

  # These types cannot be inherited from!
  forbiddenKinds = [ String, Boolean, Number, Array, Symbol, Date, RegExp ]

define Builder,

  # The type of the instance that is currently being initialized.
  building: get: ->
    return instanceType

define Builder.prototype,

  # NOTE: If the inherited type requires the 'new' keyword
  #       to be used, you must call 'createInstance' manually!
  inherits: (kind) ->

    assert not @_kind, "'kind' is already defined!"
    assert kind isnt Object, "'Cannot explicitly inherit from Object! The default 'kind' is Object, so just dont call 'inherits'!"
    assert kind isnt Function, "Cannot explicitly inherit from Function! Must pass a second argument to the Builder constructor!"
    assert not inArray(forbiddenKinds, kind), -> "Cannot inherit from '#{kind.name}'!"

    if kind isnt null
      assert kind instanceof Function, "'kind' must be a kind of Function (or null)!"

    @_kind = kind

    # Allow types to override the default 'createInstance'.
    @_willBuild.push ->
      @_createInstance ?=
        if kind is null then PureObject.create
        else (args) -> kind.apply null, args
    return

  createInstance: (createInstance) ->

    assertType createInstance, Function
    assert not @_createInstance, "'createInstance' is already defined!"
    assert @_kind, "Must call 'inherits' before 'createInstance'!"

    @_createInstance = (args) ->
      createInstance.apply null, args
    return

  initInstance: (func) ->
    assertType func, Function
    @_initInstance.push (args) ->
      func.apply this, args
    return

  defineValues: PropertyMapper { needsValue: yes }

  defineFrozenValues: PropertyMapper { frozen: yes, needsValue: yes }

  defineReactiveValues: PropertyMapper { reactive: yes, needsValue: yes }

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, (prop, key) ->
      assertType prop, Object, key
      return Property prop

    @_initInstance.push ->
      for key, prop of props
        prop.define this, key
      return
    return

  definePrototype: (props) ->

    assertType props, Object

    props = sync.map props, (prop) ->
      if not isType prop, Object
        prop = { value: prop }
      prop.frozen = yes
      return Property prop

    @_didBuild.push (type) ->
      for key, prop of props
        prop.define type.prototype, key
      return
    return

  defineMethods: (methods) ->

    assertType methods, Object

    prefix = if @_name then @_name + "#" else ""

    kind = @_kind
    if isDev
      for key, method of methods
        assertType method, Function, prefix + key
        if kind
          inherited = Super.findInherited kind, key
          assert not inherited, "Inherited methods cannot be redefined: '#{prefix + key}'\n\nCall 'overrideMethods' to explicitly override!"

    @_didBuild.push (type) ->
      for key, method of methods
        mutable.define type.prototype, key, method
      return
    return

  overrideMethods: (methods) ->

    assertType methods, Object

    kind = @_kind
    assert kind, "Must call 'inherits' before 'overrideMethods'!"

    prefix = if @_name then @_name + "#" else ""

    hasInherited = no
    for key, method of methods
      assertType method, Function, prefix + key
      inherited = Super.findInherited kind, key
      assert inherited, "Cannot find method to override for: '#{prefix + key}'!"
      continue if not Super.regex.test method.toString()
      hasInherited = yes
      methods[key] = Super inherited, method

    @_didBuild.push (type) ->
      Super.augment type if hasInherited
      for key, method of methods
        mutable.define type.prototype, key, method
      return
    return

  mustOverride: (keys) ->

    assertType keys, Array
    @_didBuild.push (type) ->
      for key in keys
        mutable.define type.prototype, key, emptyFunction
      return

    return if not isDev
    name = if @_name then @_name + "#" else ""
    @_initInstance.push ->
      for key in keys
        assert this[key] instanceof Function, "Must override '" + name + key + "'!"
      return
    return

  bindMethods: (keys) ->
    assert isType(keys, ArrayOf String), "'bindMethods' must be passed an array of strings!"
    @_initInstance.push ->
      meta = { obj: this } if isDev
      for key in keys
        meta.key = key if isDev
        assertType this[key], Function, meta
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

    @_initInstance.push ->
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

    @_initInstance.push ->
      for key, prop of props
        prop.define this, key
      return
    return

  defineStatics: (statics) ->

    assertType statics, Object

    props = sync.map statics, (options, key) ->
      options = { value: options } if not isType options, Object
      return Property options

    @_didBuild.push (type) ->
      for key, prop of props
        prop.define type, key
      return
    return

  addMixins: (mixins) ->
    assertType mixins, Array, "mixins"
    for mixin, index in mixins
      assertType mixin, Function, "mixins[" + index + "]"
      mixin this
    return

  willBuild: (func) ->
    assertType func, Function
    @_willBuild.push func
    return

  didBuild: (func) ->
    assertType func, Function
    @_didBuild.push func
    return

  construct: ->
    @build().apply null, arguments

  build: ->
    return @_cachedBuild if @_cachedBuild
    applyChain @_willBuild, this
    type = @_createType()
    setKind type, @_kind if @_kind
    frozen.define type, "_builder", this if isDev
    applyChain @_didBuild, null, [ type ]
    return @_cachedBuild = type

  _createType: ->
    name = @_name or ""
    createArguments = @__buildArgumentCreator()
    createInstance = @__buildInstanceCreator()
    return type = NamedFunction name, ->
      createInstance type, createArguments arguments

  # Returns the function resposible for transforming and
  # validating the arguments passed to the constructor.
  __buildArgumentCreator: ->
    emptyFunction.thatReturnsArgument

  # Returns the function responsible for initializing
  # each new instance's properties and any other work
  # that should be done before the constructor returns.
  __buildInstanceCreator: ->

    createInstance = @_createInstance
    createInstance =
      if createInstance
        wrapValue createInstance, @__migrateBaseObject
      else @__createBaseObject

    initInstance = @_initInstance
    return (type, args) ->

      if not instanceType
        instanceType = type
        if isDev
          instanceID = type.count++

      instance = createInstance.call null, args

      if instanceType
        instanceType = null
        if isDev
          instanceProps.define instance
          instanceID = null

      applyChain initInstance, instance, [ args ]

      return instance

  # Sometimes the base object is not created by a
  # Builder; so we have to set the instance type
  # here instead of in '_createBaseObject'.
  __migrateBaseObject: (createInstance) -> (args) ->
    instance = createInstance.call null, args
    setType instance, instanceType if instanceType
    return instance

  # This is where we "associate" a new instance
  # with the prototype of the topmost type
  # in the inheritance chain.
  __createBaseObject: ->
    Object.create instanceType.prototype
