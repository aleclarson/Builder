var ArrayOf, Builder, NamedFunction, Null, assert, assertType, createObjectLiteral, define, emptyFunction, isDev, isEnumerable, isObject, isType, mergeDefaults, ref, setKind, setType, sync, validateTypes;

ref = require("type-utils"), Null = ref.Null, ArrayOf = ref.ArrayOf, isType = ref.isType, setType = ref.setType, setKind = ref.setKind, assert = ref.assert, assertType = ref.assertType, validateTypes = ref.validateTypes;

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

isObject = require("isObject");

define = require("define");

isDev = require("isDev");

sync = require("sync");

module.exports = Builder = NamedFunction("Builder", function() {
  var self;
  self = setType({}, Builder);
  define(self, {
    enumerable: false
  }, {
    _kind: Object,
    _typePhases: [],
    _argPhases: [],
    _getCacheID: null,
    _willCreate: emptyFunction,
    _createInstance: createObjectLiteral,
    _initPhases: [],
    _didCreate: emptyFunction
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
  fromCache: function(getCacheID) {
    assertType(getCacheID, Function);
    this._getCacheID = getCacheID;
    this._typePhases.push(function(type) {
      return type.cache = Object.create(null);
    });
  },
  createArguments: function(createArguments) {
    assertType(createArguments, Function);
    this._argPhases.push(createArguments);
  },
  defineProperties: function(props) {
    assertType(props, Object);
    this._initPhases.push(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        if (isDev && (prop.enumerable === void 0)) {
          prop.enumerable = isEnumerable(key);
        }
        define(this, key, prop);
      }
    });
  },
  definePrototype: function(prototype) {
    assertType(prototype, Object);
    this._typePhases.push(function(type) {
      var key, value;
      for (key in prototype) {
        value = prototype[key];
        if (isEnumerable(key)) {
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
    this._typePhases.push(function(type) {
      var key, prop;
      for (key in statics) {
        prop = statics[key];
        assertType(prop, Object, "statics." + key);
        if (isDev && (prop.enumerable === void 0)) {
          prop.enumerable = isEnumerable(key);
        }
        define(type, key, prop);
      }
    });
  },
  createValues: function(createValues) {
    assertType(createValues, Function);
    this._initPhases.push(function(args) {
      var key, value, values;
      values = createValues.apply(this, args);
      assert(isObject(values), "'createValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        if (isEnumerable(key)) {
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
    this._initPhases.push(function(args) {
      var key, value, values;
      values = createFrozenValues.apply(this, args);
      assert(isObject(values), "'createFrozenValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        if (isDev) {
          define(this, key, {
            value: value,
            frozen: true,
            enumerable: isEnumerable(key)
          });
        } else {
          this[key] = value;
        }
      }
    });
  },
  createReactiveValues: function(createReactiveValues) {
    assertType(createReactiveValues, Function);
    this._initPhases.push(function(args) {
      var key, value, values;
      values = createReactiveValues.apply(this, args);
      assert(isObject(values), "'createReactiveValues' must return an Object!");
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        define(this, key, {
          value: value,
          reactive: true,
          enumerable: isEnumerable(key)
        });
      }
    });
  },
  bindMethods: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'bindMethods' must be passed an array of strings!");
    this._initPhases.push(function() {
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
    this._initPhases.push(function() {
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
    this._initPhases.push(function(args) {
      return init.apply(this, args);
    });
  },
  build: function() {
    var createInstance, didCreate, getCacheId, initArgs, initInstance, type, willCreate;
    initArgs = this.__initArgs(this._argPhases);
    getCacheId = this._getCacheID;
    willCreate = this._willCreate;
    createInstance = this._createInstance;
    initInstance = this.__initInstance(this._initPhases);
    didCreate = this._didCreate;
    type = this.__createType(function() {
      var args, self;
      args = initArgs(arguments);
      if (getCacheId) {
        self = getCacheId.apply(null, args);
        if (self !== void 0) {
          return self;
        }
      }
      willCreate.call(null, type, args);
      self = createInstance.apply(null, args);
      initInstance(self, args);
      didCreate.call(self, type, args);
      return self;
    });
    this.__initType(type, this._typePhases);
    return type;
  }
});

define(Builder.prototype, {
  enumerable: false
}, {
  __initArgs: function(argPhases) {
    if (argPhases.length === 0) {
      return emptyFunction.thatReturnsArgument;
    }
    return function(initialArgs) {
      var arg, args, i, j, len, len1, runPhase;
      args = [];
      for (i = 0, len = initialArgs.length; i < len; i++) {
        arg = initialArgs[i];
        args.push(arg);
      }
      for (j = 0, len1 = argPhases.length; j < len1; j++) {
        runPhase = argPhases[j];
        args = runPhase(args);
      }
      return args;
    };
  },
  __initInstance: function(initPhases) {
    if (initPhases.length === 0) {
      return emptyFunction;
    }
    return function(self, args) {
      var i, len, runPhase;
      for (i = 0, len = initPhases.length; i < len; i++) {
        runPhase = initPhases[i];
        runPhase.apply(self, args);
      }
    };
  },
  __createType: function(type) {
    setKind(type, this._kind);
    return type;
  },
  __initType: function(type, typePhases) {
    var i, len, runPhase;
    if (typePhases.length === 0) {
      return;
    }
    for (i = 0, len = typePhases.length; i < len; i++) {
      runPhase = typePhases[i];
      runPhase(type);
    }
  }
});

if (isDev) {
  isEnumerable = function(key) {
    return key[0] !== "_";
  };
} else {
  isEnumerable = emptyFunction.thatReturnsTrue;
}

createObjectLiteral = function() {
  return {};
};

mergeDefaults = function(options, optionDefaults) {
  var defaultValue, key;
  for (key in optionDefaults) {
    defaultValue = optionDefaults[key];
    if (isObject(defaultValue)) {
      if (options[key] === void 0) {
        options[key] = {};
      }
      options[key] = mergeDefaults(options[key], defaultValue);
    } else if (options[key] === void 0) {
      options[key] = defaultValue;
    }
  }
};

//# sourceMappingURL=../../map/src/Builder.map
