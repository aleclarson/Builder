var Builder, NamedFunction, Property, PureObject, Super, Tracer, ValueMapper, applyChain, assertType, bind, define, emptyFunction, forbiddenKinds, frozen, inArray, initTypeCount, injected, instanceID, instanceType, isType, mutable, ref, setKind, setType, sync, validateArgs;

require("isDev");

ref = Property = require("Property"), mutable = ref.mutable, frozen = ref.frozen;

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

ValueMapper = require("ValueMapper");

PureObject = require("PureObject");

assertType = require("assertType");

applyChain = require("applyChain");

inArray = require("in-array");

setType = require("setType");

setKind = require("setKind");

Tracer = require("tracer");

isType = require("isType");

define = require("define");

Super = require("Super");

bind = require("bind");

sync = require("sync");

injected = require("./injectable");

instanceType = null;

instanceID = null;

Builder = NamedFunction("Builder", function(name) {
  var phases, self;
  if (name != null) {
    assertType(name, String);
  }
  phases = {
    init: [],
    willBuild: [],
    didBuild: []
  };
  self = Object.create(Builder.prototype, {
    _name: {
      value: name
    },
    _kind: {
      value: false,
      writable: true
    },
    _phases: {
      value: phases
    }
  });
  isDev && self.didBuild(initTypeCount);
  return self;
});

