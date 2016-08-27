
require "isDev"

{mutable, frozen} = Property = require "Property"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
ValueMapper = require "ValueMapper"
PureObject = require "PureObject"
assertType = require "assertType"
applyChain = require "applyChain"
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

# The base instance in the inheritance chain
# must use this type's prototype with 'Object.create'.
instanceType = null
instanceID = null

Builder = NamedFunction "Builder", (name, func) ->

  self = Object.create Builder.prototype

  builderProps.define self

  if name
    assertType name, String
    self._name = name

  if func
    assertType func, Function
    self._kind = Function
    if isDev
      self._createInstance = ->
        instance = bind.toString func, ->
          func.apply instance, arguments
    else
      self._createInstance = ->
        instance = -> func.apply instance, arguments

  if isDev
    self.didBuild initTypeCount
    Object.defineProperty self, "_tracer",
      value: Tracer "Builder.construct()", { skip: 2 }

  return self

module.exports = Builder

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

    createInstance = (args) ->
      func.apply null, args

    isDev and createInstance = bind.toString func, createInstance
    @_createInstance = createInstance
    return

  trace: ->
    define this, "_shouldTrace", { value: yes }
    return

  initInstance: (func) ->
    assertType func, Function

    initInstance = (args) ->
      func.apply this, args

    isDev and initInstance = bind.toString func, initInstance
    @_initPhases.push initInstance
    return

  defineValues: (values) ->
    values = ValueMapper { values, mutable: yes }
    @_initPhases.push (args) ->
      values.define this, args
    return

  defineFrozenValues: (values) ->
    values = ValueMapper { values, frozen: yes }
    @_initPhases.push (args) ->
      values.define this, args
    return

  defineReactiveValues: (values) ->
    values = ValueMapper { values, reactive: yes }
    @_initPhases.push (args) ->
      values.define this, args
    return

  defineEvents: (events) ->

    assertType events, Object

    EventMap = require("./inject/EventMap").get()
    unless EventMap instanceof Function
      throw Error "Must inject an 'EventMap' constructor before calling 'defineEvents'!"

    kind = @_kind
    if @__hasEvents or (kind and kind::__hasEvents)

      @_initPhases.push ->
        @_events._addEvents events

    else

      @didBuild (type) ->
        frozen.define type.prototype, "__hasEvents", { value: yes }

      @_initPhases.push ->
        frozen.define this, "_events", { value: EventMap events }

    @__hasEvents or
    frozen.define this, "__hasEvents", { value: yes }

    @didBuild (type) ->
      sync.keys events, (eventName) ->
        frozen.define type.prototype, eventName,
          value: (maxCalls, callback) ->
            @_events eventName, maxCalls, callback

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, (prop, key) ->
      assertType prop, Object, key
      return Property prop

    @_initPhases.push ->
      for key, prop of props
        prop.define this, key
      return
    return

  definePrototype: (props) ->
    assertType props, Object
    @didBuild (type) ->
      for key, prop of props
        prop = { value: prop } if not isType prop, Object
        prop.frozen = yes unless prop.set or prop.writable
        define type.prototype, key, prop
      return
    return

  defineMethods: (methods) ->

    assertType methods, Object

    isDev and @_assertUniqueMethodNames methods

    @didBuild (type) ->
      for key, method of methods
        mutable.define type.prototype, key, { value: method }
      return
    return

  overrideMethods: (methods) ->

    assertType methods, Object

    if @_kind is no
      throw Error "Must call 'inherits' before 'overrideMethods'!"

    hasInherited = @_inheritMethods methods

    @didBuild (type) ->
      hasInherited and Super.augment type
      for key, method of methods
        mutable.define type.prototype, key, { value: method }
      return
    return

  # TODO: Throw if method name already exists.
  defineHooks: (hooks) ->
    assertType hooks, Object
    name = if @_name then @_name + "::" else ""
    @didBuild (type) ->
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
    @didBuild (type) ->
      {prototype} = type
      sync.each methods, (method, key) ->
        define prototype, key, get: ->
          value = bind.func method, this
          frozen.define this, key, {value}
          return value
      return
    return

  defineGetters: (getters) ->
    assertType getters, Object
    @didBuild (type) ->
      {prototype} = type
      for key, getter of getters
        frozen.define prototype, key, { get: getter }
      return
    return

  defineStatics: (statics) ->

    assertType statics, Object

    props = sync.map statics, (options, key) ->
      options = { value: options } if not isType options, Object
      return Property options

    @didBuild (type) ->
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
    @_willBuildPhases.push func
    return

  didBuild: (func) ->
    assertType func, Function
    @_didBuildPhases.push func
    return

  construct: ->
    @build().apply null, arguments

  build: ->
    return @_cachedBuild if @_cachedBuild
    applyChain @_willBuildPhases, this
    type = @_createType()
    setKind type, @_kind
    isDev and frozen.define type, "_builder", {value: this}
    applyChain @_didBuildPhases, null, [type]
    return @_cachedBuild = type

  _createType: ->
    name = @_name or ""
    buildArgs = @__createArgBuilder()
    buildInstance = @__createInstanceBuilder()

    if isDev
      assertType buildArgs, Function
      assertType buildInstance, Function
      return Function(
        "buildArgs",
        "buildInstance",
        "var type;" +
        "return type = function #{name}() {\n" +
        "  return buildInstance(type, buildArgs(arguments));\n" +
        "}"
      ) buildArgs, buildInstance

    type = -> buildInstance type, buildArgs arguments
    type.getName = -> name
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
  __createArgBuilder: ->
    emptyFunction.thatReturnsArgument

  # Returns the function responsible for initializing
  # each new instance's properties and any other work
  # that should be done before the constructor returns.
  __createInstanceBuilder: ->
    createInstance = @_getBaseCreator()
    instPhases = @_initPhases
    shouldTrace = @_shouldTrace
    return buildInstance = (type, args) ->

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

      applyChain instPhases, instance, [ args ]

      return instance

#
# Helpers
#

builderProps = Property.Map

  _name: null

  _kind: no

  _defaultKind: -> Object

  _createInstance: null

  _initPhases: -> []

  _willBuildPhases: -> []

  _didBuildPhases: -> []

  _cachedBuild: null

if isDev

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
