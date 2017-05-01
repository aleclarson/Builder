// Generated by CoffeeScript 1.12.4
var NamedFunction, PropertyMap, assertType, prototype;

NamedFunction = require("NamedFunction");

assertType = require("assertType");

PropertyMap = NamedFunction("PropertyMap", function() {
  return Object.create(PropertyMap.prototype, {
    _queue: {
      value: []
    }
  });
});

prototype = {
  push: function(define, values) {
    assertType(define, Function);
    if (arguments.length === 1) {
      this._queue.push({
        create: define
      });
      return;
    }
    if (values.constructor === Object) {
      this._queue.push({
        define: define,
        values: values
      });
    } else {
      this._queue.push({
        define: define,
        create: values
      });
    }
  },
  unshift: function(define, values) {
    assertType(define, Function);
    if (arguments.length === 1) {
      this._queue.unshift({
        create: define
      });
      return;
    }
    if (values.constructor === Object) {
      this._queue.unshift({
        define: define,
        values: values
      });
    } else {
      this._queue.unshift({
        define: define,
        create: values
      });
    }
  },
  apply: function(obj, args) {
    var create, define, i, key, len, ref, ref1, value, values;
    ref = this._queue;
    for (i = 0, len = ref.length; i < len; i++) {
      ref1 = ref[i], define = ref1.define, values = ref1.values, create = ref1.create;
      if (create) {
        values = create.apply(obj, args);
      }
      if (!(values && define)) {
        continue;
      }
      for (key in values) {
        value = values[key];
        if (value === void 0) {
          continue;
        }
        define(obj, key, value);
      }
    }
  }
};

Object.assign(PropertyMap.prototype, prototype);

module.exports = PropertyMap;