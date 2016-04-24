var ArrayOf, Builder, NamedFunction, Null, Property, assert, assertType, createValueDefiner, define, emptyFunction, isType, ref, setKind, setType, sync, validateTypes;

require("isDev");

ref = require("type-utils"), Null = ref.Null, ArrayOf = ref.ArrayOf, isType = ref.isType, setType = ref.setType, setKind = ref.setKind, assert = ref.assert, assertType = ref.assertType, validateTypes = ref.validateTypes;

NamedFunction = require("NamedFunction");

emptyFunction = require("emptyFunction");

Property = require("Property");

define = require("define");

sync = require("sync");

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
      build: [],
      initType: [],
      initInstance: []
    };
  }
});

define(Builder.prototype, {
  build: function() {
    var constructType, i, len, phase, ref1, transformArgs, type;
    if (this._cachedBuild) {
      return this._cachedBuild;
    }
    if (this._phases.build.length) {
      ref1 = this._phases.build;
      for (i = 0, len = ref1.length; i < len; i++) {
        phase = ref1[i];
        phase.call(this);
      }
    }
    transformArgs = this.__createArgTransformer();
    constructType = this.__createConstructor();
    type = this.__createType(function() {
      return constructType(type, transformArgs(arguments));
    });
    this.__initType(type);
    this._cachedBuild = type;
    return type;
  },
  addMixins: function(mixins) {
    var i, len, mixin;
    assertType(mixins, Array);
    for (i = 0, len = mixins.length; i < len; i++) {
      mixin = mixins[i];
      mixin(this);
    }
  },
  createInstance: function(createInstance) {
    assertType(createInstance, Function);
    this._createInstance = function(args) {
      return createInstance.apply(null, args);
    };
  },
  init: function(init) {
    assertType(init, Function);
    this._phases.initInstance.push(function(args) {
      return init.apply(this, args);
    });
  }
});

createValueDefiner = function(options) {
  return function(createValues) {
    var prop;
    prop = Property(options);
    if (isType(createValues, Function)) {
      this._phases.initInstance.push(function(args) {
        var key, value, values;
        values = createValues.apply(this, args);
        assertType(values, Object);
        for (key in values) {
          value = values[key];
          prop.define(this, key, value);
        }
      });
      return;
    }
    assertType(createValues, Object);
    this._phases.initInstance.push(function(args) {
      var key, value;
      for (key in createValues) {
        value = createValues[key];
        if (isType(value, Function)) {
          if (value.length) {
            prop.define(this, key, value.apply(this, args));
          } else {
            prop.define(this, key, value.call(this));
          }
        } else {
          prop.define(this, key, value);
        }
      }
    });
  };
};

define(Builder.prototype, {
  defineValues: createValueDefiner({
    needsValue: true
  }),
  defineFrozenValues: createValueDefiner({
    frozen: true,
    needsValue: true
  }),
  defineReactiveValues: createValueDefiner({
    reactive: true,
    needsValue: true
  }),
  defineProperties: function(props) {
    assertType(props, Object);
    props = sync.map(props, Property);
    this._phases.initInstance.push(function() {
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
    this._phases.initType.push(function(type) {
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
    this._phases.initType.push(function(type) {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(type, key);
      }
    });
  },
  bindMethods: function(keys) {
    assert(isType(keys, ArrayOf(String)), "'bindMethods' must be passed an array of strings!");
    this._phases.initInstance.push(function() {
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
    this._phases.initInstance.push(function() {
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
    this._phases.initInstance.push(function() {
      var key, prop;
      for (key in props) {
        prop = props[key];
        prop.define(this, key);
      }
    });
  }
});

define(Builder.prototype, {
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
    var i, len, phase, phases;
    phases = this._phases.initType;
    if (phases.length) {
      for (i = 0, len = phases.length; i < len; i++) {
        phase = phases[i];
        phase.call(null, type);
      }
    }
  }
});

//# sourceMappingURL=../../map/src/Builder.map
