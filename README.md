
# builder v1.0.0 [![experimental](https://img.shields.io/badge/stability-experimental-FF9F2A.svg?style=flat)](https://nodejs.org/api/documentation.html#documentation_stability_index)

The `Builder` class is used to construct any class you can think of.

Using inheritance, you can extend the capabilities of the base `Builder` class.

```coffee
Builder = require "builder"

builder = Builder()

MyType = builder.build()

instance = MyType()
```

#### Create values for each instance

```coffee
builder.createValues ->
  foo: 1
  _bar: 2 # Keys starting with an underscore are non-enumerable!

instance.foo         # => 1
instance._bar        # => 2
Object.keys instance # => [ "foo" ]
```

Variants of this method include:

- **createFrozenValues**: The values are made non-writable and non-configurable.

- **createReactiveValues**: The values are made reactive! :)

#### Define values on the prototype

```coffee
builder.definePrototype
  foo: -> 1
  _bar: -> 2 # Keys starting with an underscore are non-enumerable!

instance.foo()               # => 1
instance._bar()              # => 2
Object.keys MyType.prototype # => [ "foo" ]
```

#### Define values on the type

```coffee
builder.defineStatics
  foo: 1
  _bar: 2 # Keys starting with an underscore are non-enumerable!

MyType.foo         # => 1
MyType._bar        # => 2
Object.keys MyType # => [ "foo" ]
```

-

*More documentation at a later date!*
