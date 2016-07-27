var NamedFunction, Property, assertType, isType;

NamedFunction = require("NamedFunction");

assertType = require("assertType");

Property = require("Property");

isType = require("isType");

module.exports = NamedFunction("PropertyMapper", function(options) {
  return function(values) {
    var prop;
    prop = Property(options);
    if (isType(values, Function)) {
      this._initInstance.push(function(args) {
        var instValues, key, value;
        instValues = values.apply(this, args);
        assertType(instValues, Object);
        for (key in instValues) {
          value = instValues[key];
          prop.define(this, key, {
            value: value
          });
        }
      });
      return;
    }
    assertType(values, Object);
    this._initInstance.push(function(args) {
      var key, value;
      for (key in values) {
        value = values[key];
        if (isType(value, Function)) {
          if (value.length) {
            value = value.apply(this, args);
          } else {
            value = value.call(this);
          }
        }
        prop.define(this, key, {
          value: value
        });
      }
    });
  };
});

//# sourceMappingURL=map/PropertyMapper.map
