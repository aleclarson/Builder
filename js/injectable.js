var Injectable, injectable;

Injectable = require("Injectable");

injectable = {
  Event: Injectable()
};

exports.get = function(key) {
  return injectable[key].get();
};

exports.inject = function(key, value) {
  return injectable[key].inject(value);
};

//# sourceMappingURL=map/injectable.map
