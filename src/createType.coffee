
isDev = require "isDev"

if isDev

  template = """
    return function anonymous() {
      var _c = this === global ? null : this;
      var _a = createArgs(arguments, _c);
      return createInstance(arguments.callee, _a, _c);
    };
  """

  module.exports = (name, createArgs, createInstance) ->
    createType = Function "createInstance", "createArgs", "global", template.replace "anonymous", name
    return createType createInstance, createArgs, global

else

  module.exports = (name, createArgs, createInstance) -> ->
    context = if this is global then null else this
    args = createArgs arguments, context
    return createInstance arguments.callee, args, context
