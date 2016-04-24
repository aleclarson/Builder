
Builder = require "../src/Builder"

describeMode = (name, value, callback) ->
  mode = require name
  describe log.color.cyan(name + " === " + value), ->
    beforeAll -> mode.push value
    callback()
    afterAll -> mode.pop()

describe "Builder.prototype", ->

  describe "build()", ->

    it "caches the result", ->

      type = Builder()

      expect type.build()
        .toBe type.build()

  describe "createInstance()", ->

    it "determines how the base object is created", ->

      type = Builder()

      spy = jasmine.createSpy()
      type.createInstance (a, b) ->
        spy a, b
        return ->
          spy a += 1, b += 1

      Foo = type.build()

      foo = Foo 1, 2
      foo()

      expect spy.calls.count()
        .toBe 2

      expect spy.calls.argsFor 0
        .toEqual [ 1, 2 ]

      expect spy.calls.argsFor 1
        .toEqual [ 2, 3 ]

  describe "defineProperties()", ->

    it "adds custom properties to each instance", ->

      type = Builder()
      type.defineProperties { test: { get: -> 1 } }
      Foo = type.build()
      foo = Foo()

      expect foo.test
        .toBe 1

  describe "defineMethods()", ->

    it "adds values to the 'prototype'", ->

      type = Builder()
      type.defineMethods { test: emptyFunction }
      Foo = type.build()

      expect Foo::test
        .toBe emptyFunction

  describe "defineStatics()", ->

    it "adds values to the type", ->

      type = Builder()
      type.defineStatics { test: emptyFunction }
      Foo = type.build()

      expect Foo.test
        .toBe emptyFunction

  describe "defineValues()", ->

    it "adds writable values to each instance", ->

      type = Builder()
      type.defineValues -> { test: 1 }
      Foo = type.build()
      foo = Foo()

      expect foo.test
        .toBe 1

      foo.test = 2
      expect foo.test
        .toBe 2

  describe "defineFrozenValues()", ->

    it "adds frozen values to each instance", ->

      type = Builder()
      type.defineFrozenValues -> { test: 1 }
      Foo = type.build()
      foo = Foo()

      expect foo.test
        .toBe 1

  describe "defineReactiveValues()", ->

    it "adds reactive values to each instance", ->

      Tracker = require "tracker"

      type = Builder()

      type.defineReactiveValues -> { test: 1 }

      Foo = type.build()

      foo = Foo()

      spy = jasmine.createSpy()
      computation = Tracker.autorun => spy foo.test
      computation._sync = yes

      expect spy.calls.argsFor 0
        .toEqual [ 1 ]

      foo.test = 2

      expect spy.calls.argsFor 1
        .toEqual [ 2 ]

      computation.stop()

  describe "bindMethods()", ->

    it "binds a method to each instance", ->

      type = Builder()

      type.defineMethods { test: -> this }

      type.bindMethods [ "test" ]

      Foo = type.build()

      foo = Foo()

      expect foo.test
        .not.toBe Foo::test

      expect foo.test()
        .toBe foo

      test = foo.test
      expect test()
        .toBe foo

  describe "exposeGetters()", ->

    it "creates a getter for a hidden key", ->

      type = Builder()

      type.defineValues -> { _test: 1 }

      type.exposeGetters [ "test" ]

      Foo = type.build()

      foo = Foo()

      expect foo.test
        .toBe 1

      expect -> foo.test = 2
        .toThrowError "'test' is not writable."

  describe "exposeLazyGetters()", ->

    it "creates a getter for a hidden key with a value that has a 'get()' method", ->

      LazyVar = require "lazy-var"

      type = Builder()

      type.defineValues -> { _test: LazyVar -> 1 }

      type.exposeLazyGetters [ "test" ]

      Foo = type.build()

      foo = Foo()

      expect foo.test
        .toBe 1

      expect -> foo.test = 2
        .toThrowError "'test' is not writable."

  describe "addMixins()", ->

    it "passes the Builder to a function for modification before building", ->

      type = Builder()

      mixin = (type) ->
        type.defineValues -> { test: 1 }

      type.addMixins [ mixin ]

      Foo = type.build()

      foo = Foo()

      expect foo.test
        .toBe 1

  describe "init()", ->

    it "runs a function somewhere in each instance's initialization phase", ->

      type = Builder()

      type.init spy = jasmine.createSpy()

      Foo = type.build()

      foo = Foo()

      expect spy.calls.count()
        .toBe 1

    it "can be called multiple times", ->

      type = Builder()

      type.init spy = jasmine.createSpy()

      type.init spy

      Foo = type.build()

      foo = Foo()

      expect spy.calls.count()
        .toBe 2

    it "can be interleaved with other initialization methods", ->

      type = Builder()

      type.init ->
        expect @test
          .toBe undefined

      type.defineValues -> { test: 1 }

      type.init ->
        expect @test
          .toBe 1

      Foo = type.build()

      foo = Foo()

  describeMode "isDev", no, ->

    describe "defineFrozenValues()", ->

      foo = null

      beforeAll ->
        type = Builder()
        type.defineFrozenValues -> { test: 1, _test: 1 }
        Foo = type.build()
        foo = Foo()

      it "allows writing the value", ->

        expect -> foo.test = 2
          .not.toThrow()

        expect foo.test
          .toBe 2

      it "allows redefining the value", ->

        expect -> Object.defineProperty foo, "test", { value: 1, writable: yes }
          .not.toThrow()

        foo.test = 2

        expect foo.test
          .toBe 2
