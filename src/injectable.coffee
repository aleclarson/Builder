
Injectable = require "Injectable"

injectable =
  Event: Injectable()

exports.get = (key) ->
  injectable[key].get()

exports.inject = (key, value) ->
  injectable[key].inject value
