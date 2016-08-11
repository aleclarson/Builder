var ArrayOf, Builder, NamedFunction, Property, PureObject, Super, Tracer, ValueMapper, applyChain, assertType, bind, builderProps, define, emptyFunction, forbiddenKinds, frozen, inArray, initTypeCount, instanceID, instanceProps, instanceType, isType, mutable, ref, setKind, setType, sync, wrapValue;

require("isDev");

ref = Property = require("Property"), mutable = ref.mutable, frozen = ref.frozen;

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

ValueMapper = require("ValueMapper");

PureObject = require("PureObject");

applyChain = require("applyChain");

assertType = require("assertType");

wrapValue = require("wrapValue");

inArray = require("in-array");

setType = require("setType");

setKind = require("setKind");

ArrayOf = require("ArrayOf");

Tracer = require("tracer");

isType = require("isType");

define = require("define");

Super = require("Super");

bind = require("bind");

sync = require("sync");

Builder = NamedFunction("Builder", function(name, func) {
  var self;
  self = Object.create(Builder.prototype);
  builderProps.define(self);
  if (name) {
    assertType(name, String);
    self._name = name;
  }
  if (func) {
    assertType(func, Function);
    self._kind = Function;
    self._createInstance = function() {
      var instance;
      instance = function() {
        return func.apply(instance, arguments);
      };
      if (isDev) {
        instance.toString = function() {
          return func.toString();
        };
      }
      return instance;
    };
  }
  if (isDev) {
    self._didBuild.push(initTypeCount);
    Object.defineProperty(self, "_tracer", {
      value: Tracer("Builder.construct()", {
        skip: 2
      })
    });
  }
  return self;
});

module.exports = Builder;

builderProps = Property.Map({
  _name: null,
  _kind: false,
  _defaultKind: function() {
    return Object;
  },
  _createInstance: null,
  _initInstance: function() {
    return [];
  },
  _willBuild: function() {
    return [];
  },
  _didBuild: function() {
    return [];
  },
  _cachedBuild: null
});

instanceType = null;

if (isDev) {
  instanceID = null;
  initTypeCount = function(type) {
    return type.count = 0;
  };
  instanceProps = Property.Map({
    __id: function() {
      return instanceID;
    },
    __name: {
      get: function() {
        return this.constructor.getName() + "_" + this.__id;
      }
    }
  });
  forbiddenKinds = [String, Boolean, Number, Array, Symbol, Date, RegExp];
}

define(Builder, {
  building: {
    get: function() {
      return instanceType;
    }
  }
});

