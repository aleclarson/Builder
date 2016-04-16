var ArrayOf, Builder, NamedFunction, Null, ObjectLiteral, assert, assertType, define, emptyFunction, isEnumerableKey, isType, ref, setKind, setType, sync, validateTypes;

require("isDev");

ref = require("type-utils"), Null = ref.Null, ArrayOf = ref.ArrayOf, isType = ref.isType, setType = ref.setType, setKind = ref.setKind, assert = ref.assert, assertType = ref.assertType, validateTypes = ref.validateTypes;

isEnumerableKey = require("isEnumerableKey");

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

define = require("define");

sync = require("sync");

ObjectLiteral = function() {
  return {};
};

module.exports = Builder = NamedFunction("Builder", function() {
  var self;
  self = setType({}, Builder);
  define(self, {
    enumerable: false
  }, {
    _buildResult: null,
    _kind: Object,
    _willCreate: emptyFunction,
    _createInstance: ObjectLiteral,
    _didCreate: emptyFunction,
    _phases: {
      value: {
        build: [],
        initType: [],
        initInstance: []
      }
    }
  });
  return self;
});

define(Builder.prototype, {
  createInstance: function(createInstance) {
    assertType(createInstance, Function);
    this._createInstance = function(args) {
      return createInstance.apply(null, args);
    };
  },
  defineProperties: function(props) {
    assertType(props, Object);
    this._phases.initInstance.push(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        if (isDev && (prop.enumerable === void 0)) {
          prop.enumerable = isEnumerableKey(key);
        }
        define(this, key, prop);
      }
    });
  },
  definePrototype: function(prototype) {
    assertType(prototype, Object);
    this._phases.initType.push(function(type) {
      var key, value;
      for (key in prototype) {
        value = prototype[key];
        if (isEnumerableKey(key)) {
          type.prototype[key] = value;
        } else {
          define(type.prototype, key, {
            value: value,
            enumerable: false
          });
        }
      }
    });
  },
  defineStatics: function(statics) {
    assertType(statics, Object);
    this._phases.initType.push(function(type) {
      var key, prop;
      for (key in statics) {
        prop = statics[key];
        assertType(prop, Object, "statics." + key);
        if (isDev && (prop.enumerable === void 0)) {
          prop.enumerable = isEnumerableKey(key);
        }
        define(type, key, prop);
      }
    });
  },
  createValues: function(createValues) {
    assertType(createValues, Function);
    this._phases.initInstance.push(function(args) {
      var key, value, values;
      values = createValues.apply(this, args);
      assert(isType(values, Object), "'createValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        if (isEnumerableKey(key)) {
          this[key] = value;
        } else {
          define(this, key, {
            value: value,
            enumerable: false
          });
        }
      }
    });
  },
  createFrozenValues: function(createFrozenValues) {
    assertType(createFrozenValues, Function);
    this._phases.initInstance.push(function(args) {
      var key, value, values;
      values = createFrozenValues.apply(this, args);
      assert(isType(values, Object), "'createFrozenValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        if (isDev) {
          define(this, key, {
            value: value,
            frozen: true,
            enumerable: isEnumerableKey(key)
          });
        } else {
          this[key] = value;
        }
      }
    });
  },
  createReactiveValues: function(createReactiveValues) {
    assertType(createReactiveValues, Function);
    this._phases.initInstance.push(function(args) {
      var key, value, values;
      values = createReactiveValues.apply(this, args);
      assert(isType(values, Object), "'createReactiveValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        define(this, key, {
          value: value,
          reactive: true,
          enumerable: isEnumerableKey(key)
        });
      }
    });
  },
  bindMethods: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'bindMethods' must be passed an array of strings!");
    this._phases.initInstance.push(function() {
      return sync.each(keys, (function(_this) {
        return function(key) {
          var value;
          value = _this[key];
          assertType(value, Function, {
            key: _this.constructor.name + "." + key,
            instance: _this
          });
          return _this[key] = function() {
            return value.apply(_this, arguments);
          };
        };
      })(this));
    });
  },
  exposeGetters: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'exposeGetters' must be passed an array of strings!");
    this._phases.initInstance.push(function() {
      return sync.each(keys, (function(_this) {
        return function(key) {
          var internalKey;
          internalKey = "_" + key;
          return define(_this, key, {
            get: function() {
              return this[internalKey];
            }
          });
        };
      })(this));
    });
  },
  exposeLazyGetters: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'exposeGetters' must be passed an array of strings!");
    this._phases.initInstance.push(function() {
      return sync.each(keys, (function(_this) {
        return function(key) {
          var internalKey;
          internalKey = "_" + key;
          return define(_this, key, {
            get: function() {
              return this[internalKey].get();
            }
          });
        };
      })(this));
    });
  },
  addMixins: function(mixins) {
    var i, len, mixin;
    assertType(mixins, Array);
    for (i = 0, len = mixins.length; i < len; i++) {
      mixin = mixins[i];
      mixin.call(this);
    }
  },
  init: function(init) {
    assertType(init, Function);
    this._phases.initInstance.push(function(args) {
      return init.apply(this, args);
    });
  },
  build: function() {
    var constructor, i, len, phase, ref1, transformArgs, type;
    if (this._buildResult) {
      return this._buildResult;
    }
    if (this._phases.build.length) {
      ref1 = this._phases.build;
      for (i = 0, len = ref1.length; i < len; i++) {
        phase = ref1[i];
        phase.call(this);
      }
    }
    transformArgs = this.__createArgTransformer();
    constructor = this.__createConstructor();
    type = this.__createType(function() {
      return constructor(type, transformArgs(arguments));
    });
    this.__initType(type);
    return this._buildResult = type;
  }
});

define(Builder.prototype, {
  enumerable: false
}, {
  __createType: function(type) {
    setKind(type, this._kind);
    return type;
  },
  __initType: function(type) {
    var i, len, phase, phases;
    phases = this._phases.initType;
    if (phases.length) {
      for (i = 0, len = phases.length; i < len; i++) {
        phase = phases[i];
        phase.call(null, type);
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
      self = createInstance.apply(null, args);
      initInstance(self, args);
      didCreate.call(self, type, args);
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
  }
});

//# sourceMappingURL=../../map/src/Builder.map
