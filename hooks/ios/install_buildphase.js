
module.exports = function(context) {
    // make sure ios platform is part of install
    if (context.opts.cordova.platforms.indexOf('ios') < 0) {
        return;
    }

    var fs = context.requireCordovaModule('fs'),
        path = context.requireCordovaModule('path'),
        Q = context.requireCordovaModule('q'),
        xcode = context.requireCordovaModule('xcode'),
        deferral = new Q.defer();

    var iosPlatform = path.join(context.opts.projectRoot, 'platforms/ios/');
    var iosFolder = fs.existsSync(iosPlatform) ? iosPlatform : context.opts.projectRoot;

    console.log("Begin install build phase");

    fs.readdir(iosFolder, function (err, data) {
        if (err) {
            return deferral.reject(err);
        }

        var projFolder;
        var projName;

        // Find the project folder by looking for *.xcodeproj
        if (data && data.length) {
            data.forEach(function (folder) {
                if (folder.match(/\.xcodeproj$/)) {
                    projFolder = path.join(iosFolder, folder);
                    projName = path.basename(folder, '.xcodeproj');
                }
            });
        }

        if (!projFolder || !projName) {
            return deferral.reject("Could not find an .xcodeproj folder in: " + iosFolder);
        }

        var projectPath = path.join(projFolder, 'project.pbxproj');

        var pbxProject;
        if (context.opts.cordova.project) {
            pbxProject = context.opts.cordova.project.parseProjectFile(context.opts.projectRoot).xcode;
        } else {
            pbxProject = xcode.project(projectPath);
            pbxProject.parseSync();
        }

        var phaseComment = 'Strip unneeded architectures';
        var target = pbxProject.getFirstTarget().uuid;
        if(pbxProject.buildPhase(phaseComment, target)) {
            console.log("Build phase already installed");
            return deferral.resolve();
        }

        fs.readFile(path.join(__dirname, 'buildphase.sh'), 'utf8', function(err, shellScript) {
            if(err) {
                return deferral.reject(err);
            }

            var options = {
                shellPath: '/bin/sh', 
                shellScript: shellScript
            };

            pbxProject.addBuildPhase([], 'PBXShellScriptBuildPhase', phaseComment, target, options);
            fs.writeFile(projectPath, pbxProject.writeSync(), 'utf8', function(err) {
                if(err) {
                    return deferral.reject(err);
                }

                deferral.resolve();
                console.log("Finished install build phase");
            });
        });
    });

    return deferral.promise;
};