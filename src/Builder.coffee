
{mutable, frozen, reactive} = Property = require "Property"

NamedFunction = require "NamedFunction"
emptyFunction = require "emptyFunction"
assertType = require "assertType"
setProto = require "setProto"
setType = require "setType"
setKind = require "setKind"
isType = require "isType"
Super = require "Super"
isDev = require "isDev"
bind = require "bind"
sync = require "sync"

PropertyMap = require "./PropertyMap"
createType = require "./createType"
PhaseMap = require "./PhaseMap"

# The base instance in the inheritance chain
# must use this type's prototype with 'Object.create'.
instanceType = null
instanceID = null

Builder = NamedFunction "Builder", (name) ->
  assertType name, String if name?

  values =
    _name: name
    _used: Object.create null
    _phases: PhaseMap()
    _values: PropertyMap()
    _protos: PropertyMap()
    _statics: PropertyMap()

  values[key] = {value} for key, value of values
  values._kind = {value: no, writable: yes}

  self = Object.create Builder.prototype, values
  isDev and self._phases.push "didBuild", initTypeCount
  return self

module.exports = Builder

prototype =

  abstract: ->
    # TODO: Throw when attempting to construct an abstract type.

  # NOTE: If the inherited type requires the 'new' keyword
  #       to be used, you must call 'createInstance' manually!
  inherits: (kind) ->

    if @_kind isnt no
      throw Error "'kind' is already defined!"

    unless (kind instanceof Function) or (kind is null)
      throw Error "'kind' must be a kind of Function (or null)!"

    # Allow subtypes to know if a supertype used a method
    # that relies on a once-per-prototype mechanism.
    setProto @_used, kind._used if kind and kind._used

    @_kind = kind
    @__didInherit kind
    return

  createInstance: (createInstance) ->

    assertType createInstance, Function

    if @_createInstance
      throw Error "'createInstance' has already been called!"

    Object.defineProperty this, "_createInstance", {value: createInstance}
    return

  trace: ->
    isDev and @_values.push ->
      Object.defineProperty this, "__stack", value: Error()
    return

  defineFunction: (func) ->
    assertType func, Function
    @_kind = Function
    @_createInstance = ->
      self = -> func.apply self, arguments
      isDev and self.toString = -> func.toString()
      return self
    return

  construct: ->
    return @build().apply null, arguments

  build: ->

    if @_built
    then throw Error "Cannot build more than once!"
    else frozen.define this, "_built", {value: yes}

    if @_kind is no
      @_kind = @_defaultKind

    @_phases.apply "willBuild", this
    @__willBuild()

    type = @_createType()
    setKind type, @_kind

    @_protos.apply type.prototype
    @_statics.apply type

    Object.defineProperties type,
      displayName: {value: @_name or ""}
      _used: {value: @_used}

    @_phases.apply "didBuild", null, [type]
    @__didBuild type

    return type

### Methods available to mixins ###
Object.assign prototype, mixinPrototype =

  initInstance: (callback) ->
    assertType callback, Function
    @_values.push callback
    return

  createValue: (key, create) ->
    @_createValue key, create, defineValue

  defineValue: (key, value) ->
    @_defineValue key, value, defineValue

  createFrozenValue: (key, create) ->
    @_createValue key, create, defineFrozenValue

  defineFrozenValue: (key, value) ->
    @_defineValue key, value, defineFrozenValue

  createReactiveValue: (key, create) ->
    @_createValue key, create, defineReactiveValue

  defineReactiveValue: (key, value) ->
    @_defineValue key, value, defineReactiveValue

  defineValues: (values) ->
    @_values.push defineValue, values
    return

  defineFrozenValues: (values) ->
    @_values.push defineFrozenValue, values
    return

  defineReactiveValues: (values) ->
    @_values.push defineReactiveValue, values
    return

  defineProperty: (key, prop) ->
    prop = Property prop
    @_values.push ->
      prop.define this, key
      return
    return

  defineProperties: (props) ->
    @_defineProperties @_values, props

  definePrototype: (props) ->
    @_defineProperties @_protos, props

  defineMethod: (name, method) ->
    assertType name, String
    isDev and @_validateMethod name, method
    @_protos.push -> defineValue this, name, method
    return

  defineMethods: (methods) ->
    isDev and @_validateMethods methods
    @_protos.push defineValue, methods
    return

  overrideMethods: (methods) ->
    assertType methods, Object

    if @_kind is no
      throw Error "Must call 'inherits' before 'overrideMethods'!"

    shouldAugment = no

    for key, method of methods
      continue if method is undefined

      unless method instanceof Function
        throw TypeError "'#{getMethodPath @_name, key}' must be a kind of Function!"

      unless inherited = Super.findInherited @_kind, key
        throw Error "Cannot find method to override for: '#{getMethodPath @_name, key}'!"

      # Only wrap methods that call their super.
      if 0 <= method.toString().indexOf "this.__super"
        methods[key] = Super inherited, method
        shouldAugment = yes

    @_protos.push defineValue, methods
    shouldAugment and @_phases.push "didBuild", Super.augment
    return

  # TODO: Throw if method name already exists.
  defineHooks: (methods) ->
    assertType methods, Object
    isDev and @_validateMethods methods

    name = @_name
    @_protos.push ->
      for key, method of methods
        if method is null
          if isDev
          then method = -> throw Error "Must override '#{getMethodPath name, key}'!"
          else method = emptyFunction

        continue unless method
        defineValue this, key, method
      return
    return

  defineBoundMethods: (methods) ->
    assertType methods, Object
    @_protos.push ->
      for key, method of methods
        defineBoundMethod this, key, method
      return
    return

  defineGetters: (getters) ->
    assertType getters, Object
    @_protos.push ->
      for key, get of getters
        assertType get, Function, key
        frozen.define this, key, {get}
      return
    return

  defineStatics: (statics) ->
    @_defineProperties @_statics, statics

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

  willBuild: (callback) ->
    @_phases.push "willBuild", callback
    return

  didBuild: (callback) ->
    @_phases.push "didBuild", callback
    return

