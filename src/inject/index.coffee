
injectable =
  EventMap: require "./EventMap"

module.exports = (key, value) ->
  injectable[key].inject value
