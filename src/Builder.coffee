
require "isDev"

{ mutable, frozen } = Property = require "Property"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
ValueMapper = require "ValueMapper"
PureObject = require "PureObject"
applyChain = require "applyChain"
assertType = require "assertType"
wrapValue = require "wrapValue"
inArray = require "in-array"
setType = require "setType"
setKind = require "setKind"
ArrayOf = require "ArrayOf"
Tracer = require "tracer"
isType = require "isType"
define = require "define"
Super = require "Super"
bind = require "bind"
sync = require "sync"

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

module.exports = Builder

builderProps = Property.Map

  _name: null

  _kind: no

  _defaultKind: -> Object

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
  forbiddenKinds = [
    String
    Boolean
    Number
    Array
    Symbol
    Date
    RegExp
  ]

define Builder,

  # The type of the instance that is currently being initialized.
  building: get: ->
    return instanceType

define Builder.prototype,

  # NOTE: If the inherited type requires the 'new' keyword
  #       to be used, you must call 'createInstance' manually!
  inherits: (kind) ->

    if @_kind isnt no
      throw Error "'kind' is already defined!"

    if inArray forbiddenKinds, kind
      throw Error "Cannot inherit from '#{kind.name}'!"

    unless (kind instanceof Function) or (kind is null)
      throw Error "'kind' must be a kind of Function (or null)!"

    @_kind = kind
    return

  createInstance: (func) ->

    assertType func, Function

    if @_createInstance
      throw Error "'createInstance' has already been called!"

    if @_kind is no
      throw Error "Must call 'inherits' before 'createInstance'!"

    @_createInstance = bind.toString func, (args) -> func.apply null, args
    return

  trace: ->
    define this, "_shouldTrace", { value: yes }
    return

  initInstance: (func) ->
    assertType func, Function
    @_initInstance.push (args) ->
      func.apply this, args
    return

  defineValues: (values) ->
    values = ValueMapper { values, mutable: yes }
    @_initInstance.push (args) ->
      values.define this, args
    return

  defineFrozenValues: (values) ->
    values = ValueMapper { values, frozen: yes }
    @_initInstance.push (args) ->
      values.define this, args
    return

  defineReactiveValues: (values) ->
    values = ValueMapper { values, reactive: yes }
    @_initInstance.push (args) ->
      values.define this, args
    return

  defineEvents: (events) ->

    assertType events, Object

    EventMap = require("./inject/EventMap").get()
    unless EventMap instanceof Function
      throw Error "Must inject an 'EventMap' constructor before calling 'defineEvents'!"

    kind = @_kind
    if @__hasEvents or (kind and kind::__hasEvents)

      @_initInstance.push ->
        @_events._addEvents events

    else

      @_didBuild.push (type) ->
        frozen.define type.prototype, "__hasEvents", { value: yes }

      @_initInstance.push ->
        frozen.define this, "_events", { value: EventMap events }

    @__hasEvents or
    frozen.define this, "__hasEvents", { value: yes }

    @_didBuild.push (type) ->
      sync.keys events, (eventName) ->
        frozen.define type.prototype, eventName,
          value: (maxCalls, onNotify) ->
            @_events eventName, maxCalls, onNotify

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
    @_didBuild.push (type) ->
      for key, prop of props
        prop = { value: prop } if not isType prop, Object
        prop.frozen = yes unless prop.set or prop.writable
        define type.prototype, key, prop
      return
    return

  defineMethods: (methods) ->

    assertType methods, Object

    isDev and @_assertUniqueMethodNames methods

    @_didBuild.push (type) ->
      for key, method of methods
        mutable.define type.prototype, key, { value: method }
      return
    return

  overrideMethods: (methods) ->

    assertType methods, Object

    if @_kind is no
      throw Error "Must call 'inherits' before 'overrideMethods'!"

    hasInherited = @_inheritMethods methods

    @_didBuild.push (type) ->
      hasInherited and Super.augment type
      for key, method of methods
        mutable.define type.prototype, key, { value: method }
      return
    return

  # TODO: Throw if method name already exists.
  defineHooks: (hooks) ->
    assertType hooks, Object
    name = if @_name then @_name + "::" else ""
    @_didBuild.push (type) ->
      for key, defaultValue of hooks
        if defaultValue instanceof Function
          value = defaultValue
        else if isDev
          value = -> throw Error "Must override '#{name + key}'!"
        else
          value = emptyFunction
        type.prototype[key] = value
      return
    return

  defineBoundMethods: (methods) ->
    assertType methods, Object
    @_initInstance.unshift ->
      for key, method of methods
        assertType method, Function, key
        this[key] = bind.func method, this
      return
    return

  defineGetters: (getters) ->
    assertType getters, Object
    @_didBuild.push ({ prototype }) ->
      for key, getter of getters
        frozen.define prototype, key, { get: getter }
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
    setKind type, @_kind
    isDev and frozen.define type, "_builder", { value: this }
    applyChain @_didBuild, null, [ type ]
    return @_cachedBuild = type

  _createType: ->
    name = @_name or ""
    createArguments = @__buildArgumentCreator()
    createInstance = @__buildInstanceCreator()
    type = NamedFunction name, -> createInstance type, createArguments arguments
    return type

  _getBaseCreator: ->

    if @_kind is no
      @_kind = @_defaultKind

    kind = @_kind
    createInstance = @_createInstance

    unless createInstance

      if kind is @_defaultKind
        return @_defaultBaseCreator

      if kind is null
        createInstance = PureObject.create
      else
        createInstance = (args) ->
          kind.apply null, args

    return (args) ->
      instance = createInstance.call null, args
      instanceType and setType instance, instanceType
      return instance

  _defaultBaseCreator: ->
    Object.create instanceType.prototype

  _assertUniqueMethodNames: (methods) ->
    prefix = if @_name then @_name + "::" else ""
    for key, method of methods
      assertType method, Function, prefix + key
      continue unless @_kind
      continue unless inherited = Super.findInherited @_kind, key
      throw Error "Inherited methods cannot be redefined: '#{prefix + key}'\n\n" +
                  "Call 'overrideMethods' to explicitly override!"
    return

  _inheritMethods: (methods) ->

    prefix = if @_name then @_name + "::" else ""

    hasInherited = no
    for key, method of methods
      assertType method, Function, prefix + key

      inherited = Super.findInherited @_kind, key

      if not inherited
        throw Error "Cannot find method to override for: '#{prefix + key}'!"

      if not Super.regex.test method.toString()
        continue

      hasInherited = yes
      methods[key] = Super inherited, method

    return hasInherited

  # Returns the function responsible for transforming and
  # validating the arguments passed to the constructor.
  __buildArgumentCreator: ->
    emptyFunction.thatReturnsArgument

  # Returns the function responsible for initializing
  # each new instance's properties and any other work
  # that should be done before the constructor returns.
  __buildInstanceCreator: ->
    createInstance = @_getBaseCreator()
    initInstance = @_initInstance
    shouldTrace = @_shouldTrace
    return constructor = (type, args) ->

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

      if isDev and shouldTrace

        if not instance._tracers
          frozen.define instance, "_tracers",
            value: Object.create null

        instance._tracers.init = Tracer @_name + "()"

      applyChain initInstance, instance, [ args ]

      return instance
