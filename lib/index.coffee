
if atom.inDevMode()
  exports.activate = ->
    watcher = require './watcher'
    watcher.start()
    @deactivate = watcher.stop
    @provide = -> watcher.watch
    return
