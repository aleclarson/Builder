
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
Tracer = require "tracer"
isType = require "isType"
define = require "define"
Super = require "Super"
bind = require "bind"
sync = require "sync"

injected = require "./injectable"

# The base instance in the inheritance chain
# must use this type's prototype with 'Object.create'.
instanceType = null
instanceID = null

Builder = NamedFunction "Builder", (name) ->
  assertType name, String if name?

  phases =
    init: []
    willBuild: []
    didBuild: []

  self = Object.create Builder.prototype,
    _name: {value: name}
    _kind: {value: no, writable: yes}
    _phases: {value: phases}

  isDev and
  self.didBuild initTypeCount

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

    @_kind = Object if @_kind is no

    createInstance = (args) ->
      func.apply null, args

    isDev and createInstance = bind.toString func, createInstance
    frozen.define this, "_createInstance", {value: createInstance}
    return

  trace: ->
    isDev and @_phases.init.push ->
      mutable.define this, "__stack", value: Error()
    return

  initInstance: (func) ->
    assertType func, Function

    initInstance = (args) ->
      func.apply this, args

    isDev and initInstance = bind.toString func, initInstance
    @_phases.init.push initInstance
    return

  defineFunction: (func) ->
    assertType func, Function
    @_kind = Function
    @_createInstance = ->
      self = -> func.apply self, arguments
      isDev and self.toString = -> func.toString()
      return self
    return

  defineValues: (values) ->
    values = ValueMapper {values, mutable: yes}
    @_phases.init.push (args) ->
      values.define this, args
    return

  defineFrozenValues: (values) ->
    values = ValueMapper {values, frozen: yes}
    @_phases.init.push (args) ->
      values.define this, args
    return

  defineReactiveValues: (values) ->
    values = ValueMapper {values, reactive: yes}
    @_phases.init.push (args) ->
      values.define this, args
    return

  defineEvents: (eventConfigs) ->
    assertType eventConfigs, Object

    Event = injected.get "Event"
    unless Event instanceof Function
      throw Error "'defineEvents' requires an injected 'Event' constructor!"

    @_phases.init.push ->
      events = @__events or Object.create null

      self = this
      sync.each eventConfigs, (argTypes, key) ->
        event = Event()
        events[key] = ->
          isDev and argTypes and validateArgs arguments, argTypes
          event.emit.apply null, arguments
          return
        frozen.define self, key, {value: event.listenable}
        return

      @__events or
      frozen.define this, "__events", {value: events}
      return
    return

  defineListeners: (createListeners) ->
    assertType createListeners, Function

    Event = injected.get "Event"
    unless Event instanceof Function
      throw Error "'defineListeners' requires an injected 'Event' constructor!"

    @_phases.init.push (args) ->
      listeners = @__listeners or []
      onAttach = Event
        .didAttach (listener) -> listeners.push listener.start()
        .start()

      createListeners.apply this, args
      onAttach.detach()

      @__listeners or
      frozen.define this, "__listeners", {value: listeners}
      return
    return

  defineProperties: (props) ->

    assertType props, Object

    props = sync.map props, (prop, key) ->
      assertType prop, Object, key
      return Property prop

    @_phases.init.push ->
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
      for key, get of getters
        assertType get, Function, key
        frozen.define prototype, key, {get}
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
    @_phases.willBuild.push func
    return

  didBuild: (func) ->
    assertType func, Function
    @_phases.didBuild.push func
    return

  construct: ->
    @build().apply null, arguments

  build: ->
    applyChain @_phases.willBuild, this
    type = @_createType()
    setKind type, @_kind
    applyChain @_phases.didBuild, null, [type]
    return type

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
    defaultKind = @_defaultKind or Object

    if @_kind is no
      @_kind = defaultKind

    kind = @_kind
    createInstance = @_createInstance

    unless createInstance

      if kind is defaultKind
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
    instPhases = @_phases.init
    return buildInstance = (type, args) ->

      if not instanceType
        instanceType = type
        isDev and instanceID = type.__count++

      instance = createInstance.call null, args

      if instanceType

        isDev and
        frozen.define instance, "__name",
          value: instanceType.getName() + "_" + instanceID

        instanceType = null
        isDev and instanceID = null

      applyChain instPhases, instance, [ args ]

      return instance

#
# Helpers
#

if isDev

  initTypeCount = (type) ->
    mutable.define type, "__count", {value: 0}

  validateArgs = (args, argTypes) ->
    argNames = Object.keys argTypes
    for name, index in argNames
      assertType args[index], argTypes[name], name
    return

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
