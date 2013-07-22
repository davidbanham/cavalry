path = require 'path'
util = require 'util'
Stream = require('stream').Stream
spawn = require('child_process').spawn

Drone = (opts={}) ->
  @processes = {}
  @droneId = 'someId'
  base = opts.basedir or process.cwd()
  @deploydir = path.resolve(opts.deploydir or path.join(base, 'deploy'))

Drone.prototype = new Stream

Drone.prototype.spawn = (opts, cb) ->
  id = Math.floor(Math.random() * (1 << 24)).toString(16)
  repo = opts.repo
  commit = opts.commit
  dir = opts.cwd or path.join(@deploydir, repo + "." + commit)
  cmd = opts.command[0]
  args = opts.command.slice 1
  respawn = =>
    innerProcess = spawn cmd, args,
      cwd: dir
    @processes[id] =
      id: id
      status: "running"
      repo: repo
      commit: commit
      command: opts.command
      cwd: dir
      process: innerProcess
      respawn: respawn
      drone: @droneId

    innerProcess.stdout.on "data", (buf) =>
      @emit "stdout", buf,
        drone: @droneId
        id: id
        repo: repo
        commit: commit

    innerProcess.stderr.on "data", (buf) =>
      @emit "stderr", buf,
        drone: @droneId
        id: id
        repo: repo
        commit: commit

    innerProcess.on "error", (err) ->
      console.log "error", err
      @emit "error", err,
        drone: @droneId
        id: id
        repo: repo
        commit: commit

    innerProcess.once "exit", (code, signal) =>
      proc = @processes[id]
      @emit "exit", code, signal,
        drone: @droneId
        id: id
        repo: repo
        commit: commit
        command: opts.command

      if opts.once
        delete @processes[id]
      else if proc.status isnt "stopped"
        proc.status = "respawning"
        setTimeout =>
          respawn() if proc.status isnt "stopped"
        , opts.debounce or 1000
    @emit "spawn",
      drone: @droneId
      id: @id
      repo: repo
      commit: commit
      command: opts.command
      cwd: dir
  respawn()
  cb @processes[id] if cb?

Drone.prototype.stop = (ids) ->
  ids = [ ids ] if !Array.isArray(ids)
  for id in ids
    proc = @processes[id]
    return false if !proc?
    @emit "stop", @processes[id]
    proc.status = "stopped"
    proc.process.kill()

Drone.prototype.restart = (ids) ->
  ids = [ ids ] if !Array.isArray(ids)
  for id in ids
    proc = @processes[id]
    return false if !proc?
    @emit "restart", @processes[id]
    proc.process.kill()

module.exports = (opts) ->
  new Drone opts
