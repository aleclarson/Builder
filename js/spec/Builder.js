var Builder, describeMode;

Builder = require("../src/Builder");

describeMode = function(name, value, callback) {
  var mode;
  mode = require(name);
  return describe(log.color.cyan(name + " === " + value), function() {
    beforeAll(function() {
      return mode.push(value);
    });
    callback();
    return afterAll(function() {
      return mode.pop();
    });
  });
};

describe("Builder.prototype", function() {
  describe("build()", function() {
    return it("caches the result", function() {
      var type;
      type = Builder();
      return expect(type.build()).toBe(type.build());
    });
  });
  describe("createInstance()", function() {
    return it("determines how the base object is created", function() {
      var Foo, foo, spy, type;
      type = Builder();
      spy = jasmine.createSpy();
      type.createInstance(function(a, b) {
        spy(a, b);
        return function() {
          return spy(a += 1, b += 1);
        };
      });
      Foo = type.build();
      foo = Foo(1, 2);
      foo();
      expect(spy.calls.count()).toBe(2);
      expect(spy.calls.argsFor(0)).toEqual([1, 2]);
      return expect(spy.calls.argsFor(1)).toEqual([2, 3]);
    });
  });
  describe("defineProperties()", function() {
    return it("adds custom properties to each instance", function() {
      var Foo, foo, type;
      type = Builder();
      type.defineProperties({
        test: {
          get: function() {
            return 1;
          }
        }
      });
      Foo = type.build();
      foo = Foo();
      return expect(foo.test).toBe(1);
    });
  });
  describe("definePrototype()", function() {
    return it("adds values to the 'prototype'", function() {
      var Foo, type;
      type = Builder();
      type.definePrototype({
        test: emptyFunction
      });
      Foo = type.build();
      return expect(Foo.prototype.test).toBe(emptyFunction);
    });
  });
  describe("defineStatics()", function() {
    return it("adds values to the type", function() {
      var Foo, type;
      type = Builder();
      type.defineStatics({
        test: emptyFunction
      });
      Foo = type.build();
      return expect(Foo.test).toBe(emptyFunction);
    });
  });
  describe("createValues()", function() {
    return it("adds writable values to each instance", function() {
      var Foo, foo, type;
      type = Builder();
      type.createValues(function() {
        return {
          test: 1
        };
      });
      Foo = type.build();
      foo = Foo();
      expect(foo.test).toBe(1);
      foo.test = 2;
      return expect(foo.test).toBe(2);
    });
  });
  describe("createFrozenValues()", function() {
    return it("adds frozen values to each instance", function() {
      var Foo, foo, type;
      type = Builder();
      type.createFrozenValues(function() {
        return {
          test: 1
        };
      });
      Foo = type.build();
      foo = Foo();
      return expect(foo.test).toBe(1);
    });
  });
  describe("createReactiveValues()", function() {
    return it("adds reactive values to each instance", function() {
      var Foo, Tracker, computation, foo, spy, type;
      Tracker = require("tracker");
      type = Builder();
      type.createReactiveValues(function() {
        return {
          test: 1
        };
      });
      Foo = type.build();
      foo = Foo();
      spy = jasmine.createSpy();
      computation = Tracker.autorun((function(_this) {
        return function() {
          return spy(foo.test);
        };
      })(this));
      computation._sync = true;
      expect(spy.calls.argsFor(0)).toEqual([1]);
      foo.test = 2;
      expect(spy.calls.argsFor(1)).toEqual([2]);
      return computation.stop();
    });
  });
  describe("bindMethods()", function() {
    return it("binds a method to each instance", function() {
      var Foo, foo, test, type;
      type = Builder();
      type.definePrototype({
        test: function() {
          return this;
        }
      });
      type.bindMethods(["test"]);
      Foo = type.build();
      foo = Foo();
      expect(foo.test).not.toBe(Foo.prototype.test);
      expect(foo.test()).toBe(foo);
      test = foo.test;
      return expect(test()).toBe(foo);
    });
  });
  describe("exposeGetters()", function() {
    return it("creates a getter for a hidden key", function() {
      var Foo, foo, type;
      type = Builder();
      type.createValues(function() {
        return {
          _test: 1
        };
      });
      type.exposeGetters(["test"]);
      Foo = type.build();
      foo = Foo();
      expect(foo.test).toBe(1);
      return expect(function() {
        return foo.test = 2;
      }).toThrowError("'test' is not writable.");
    });
  });
  describe("exposeLazyGetters()", function() {
    return it("creates a getter for a hidden key with a value that has a 'get()' method", function() {
      var Foo, LazyVar, foo, type;
      LazyVar = require("lazy-var");
      type = Builder();
      type.createValues(function() {
        return {
          _test: LazyVar(function() {
            return 1;
          })
        };
      });
      type.exposeLazyGetters(["test"]);
      Foo = type.build();
      foo = Foo();
      expect(foo.test).toBe(1);
      return expect(function() {
        return foo.test = 2;
      }).toThrowError("'test' is not writable.");
    });
  });
  describe("addMixins()", function() {
    return it("passes the Builder to a function for modification before building", function() {
      var Foo, foo, mixin, type;
      type = Builder();
      mixin = function(type) {
        return type.createValues(function() {
          return {
            test: 1
          };
        });
      };
      type.addMixins([mixin]);
      Foo = type.build();
      foo = Foo();
      return expect(foo.test).toBe(1);
    });
  });
  describe("init()", function() {
    it("runs a function somewhere in each instance's initialization phase", function() {
      var Foo, foo, spy, type;
      type = Builder();
      type.init(spy = jasmine.createSpy());
      Foo = type.build();
      foo = Foo();
      return expect(spy.calls.count()).toBe(1);
    });
    it("can be called multiple times", function() {
      var Foo, foo, spy, type;
      type = Builder();
      type.init(spy = jasmine.createSpy());
      type.init(spy);
      Foo = type.build();
      foo = Foo();
      return expect(spy.calls.count()).toBe(2);
    });
    return it("can be interleaved with other initialization methods", function() {
      var Foo, foo, type;
      type = Builder();
      type.init(function() {
        return expect(this.test).toBe(void 0);
      });
      type.createValues(function() {
        return {
          test: 1
        };
      });
      type.init(function() {
        return expect(this.test).toBe(1);
      });
      Foo = type.build();
      return foo = Foo();
    });
  });
  describeMode("isDev", true, function() {
    describe("defineProperties()", function() {
      return it("hides keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.defineProperties({
          _test: {
            value: 1
          }
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual([]);
      });
    });
    describe("definePrototype()", function() {
      return it("hides keys that begin with '_'", function() {
        var Foo, type;
        type = Builder();
        type.definePrototype({
          _test: emptyFunction
        });
        Foo = type.build();
        return expect(Object.keys(Foo.prototype)).toEqual([]);
      });
    });
    describe("defineStatics()", function() {
      return it("hides keys that begin with '_'", function() {
        var Foo, type;
        type = Builder();
        type.defineStatics({
          _test: emptyFunction
        });
        Foo = type.build();
        return expect(Object.keys(Foo)).toEqual([]);
      });
    });
    describe("createValues()", function() {
      return it("hides keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.createValues(function() {
          return {
            _test: 1
          };
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual([]);
      });
    });
    describe("createFrozenValues()", function() {
      var foo;
      foo = null;
      beforeAll(function() {
        var Foo, type;
        type = Builder();
        type.createFrozenValues(function() {
          return {
            test: 1,
            _test: 1
          };
        });
        Foo = type.build();
        return foo = Foo();
      });
      it("throws when writing the value", function() {
        expect(foo.test).toBe(1);
        return expect(function() {
          return foo.test = 2;
        }).toThrowError("'test' is not writable.");
      });
      it("throws when redefining the value", function() {
        return expect(function() {
          return Object.defineProperty(foo, "test", {
            value: 1,
            writable: true
          });
        }).toThrowError("Cannot redefine property: test");
      });
      return it("hides keys that begin with '_'", function() {
        expect(foo._test).toBe(1);
        return expect(Object.keys(foo)).toEqual(["test"]);
      });
    });
    return describe("createReactiveValues()", function() {
      return it("hides keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.createReactiveValues(function() {
          return {
            _test: 1
          };
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual([]);
      });
    });
  });
  return describeMode("isDev", false, function() {
    describe("defineProperties()", function() {
      return it("shows keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.defineProperties({
          _test: {
            value: 1
          }
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual(["_test"]);
      });
    });
    describe("definePrototype()", function() {
      return it("shows keys that begin with '_'", function() {
        var Foo, type;
        type = Builder();
        type.definePrototype({
          _test: emptyFunction
        });
        Foo = type.build();
        return expect(Object.keys(Foo.prototype)).toEqual(["_test"]);
      });
    });
    describe("defineStatics()", function() {
      return it("shows keys that begin with '_'", function() {
        var Foo, type;
        type = Builder();
        type.defineStatics({
          _test: emptyFunction
        });
        Foo = type.build();
        return expect(Object.keys(Foo)).toEqual(["_test"]);
      });
    });
    describe("createValues()", function() {
      return it("shows keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.createValues(function() {
          return {
            _test: 1
          };
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual(["_test"]);
      });
    });
    describe("createFrozenValues()", function() {
      var foo;
      foo = null;
      beforeAll(function() {
        var Foo, type;
        type = Builder();
        type.createFrozenValues(function() {
          return {
            test: 1,
            _test: 1
          };
        });
        Foo = type.build();
        return foo = Foo();
      });
      it("allows writing the value", function() {
        expect(function() {
          return foo.test = 2;
        }).not.toThrow();
        return expect(foo.test).toBe(2);
      });
      it("allows redefining the value", function() {
        expect(function() {
          return Object.defineProperty(foo, "test", {
            value: 1,
            writable: true
          });
        }).not.toThrow();
        foo.test = 2;
        return expect(foo.test).toBe(2);
      });
      return it("shows keys that begin with '_'", function() {
        return expect(Object.keys(foo)).toEqual(["test", "_test"]);
      });
    });
    return describe("createReactiveValues()", function() {
      return it("shows keys that begin with '_'", function() {
        var Foo, foo, type;
        type = Builder();
        type.createReactiveValues(function() {
          return {
            _test: 1
          };
        });
        Foo = type.build();
        foo = Foo();
        return expect(Object.keys(foo)).toEqual(["_test"]);
      });
    });
  });
});

//# sourceMappingURL=../../map/spec/Builder.map
