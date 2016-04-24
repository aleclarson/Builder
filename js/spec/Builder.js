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
  describe("defineMethods()", function() {
    return it("adds values to the 'prototype'", function() {
      var Foo, type;
      type = Builder();
      type.defineMethods({
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
  describe("defineValues()", function() {
    return it("adds writable values to each instance", function() {
      var Foo, foo, type;
      type = Builder();
      type.defineValues(function() {
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
  describe("defineFrozenValues()", function() {
    return it("adds frozen values to each instance", function() {
      var Foo, foo, type;
      type = Builder();
      type.defineFrozenValues(function() {
        return {
          test: 1
        };
      });
      Foo = type.build();
      foo = Foo();
      return expect(foo.test).toBe(1);
    });
  });
  describe("defineReactiveValues()", function() {
    return it("adds reactive values to each instance", function() {
      var Foo, Tracker, computation, foo, spy, type;
      Tracker = require("tracker");
      type = Builder();
      type.defineReactiveValues(function() {
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
      type.defineMethods({
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
      type.defineValues(function() {
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
      type.defineValues(function() {
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
        return type.defineValues(function() {
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
      type.defineValues(function() {
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
  return describeMode("isDev", false, function() {
    return describe("defineFrozenValues()", function() {
      var foo;
      foo = null;
      beforeAll(function() {
        var Foo, type;
        type = Builder();
        type.defineFrozenValues(function() {
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
      return it("allows redefining the value", function() {
        expect(function() {
          return Object.defineProperty(foo, "test", {
            value: 1,
            writable: true
          });
        }).not.toThrow();
        foo.test = 2;
        return expect(foo.test).toBe(2);
      });
    });
  });
});

//# sourceMappingURL=../../map/spec/Builder.map