define(Builder.prototype, {
  inherits: function(kind) {
    if (this._kind !== false) {
      throw Error("'kind' is already defined!");
    }
    if (inArray(forbiddenKinds, kind)) {
      throw Error("Cannot inherit from '" + kind.name + "'!");
    }
    if (!((kind instanceof Function) || (kind === null))) {
      throw Error("'kind' must be a kind of Function (or null)!");
    }
    this._kind = kind;
  },
  createInstance: function(func) {
    assertType(func, Function);
    if (this._createInstance) {
      throw Error("'createInstance' has already been called!");
    }
    if (this._kind === false) {
      throw Error("Must call 'inherits' before 'createInstance'!");
    }
    this._createInstance = bind.toString(func, function(args) {
      return func.apply(null, args);
    });
  },
  trace: function() {
    define(this, "_shouldTrace", {
      value: true
    });
  },
  initInstance: function(func) {
    assertType(func, Function);
    this._initInstance.push(function(args) {
      return func.apply(this, args);
    });
  },
  defineValues: function(values) {
    values = ValueMapper({
      values: values,
      mutable: true
    });
    this._initInstance.push(function(args) {
      return values.define(this, args);
    });
  },
  defineFrozenValues: function(values) {
    values = ValueMapper({
      values: values,
      frozen: true
    });
    this._initInstance.push(function(args) {
      return values.define(this, args);
    });
  },
  defineReactiveValues: function(values) {
    values = ValueMapper({
      values: values,
      reactive: true
    });
    this._initInstance.push(function(args) {
      return values.define(this, args);
    });
  },
  defineEvents: function(events) {
    var EventMap, kind;
    assertType(events, Object);
    EventMap = require("./inject/EventMap").get();
    if (!(EventMap instanceof Function)) {
      throw Error("Must inject an 'EventMap' constructor before calling 'defineEvents'!");
    }
    kind = this._kind;
    if (this.__hasEvents || (kind && kind.prototype.__hasEvents)) {
      this._initInstance.push(function() {
        return this._events._addEvents(events);
      });
    } else {
      this._didBuild.push(function(type) {
        return frozen.define(type.prototype, "__hasEvents", {
          value: true
        });
      });
      this._initInstance.push(function() {
        return frozen.define(this, "_events", {
          value: EventMap(events)
        });
      });
    }
    this.__hasEvents || frozen.define(this, "__hasEvents", {
      value: true
    });
    return this._didBuild.push(function(type) {
      return sync.keys(events, function(eventName) {
        return frozen.define(type.prototype, eventName, {
          value: function(maxCalls, onNotify) {
            return this._events(eventName, maxCalls, onNotify);
          }
        });
      });
    });
  },
  defineProperties: function(props) {
    assertType(props, Object);
    props = sync.map(props, function(prop, key) {
      assertType(prop, Object, key);
      return Property(prop);
    });
    this._initInstance.push(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  },
  definePrototype: function(props) {
    assertType(props, Object);
    this._didBuild.push(function(type) {
      var key, prop;
      for (key in props) {
        prop = props[key];
        if (!isType(prop, Object)) {
          prop = {
            value: prop
          };
        }
        if (!(prop.set || prop.writable)) {
          prop.frozen = true;
        }
        define(type.prototype, key, prop);
      }
    });
  },
  defineMethods: function(methods) {
    assertType(methods, Object);
    isDev && this._assertUniqueMethodNames(methods);
    this._didBuild.push(function(type) {
      var key, method;
      for (key in methods) {
        method = methods[key];
        mutable.define(type.prototype, key, {
          value: method
        });
      }
    });
  },
  overrideMethods: function(methods) {
    var hasInherited;
    assertType(methods, Object);
    if (this._kind === false) {
      throw Error("Must call 'inherits' before 'overrideMethods'!");
    }
    hasInherited = this._inheritMethods(methods);
    this._didBuild.push(function(type) {
      var key, method;
      hasInherited && Super.augment(type);
      for (key in methods) {
        method = methods[key];
        mutable.define(type.prototype, key, {
          value: method
        });
      }
    });
  },
  defineHooks: function(hooks) {
    var name;
    assertType(hooks, Object);
    name = this._name ? this._name + "::" : "";
    this._didBuild.push(function(type) {
      var defaultValue, key, value;
      for (key in hooks) {
        defaultValue = hooks[key];
        if (defaultValue instanceof Function) {
          value = defaultValue;
        } else if (isDev) {
          value = function() {
            throw Error("Must override '" + (name + key) + "'!");
          };
        } else {
          value = emptyFunction;
        }
        type.prototype[key] = value;
      }
    });
  },
  defineBoundMethods: function(methods) {
    assertType(methods, Object);
    this._initInstance.unshift(function() {
      var key, method;
      for (key in methods) {
        method = methods[key];
        assertType(method, Function, key);
        this[key] = bind.func(method, this);
      }
    });
  },
  defineGetters: function(getters) {
    assertType(getters, Object);
    this._didBuild.push(function(arg) {
      var getter, key, prototype;
      prototype = arg.prototype;
      for (key in getters) {
        getter = getters[key];
        frozen.define(prototype, key, {
          get: getter
        });
      }
    });
  },
  defineStatics: function(statics) {
    var props;
    assertType(statics, Object);
    props = sync.map(statics, function(options, key) {
      if (!isType(options, Object)) {
        options = {
          value: options
        };
      }
      return Property(options);
    });
    this._didBuild.push(function(type) {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(type, key);
      }
    });
  },
  addMixins: function(mixins) {
    var i, index, len, mixin;
    assertType(mixins, Array, "mixins");
    for (index = i = 0, len = mixins.length; i < len; index = ++i) {
      mixin = mixins[index];
      assertType(mixin, Function, "mixins[" + index + "]");
      mixin(this);
    }
  },
  willBuild: function(func) {
    assertType(func, Function);
    this._willBuild.push(func);
  },
  didBuild: function(func) {
    assertType(func, Function);
    this._didBuild.push(func);
  },
  construct: function() {
    return this.build().apply(null, arguments);
  },
  build: function() {
    var type;
    if (this._cachedBuild) {
      return this._cachedBuild;
    }
    applyChain(this._willBuild, this);
    type = this._createType();
    setKind(type, this._kind);
    isDev && frozen.define(type, "_builder", {
      value: this
    });
    applyChain(this._didBuild, null, [type]);
    return this._cachedBuild = type;
  },
  _createType: function() {
    var createArguments, createInstance, name, type;
    name = this._name || "";
    createArguments = this.__buildArgumentCreator();
    createInstance = this.__buildInstanceCreator();
    type = NamedFunction(name, function() {
      return createInstance(type, createArguments(arguments));
    });
    return type;
  },
  _getBaseCreator: function() {
    var createInstance, kind;
    if (this._kind === false) {
      this._kind = this._defaultKind;
    }
    kind = this._kind;
    createInstance = this._createInstance;
    if (!createInstance) {
      if (kind === this._defaultKind) {
        return this._defaultBaseCreator;
      }
      if (kind === null) {
        createInstance = PureObject.create;
      } else {
        createInstance = function(args) {
          return kind.apply(null, args);
        };
      }
    }
    return function(args) {
      var instance;
      instance = createInstance.call(null, args);
      instanceType && setType(instance, instanceType);
      return instance;
    };
  },
  _defaultBaseCreator: function() {
    return Object.create(instanceType.prototype);
  },
  _assertUniqueMethodNames: function(methods) {
    var inherited, key, method, prefix;
    prefix = this._name ? this._name + "::" : "";
    for (key in methods) {
      method = methods[key];
      assertType(method, Function, prefix + key);
      if (!this._kind) {
        continue;
      }
      if (!(inherited = Super.findInherited(this._kind, key))) {
        continue;
      }
      throw Error(("Inherited methods cannot be redefined: '" + (prefix + key) + "'\n\n") + "Call 'overrideMethods' to explicitly override!");
    }
  },
  _inheritMethods: function(methods) {
    var hasInherited, inherited, key, method, prefix;
    prefix = this._name ? this._name + "::" : "";
    hasInherited = false;
    for (key in methods) {
      method = methods[key];
      assertType(method, Function, prefix + key);
      inherited = Super.findInherited(this._kind, key);
      if (!inherited) {
        throw Error("Cannot find method to override for: '" + (prefix + key) + "'!");
      }
      if (!Super.regex.test(method.toString())) {
        continue;
      }
      hasInherited = true;
      methods[key] = Super(inherited, method);
    }
    return hasInherited;
  },
  __buildArgumentCreator: function() {
    return emptyFunction.thatReturnsArgument;
  },
  __buildInstanceCreator: function() {
    var constructor, createInstance, initInstance, shouldTrace;
    createInstance = this._getBaseCreator();
    initInstance = this._initInstance;
    shouldTrace = this._shouldTrace;
    return constructor = function(type, args) {
      var instance;
      if (!instanceType) {
        instanceType = type;
        if (isDev) {
          instanceID = type.count++;
        }
      }
      instance = createInstance.call(null, args);
      if (instanceType) {
        instanceType = null;
        if (isDev) {
          instanceProps.define(instance);
          instanceID = null;
        }
      }
      if (isDev && shouldTrace) {
        if (!instance._tracers) {
          frozen.define(instance, "_tracers", {
            value: Object.create(null)
          });
        }
        instance._tracers.init = Tracer(this._name + "()");
      }
      applyChain(initInstance, instance, [args]);
      return instance;
    };
  }
});

//# sourceMappingURL=map/Builder.map