module.exports = Builder;

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
    var createInstance;
    assertType(func, Function);
    if (this._createInstance) {
      throw Error("'createInstance' has already been called!");
    }
    if (this._kind === false) {
      throw Error("Must call 'inherits' before 'createInstance'!");
    }
    createInstance = function(args) {
      return func.apply(null, args);
    };
    isDev && (createInstance = bind.toString(func, createInstance));
    frozen.define(this, "_createInstance", {
      value: createInstance
    });
  },
  trace: function() {
    isDev && this._phases.init.push(function() {
      return mutable.define(this, "__stack", {
        value: Error()
      });
    });
  },
  initInstance: function(func) {
    var initInstance;
    assertType(func, Function);
    initInstance = function(args) {
      return func.apply(this, args);
    };
    isDev && (initInstance = bind.toString(func, initInstance));
    this._phases.init.push(initInstance);
  },
  defineFunction: function(func) {
    assertType(func, Function);
    this._kind = Function;
    this._createInstance = function() {
      var self;
      self = function() {
        return func.apply(self, arguments);
      };
      isDev && (self.toString = function() {
        return func.toString();
      });
      return self;
    };
  },
  defineValues: function(values) {
    values = ValueMapper({
      values: values,
      mutable: true
    });
    this._phases.init.push(function(args) {
      return values.define(this, args);
    });
  },
  defineFrozenValues: function(values) {
    values = ValueMapper({
      values: values,
      frozen: true
    });
    this._phases.init.push(function(args) {
      return values.define(this, args);
    });
  },
  defineReactiveValues: function(values) {
    values = ValueMapper({
      values: values,
      reactive: true
    });
    this._phases.init.push(function(args) {
      return values.define(this, args);
    });
  },
  defineEvents: function(eventConfigs) {
    var Event;
    assertType(eventConfigs, Object);
    Event = injected.get("Event");
    if (!(Event instanceof Function)) {
      throw Error("'defineEvents' requires an injected 'Event' constructor!");
    }
    this._phases.init.push(function() {
      var events, self;
      events = this.__events || Object.create(null);
      self = this;
      sync.each(eventConfigs, function(argTypes, key) {
        var event;
        event = Event();
        events[key] = function() {
          isDev && argTypes && validateArgs(arguments, argTypes);
          event.emit.apply(null, arguments);
        };
        frozen.define(self, key, {
          value: event.listenable
        });
      });
      this.__events || frozen.define(this, "__events", {
        value: events
      });
    });
  },
  defineListeners: function(createListeners) {
    var Event;
    assertType(createListeners, Function);
    Event = injected.get("Event");
    if (!(Event instanceof Function)) {
      throw Error("'defineListeners' requires an injected 'Event' constructor!");
    }
    this._phases.init.push(function(args) {
      var listeners, onAttach;
      listeners = this.__listeners || [];
      onAttach = Event.didAttach(function(listener) {
        return listeners.push(listener.start());
      }).start();
      createListeners.apply(this, args);
      onAttach.detach();
      this.__listeners || frozen.define(this, "__listeners", {
        value: listeners
      });
    });
  },
  defineProperties: function(props) {
    assertType(props, Object);
    props = sync.map(props, function(prop, key) {
      assertType(prop, Object, key);
      return Property(prop);
    });
    this._phases.init.push(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  },
  definePrototype: function(props) {
    assertType(props, Object);
    this.didBuild(function(type) {
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
    this.didBuild(function(type) {
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
    this.didBuild(function(type) {
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
    this.didBuild(function(type) {
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
    this.didBuild(function(type) {
      var prototype;
      prototype = type.prototype;
      sync.each(methods, function(method, key) {
        return define(prototype, key, {
          get: function() {
            var value;
            value = bind.func(method, this);
            frozen.define(this, key, {
              value: value
            });
            return value;
          }
        });
      });
    });
  },
  defineGetters: function(getters) {
    assertType(getters, Object);
    this.didBuild(function(type) {
      var get, key, prototype;
      prototype = type.prototype;
      for (key in getters) {
        get = getters[key];
        assertType(get, Function, key);
        frozen.define(prototype, key, {
          get: get
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
    this.didBuild(function(type) {
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
    this._phases.willBuild.push(func);
  },
  didBuild: function(func) {
    assertType(func, Function);
    this._phases.didBuild.push(func);
  },
  construct: function() {
    return this.build().apply(null, arguments);
  },
  build: function() {
    var type;
    applyChain(this._phases.willBuild, this);
    type = this._createType();
    setKind(type, this._kind);
    applyChain(this._phases.didBuild, null, [type]);
    return type;
  },
  _createType: function() {
    var buildArgs, buildInstance, name, type;
    name = this._name || "";
    buildArgs = this.__createArgBuilder();
    buildInstance = this.__createInstanceBuilder();
    if (isDev) {
      assertType(buildArgs, Function);
      assertType(buildInstance, Function);
      return Function("buildArgs", "buildInstance", "var type;" + ("return type = function " + name + "() {\n") + "  return buildInstance(type, buildArgs(arguments));\n" + "}")(buildArgs, buildInstance);
    }
    type = function() {
      return buildInstance(type, buildArgs(arguments));
    };
    type.getName = function() {
      return name;
    };
    return type;
  },
  _getBaseCreator: function() {
    var createInstance, defaultKind, kind;
    defaultKind = this._defaultKind || Object;
    if (this._kind === false) {
      this._kind = defaultKind;
    }
    kind = this._kind;
    createInstance = this._createInstance;
    if (!createInstance) {
      if (kind === defaultKind) {
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
  __createArgBuilder: function() {
    return emptyFunction.thatReturnsArgument;
  },
  __createInstanceBuilder: function() {
    var buildInstance, createInstance, instPhases;
    createInstance = this._getBaseCreator();
    instPhases = this._phases.init;
    return buildInstance = function(type, args) {
      var instance;
      if (!instanceType) {
        instanceType = type;
        isDev && (instanceID = type.__count++);
      }
      instance = createInstance.call(null, args);
      if (instanceType) {
        isDev && frozen.define(instance, "__name", {
          value: instanceType.getName() + "_" + instanceID
        });
        instanceType = null;
        isDev && (instanceID = null);
      }
      applyChain(instPhases, instance, [args]);
      return instance;
    };
  }
});

if (isDev) {
  initTypeCount = function(type) {
    return mutable.define(type, "__count", {
      value: 0
    });
  };
  validateArgs = function(args, argTypes) {
    var argNames, i, index, len, name;
    argNames = Object.keys(argTypes);
    for (index = i = 0, len = argNames.length; i < len; index = ++i) {
      name = argNames[index];
      assertType(args[index], argTypes[name], name);
    }
  };
  forbiddenKinds = [String, Boolean, Number, Array, Symbol, Date, RegExp];
}

//# sourceMappingURL=map/Builder.map
