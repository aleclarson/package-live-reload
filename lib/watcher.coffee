{CompositeDisposable} = require 'atom'
path = require 'path'
sock = require 'wch/sock'
wch = require 'wch'
fs = require 'fs'

{packages} = atom

subs = null
streams = new Map
registry = new Map
projectPaths = null

registerPackage = (name, opts) ->
  pack = packages.getLoadedPackage name
  packPath = fs.realpathSync pack.path
  registry.set packPath, [name, opts]

  if global.DEBUG
    console.log 'Package activated:', name

  if sock.connected and inActiveProject packPath
    unwatchPackage name
    watchPackage name, opts
    return

watchPackage = (name, opts) ->
  pack = packages.getLoadedPackage name
  packPath = fs.realpathSync pack.path

  reloading = false
  stream = wch.stream packPath, opts

  .on 'data', debounce 100, ->
    return if reloading
    reloading = true
    reloadPackage name
    .then -> reloading = false

  # Report any errors.
  .on 'error', (err) ->
    console.error err.stack

  streams.set name, stream
  if global.DEBUG
    console.log 'Watching package: ' + name
    return

inActiveProject = (packPath) ->
  for projectPath in projectPaths
    name = path.relative projectPath, packPath
    return true if name.slice(0, 2) isnt '..'
  return false

debounce = (delay, fn) ->
  timer = null
  return ->
    clearTimeout timer
    timer = setTimeout fn, delay
    return

reloadPackage = (name) ->
  console.log 'Reloading package:', name
  pack = packages.getLoadedPackage name
  packages.deactivatePackage(name).then ->
    unloadModules pack.mainModulePath, pack.path
    packages.unloadPackage name
    packages.activatePackage name

refreshPackages = ->
  self = 'package-live-reload'
  packages.getActivePackages().forEach (pack) ->
    return if pack.name is self
    packPath = fs.realpathSync pack.path
    if inActiveProject packPath
      reloadPackage pack.name

unloadModules = (main, root) ->

  paths = new Set
  unloadModule = (mod) ->
    return if paths.has mod.id
    name = path.relative root, mod.id
    return if name.slice(0, 3) is '../'

    if global.DEBUG
      console.log 'Unloading module:', mod.id

    paths.add mod.id
    mod.children.forEach unloadModule
    delete require.cache[mod.id]

  if main = require.cache[main]
    unloadModule main
    return

unwatchPackage = (name) ->
  if stream = streams.get name
    endStream stream, name
    if global.DEBUG
      console.log 'Unwatching package:', name
      return

unregisterPackage = (pack) ->
  if global.DEBUG
    console.log 'Package deactivated:', pack.name
  packPath = fs.realpathSync pack.path
  registry.delete packPath
  unwatchPackage pack.name

setProjects = (paths) ->
  projectPaths = paths

  # End streams of packages no longer open.
  streams.forEach (stream, name) ->
    packPath = packages.resolvePackagePath name
    unless inActiveProject packPath
      endStream stream, name
      if global.DEBUG
        console.log 'Unwatching package:', name
        return

  # Start streams for newly opened packages.
  startPendingStreams()

startPendingStreams = ->
  registry.forEach (args, packPath) ->
    return if streams.has args[0]
    if inActiveProject packPath
      watchPackage.apply null, args

endStream = (stream, name) ->
  streams.delete name
  stream.destroy()
  return

# If the wch server is started after package-live-reload
# is activated, we need to start the streams once connected.
sock.on 'connect', startPendingStreams

module.exports =
  watch: registerPackage

  start: ->
    subs = new CompositeDisposable
    subs.add atom.commands.add 'atom-text-editor',
      'package-live-reload:refresh': refreshPackages
    subs.add packages.onDidDeactivatePackage unregisterPackage
    subs.add atom.project.onDidChangePaths setProjects
    projectPaths = atom.project.getPaths()

    # Watch myself.
    registerPackage 'package-live-reload',
      include: ['lib/**/*.coffee', 'package.json']

    # Connect to wch.
    sock.connect()

  stop: ->
    registry.clear()
    streams.forEach endStream
    subs.dispose()
    subs = null
    return
