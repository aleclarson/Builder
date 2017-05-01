
isDev = require "isDev"

if isDev
  module.exports = do ->

    template = """
      return function anonymous() {
        var args = createArgs(arguments, this);
        return createInstance(arguments.callee, args, this);
      };
    """

    return (name, createArgs, createInstance) ->
      createType = Function "createInstance", "createArgs", template.replace "anonymous", name
      return createType createInstance, createArgs

else
  module.exports = (name, createArgs, createInstance) -> ->
    args = createArgs arguments, this
    return createInstance arguments.callee, args, this
