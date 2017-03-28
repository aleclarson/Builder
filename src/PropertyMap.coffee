
NamedFunction = require "NamedFunction"
assertType = require "assertType"

PropertyMap = NamedFunction "PropertyMap", ->
  Object.create PropertyMap.prototype,
    _queue: {value: []}

prototype =

  push: (define, values) ->
    assertType define, Function

    if arguments.length is 1
      @_queue.push {create: define}
      return

    if values.constructor is Object
    then @_queue.push {define, values}
    else @_queue.push {define, create: values}
    return

  unshift: (define, values) ->
    assertType define, Function

    if arguments.length is 1
      @_queue.unshift {create: define}
      return

    if values.constructor is Object
    then @_queue.unshift {define, values}
    else @_queue.unshift {define, create: values}
    return

  apply: (obj, args) ->
    for {define, values, create} in @_queue
      values = create.apply obj, args if create
      continue unless values and define
      for key, value of values
        continue if value is undefined
        define obj, key, value
    return

Object.assign PropertyMap.prototype, prototype
module.exports = PropertyMap
