const child_process = require("child_process");
const q = require("q");

module.exports = function () {
  console.log("Pebble prerequisites");

  var deferral = q.defer();

  var output = child_process.exec('npm install', {cwd: __dirname},
      function (error) {
        if (error !== null) {
          console.log('exec error: ' + error);
          deferral.reject('npm installation failed');
        }
        deferral.resolve();
      });

  return deferral.promise;
};
