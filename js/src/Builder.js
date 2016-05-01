var ArrayOf, Builder, NamedFunction, Null, Property, ValueDefiner, assert, assertType, define, emptyFunction, isType, ref, setKind, setType, sync, validateTypes;

require("isDev");

ref = require("type-utils"), Null = ref.Null, ArrayOf = ref.ArrayOf, isType = ref.isType, setType = ref.setType, setKind = ref.setKind, assert = ref.assert, assertType = ref.assertType, validateTypes = ref.validateTypes;

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

Property = require("Property");

define = require("define");

sync = require("sync");

ValueDefiner = require("./ValueDefiner");

module.exports = Builder = NamedFunction("Builder", function() {
  var self;
  self = setType({}, Builder);
  Builder.props.define(self);
  return self;
});

Builder.props = Property.Map({
  _cachedBuild: null,
  _kind: {
    value: Object
  },
  _willCreate: {
    value: emptyFunction
  },
  _createInstance: {
    value: function() {
      return {};
    }
  },
  _didCreate: {
    value: function(type) {
      return setType(this, type);
    }
  },
  _phases: function() {
    return {
      willBuild: [],
      didBuild: [],
      willCreate: [],
      didCreate: [],
      initInstance: []
    };
  }
});

define(Builder.prototype, {
  createInstance: function(createInstance) {
    assertType(createInstance, Function);
    this._createInstance = function(args) {
      return createInstance.apply(null, args);
    };
  },
  defineValues: ValueDefiner({
    needsValue: true
  }),
  defineFrozenValues: ValueDefiner({
    needsValue: true,
    frozen: true
  }),
  defineReactiveValues: ValueDefiner({
    needsValue: true,
    reactive: true
  }),
  defineProperties: function(props) {
    assertType(props, Object);
    props = sync.map(props, Property);
    this._initInstance(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  },
  defineMethods: function(methods) {
    var props;
    assertType(methods, Object);
    props = sync.map(methods, function(value, key) {
      assertType(value, Function, key);
      return Property({
        value: value
      });
    });
    this.didBuild(function(type) {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(type.prototype, key);
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
  bindMethods: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'bindMethods' must be passed an array of strings!");
    this._initInstance(function() {
      return sync.each(keys, (function(_this) {
        return function(key) {
          var method;
          method = _this[key];
          assertType(method, Function, key);
          return _this[key] = function() {
            return method.apply(_this, arguments);
          };
        };
      })(this));
    });
  },
  exposeGetters: function(keys) {
    var props;
    assertType(keys, Array);
    props = {};
    sync.each(keys, function(key) {
      var internalKey;
      internalKey = "_" + key;
      return props[key] = Property({
        get: function() {
          return this[internalKey];
        },
        enumerable: true
      });
    });
    this._initInstance(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  },
  exposeLazyGetters: function(keys) {
    var props;
    assertType(keys, Array);
    props = {};
    sync.each(keys, function(key) {
      var internalKey;
      internalKey = "_" + key;
      return props[key] = Property({
        get: function() {
          return this[internalKey].get();
        },
        enumerable: true
      });
    });
    this._initInstance(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  },
  initInstance: function(init) {
    assertType(init, Function);
    this._initInstance(function(args) {
      return init.apply(this, args);
    });
  },
  willCreate: function(fn) {
    assertType(fn, Function);
    this._phases.willCreate.push(fn);
  },
  didCreate: function(fn) {
    assertType(fn, Function);
    this._phases.didCreate.push(fn);
  },
  addMixins: function(mixins) {
    var i, len, mixin;
    assertType(mixins, Array);
    for (i = 0, len = mixins.length; i < len; i++) {
      mixin = mixins[i];
      mixin(this);
    }
  },
  willBuild: function(fn) {
    assertType(fn, Function);
    this._phases.willBuild.push(fn);
  },
  didBuild: function(fn) {
    assertType(fn, Function);
    this._phases.didBuild.push(fn);
  },
  build: function() {
    var constructType, transformArgs, type;
    if (this._cachedBuild) {
      return this._cachedBuild;
    }
    this._executePhase("willBuild", this);
    transformArgs = this.__createArgTransformer();
    constructType = this.__createConstructor();
    type = this.__createType(function() {
      return constructType(type, transformArgs(arguments));
    });
    this._executePhase("didBuild", null, [type]);
    this._cachedBuild = type;
    return type;
  },
  _initInstance: function(init) {
    assertType(init, Function);
    this._phases.initInstance.push(init);
  },
  _executePhase: function(phaseName, scope, args) {
    var callback, callbacks, i, j, len, len1;
    callbacks = this._phases[phaseName];
    if (!callbacks.length) {
      return;
    }
    if (args) {
      for (i = 0, len = callbacks.length; i < len; i++) {
        callback = callbacks[i];
        callback.apply(scope, args);
      }
    } else {
      for (j = 0, len1 = callbacks.length; j < len1; j++) {
        callback = callbacks[j];
        callback.call(scope);
      }
    }
  },
  __createArgTransformer: function() {
    return emptyFunction.thatReturnsArgument;
  },
  __createConstructor: function() {
    var createInstance, didCreate, initInstance, willCreate;
    willCreate = this._willCreate;
    createInstance = this._createInstance;
    initInstance = this.__createInitializer();
    didCreate = this._didCreate;
    return function(type, args) {
      var self;
      willCreate.call(null, type, args);
      self = createInstance.call(null, args);
      didCreate.call(self, type, args);
      initInstance(self, args);
      return self;
    };
  },
  __createInitializer: function() {
    var phases;
    phases = this._phases.initInstance;
    if (phases.length === 0) {
      return emptyFunction;
    }
    return function(self, args) {
      var i, len, phase;
      for (i = 0, len = phases.length; i < len; i++) {
        phase = phases[i];
        phase.call(self, args);
      }
    };
  },
  __createType: function(type) {
    setKind(type, this._kind);
    return type;
  },
  __initType: function(type) {
    if (isDev) {
      define(type, "_builder", this);
    }
  }
});

//# sourceMappingURL=../../map/src/Builder.map
