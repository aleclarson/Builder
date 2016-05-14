var NamedFunction, Property, assertType, isType;

NamedFunction = require("NamedFunction");

assertType = require("assertType");

Property = require("Property");

isType = require("isType");

module.exports = NamedFunction("PropertyMapper", function(options) {
  return function(createValues) {
    var prop;
    prop = Property(options);
    if (isType(createValues, Function)) {
      this._initInstance(function(args) {
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
    this._initInstance(function(args) {
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
});

//# sourceMappingURL=../../map/src/PropertyMapper.map
