
{frozen, hidden, reactive} = require "Property"
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
Mixin = require "Mixin"
isDev = require "isDev"
bind = require "bind"
sync = require "sync"

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

Builder.Mixin = Mixin.create
  methods: [
    "initInstance"
    "defineValues"
    "defineFrozenValues"
    "defineReactiveValues"
    "defineProperties"
    "definePrototype"
    "defineMethods"
    "overrideMethods"
    "defineHooks"
    "defineBoundMethods"
    "defineGetters"
    "defineStatics"
    "addMixin"
    "addMixins"
    "willBuild"
    "didBuild"
  ]

#
# Public Methods
#

Object.assign Builder.prototype,

  abstract: ->
    # TODO: Throw when attempting to construct an abstract type.

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
    @__didInherit kind
    return

  createInstance: (createInstance) ->

    assertType createInstance, Function

    if @_createInstance
      throw Error "'createInstance' has already been called!"

    @_kind = Object if @_kind is no
    mutable.define this, "_createInstance", {value: createInstance}
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

  defineValues: do ->

    defineValue = (obj, key, value) ->
      if value isnt undefined
        prop = {value, writable: yes}
        prop.enumerable = key.startsWith "_"
        Object.defineProperty obj, key, prop
      return

    return (values) ->
      mapValues = ValueMapper values, defineValue
      @_phases.init.push (args) ->
        mapValues this, args
      return

  defineFrozenValues: do ->

    defineValue = (obj, key, value) ->
      if value isnt undefined
        frozen.define obj, key, {value}
      return

    return (values) ->
      mapValues = ValueMapper values, defineValue
      @_phases.init.push (args) ->
        mapValues this, args
      return

  defineReactiveValues: do ->

    defineValue = (obj, key, value) ->
      if value isnt undefined
        reactive.define obj, key, {value}
      return

    return (values) ->
      mapValues = ValueMapper values, defineValue
      @_phases.init.push (args) ->
        mapValues this, args
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
        mutable.define type.prototype, key, {value: method}
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
        frozen.define type.prototype, key, {value: method}
      return
    return

  # TODO: Throw if method name already exists.
  defineHooks: do ->

    getDefaultHook = (keyPath) ->
      if isDev
      then -> throw Error "Must override '#{keyPath}'!"
      else emptyFunction

    return (hooks) ->
      assertType hooks, Object
      name = if @_name then @_name + "::" else ""
      @didBuild (type) ->
        for key, hook of hooks
          hook ?= getDefaultHook name + key
          type.prototype[key] = hook
        return

  defineBoundMethods: (methods) ->
    assertType methods, Object
    @didBuild (type) ->
      {prototype} = type
      sync.each methods, (method, key) ->
        frozen.define prototype, key, get: ->
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

  addMixin: (mixin, options) ->
    assertType mixin, Function, "mixin"
    mixin this, options
    return

  addMixins: (mixins) ->
    assertType mixins, Array, "mixins"
    for mixin, index in mixins
      assertType mixin, Function, "mixins[" + index + "]"
      mixin this, {}
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
    return @build().apply null, arguments

  build: ->

    if @_built
    then throw Error "Cannot build more than once!"
    else frozen.define this, "_built", {value: yes}

    applyChain @_phases.willBuild, this
    @__willBuild()

    type = @_createType()
    setKind type, @_kind

    applyChain @_phases.didBuild, null, [type]
    @__didBuild type

    return type

#
# Internal Methods
#

Object.assign Builder.prototype,

  _createType: ->
    name = @_name or ""

    buildArgs = @__createArgBuilder()
    assertType buildArgs, Function

    buildInstance = @__createInstanceBuilder()
    assertType buildInstance, Function

    return buildType name, buildArgs, buildInstance

  _getBaseCreator: ->
    defaultKind = @_defaultKind or Object

    if @_kind is no
      @_kind = defaultKind

    kind = @_kind
    createInstance = @_createInstance

    unless createInstance

      if kind is defaultKind
        return @_defaultBaseCreator

      createInstance =
        if kind is null
        then PureObject.create
        else kind

    return (args) ->
      instance = createInstance.apply this, args
      instanceType and setType instance, instanceType
      return instance

  _defaultBaseCreator: ->
    Object.create instanceType.prototype

  _assertUniqueMethodNames: isDev and (methods) ->
    prefix = if @_name then @_name + "::" else ""
    for key, method of methods

      continue if method is undefined
      unless method instanceof Function
        throw TypeError "'#{prefix + key}' must be a kind of Function!"

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

      # Only wrap methods that call their super.
      continue if 0 > method.toString().indexOf "this.__super"

      hasInherited = yes
      methods[key] = Super inherited, method

    return hasInherited

#
# Subclass Hooks
#

Object.assign Builder.prototype,

  # Returns the function responsible for transforming and
  # validating the arguments passed to the constructor.
  __createArgBuilder: ->
    return emptyFunction.thatReturnsArgument

  # Returns the function responsible for initializing
  # each new instance's properties and any other work
  # that should be done before the constructor returns.
  __createInstanceBuilder: ->
    createInstance = @_getBaseCreator()
    instPhases = @_phases.init
    return buildInstance = (type, args, context) ->

      if not instanceType
        instanceType = type
        isDev and instanceID = type.__count++

      instance = createInstance.call context, args

      if instanceType

        isDev and mutable.define instance, "__name",
          value: instanceType.getName() + "_" + instanceID

        instanceType = null
        isDev and instanceID = null

      applyChain instPhases, instance, [ args ]

      return instance

  __didInherit: emptyFunction

  __willBuild: emptyFunction

  __didBuild: emptyFunction

#
# Helpers
#

if isDev

  initTypeCount = (type) ->
    mutable.define type, "__count", {value: 0}

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

buildType =

  if isDev then (name, buildArgs, buildInstance) ->
    return Function(
      "global",
      "buildArgs",
      "buildInstance",
      "var type;" +
      "return type = function #{name}() {\n" +
      "  var context = this === global ? null : this;\n" +
      "  var args = buildArgs(arguments, context);\n" +
      "  return buildInstance(type, args, context);\n" +
      "}"
    ) global, buildArgs, buildInstance

  else (name, buildArgs, buildInstance) ->

    type = ->
      context = if this is global then null else this
      args = buildArgs arguments, context
      return buildInstance type, args, context

    type.getName = ->
      return name

    return type