### Subclass hooks ###
Object.assign prototype,

  __didInherit: emptyFunction

  __willBuild: emptyFunction

  __didBuild: emptyFunction

  # Returns the function responsible for transforming and
  # validating the arguments passed to the constructor.
  __createArgBuilder: ->
    return emptyFunction.thatReturnsArgument

  # Returns the function responsible for initializing
  # each new instance's properties and any other work
  # that should be done before the constructor returns.
  __createInstanceBuilder: ->
    values = @_values
    createInstance = @_getInstanceCreator()
    return buildInstance = (type, args, context) ->

      unless instanceType
        instanceType = type
        isDev and instanceID = type.__count++

      instance = createInstance.call context, args

      if instanceType
        if isDev
          Object.defineProperty instance, "__name",
            value: instanceType.getName() + "_" + instanceID
          instanceID = null
        instanceType = null

      values.apply instance, args
      return instance

### Internal prototype ###
Object.assign prototype,

  _defaultKind: Object

  _needs: (name) ->
    return no if @_used[name]
    @_used[name] = yes
    return yes

  _createValue: (key, create, define) ->
    @_values.push ->
      value = create.apply this, arguments
      define this, key, value
    return

  _defineValue: (key, value, define) ->
    @_values.push ->
      define this, key, value
    return

  _defineProperties: (values, props) ->
    assertType values, PropertyMap
    assertType props, Object

    props = sync.map props, (prop, key) ->
      prop = {value: prop} unless isType prop, Object
      assertType prop, Object, key
      return Property prop

    values.push ->
      for key, prop of props
        prop.define this, key
      return
    return

  _createType: ->
    name = @_name or ""

    buildArgs = @__createArgBuilder()
    assertType buildArgs, Function

    buildInstance = @__createInstanceBuilder()
    assertType buildInstance, Function

    return createType name, buildArgs, buildInstance

  _rootCreator: ->
    Object.create instanceType.prototype

  _getInstanceCreator: ->

    unless createInstance = @_createInstance
      kind = @_kind

      if kind is null or kind is Object
        return @_rootCreator

      createInstance =
        if kind is @_defaultKind
        then @_defaultCreator or kind
        else kind

    return (args) ->
      instance = createInstance.apply this, args
      instanceType and setType instance, instanceType
      return instance

  _validateMethod: if isDev then (key, method) ->

    return unless method
    unless method instanceof Function
      throw TypeError "'#{getMethodPath @_name, key}' must be a kind of Function!"

    return unless @_kind
    return unless Super.findInherited @_kind, key

    throw Error "Cannot redefine an inherited method: '#{getMethodPath @_name, key}'\n\n" +
                "Call 'overrideMethods' to explicitly override!"

  _validateMethods: if isDev then (methods) ->
    assertType methods, Object
    for key, method of methods
      @_validateMethod key, method
    return

do -> # Ensure the prototype is not enumerable.
  for key, value of prototype
    continue if value is undefined
    Object.defineProperty Builder.prototype, key, {value}
  return

Builder.Mixin = require("Mixin").create
  methods: Object.keys mixinPrototype

#
# Helpers
#

isDev and initTypeCount = (type) ->
  mutable.define type, "__count", {value: 0}

isDev and getMethodPath = (typeName, methodName) ->
  if typeName
  then typeName + "::" + methodName
  else methodName

defineValue = (obj, key, value) ->
  prop = {value, writable: yes}
  prop.enumerable = not key.startsWith "_"
  Object.defineProperty obj, key, prop

defineFrozenValue = (obj, key, value) ->
  frozen.define obj, key, {value}

defineReactiveValue = (obj, key, value) ->
  reactive.define obj, key, {value}

defineBoundMethod = (obj, key, method) ->
  mutable.define obj, key, get: ->
    value = bind.func method, this
    mutable.define this, key, {value}
    return value
