
# Builder v2.2.2 ![stable](https://img.shields.io/badge/stability-stable-4EBA0F.svg?style=flat)

A `Builder` is an extensible interface for building factory functions.

`Builder.prototype` provides basic utilities for defining properties, methods, and much more.

The `Builder` class is designed to be subclassed.
This allows `Builder` instances to be as specialized as you see fit.

```coffee
Builder = require "Builder"

type = Builder "TypeName"
```

&nbsp;

### type.inherits

Sets the superclass.

```coffee
# Create each instance with `{}`
# NOTE: This is the default, so never call `inherits` like this!
type.inherits Object

# Create each instance with `Object.create(null)`
type.inherits null

# Some types are not inheritable.
# The call below will throw an error.
type.inherits Array
```

**TODO**: Write documentation...

&nbsp;

## Subclassing

**TODO**: Write documentation...
