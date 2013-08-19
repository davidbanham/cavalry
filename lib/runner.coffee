path = require 'path'
util = require 'util'
Stream = require('stream').Stream
spawn = require('child_process').spawn
gitter = require('../lib/gitter.coffee')()

Drone = (opts={}) ->
  @processes = {}
  @droneId = 'someId'
  base = process.env.BASEDIR or process.cwd()
  @deploydir = path.resolve(process.env.DEPLOYDIR or path.join(base, 'deploy'))
  return this

Drone.prototype = new Stream

Drone.prototype.spawn = (opts, cb) ->
  id = Math.floor(Math.random() * (1 << 24)).toString(16)
  repo = opts.repo
  commit = opts.commit
  dir = opts.cwd or path.join(@deploydir, repo + "." + commit)
  cmd = opts.command[0]
  args = opts.command.slice 1
  respawn = =>
    env = {}
    env[k] = v for k,v of process.env
    env[k] = v for k,v of opts.env
    innerProcess = spawn cmd, args,
      cwd: dir
      env: env
    @processes[id] =
      id: id
      status: "running"
      repo: repo
      commit: commit
      command: opts.command
      opts: opts
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
      #If it's an ENOENT, try fetching the repo from the master
      console.error "error", err
      if err.code is "ENOENT"
        outerErr = err
        master =
          hostname: process.env.MASTERHOST or "localhost"
          port: process.env.MASTERGITPORT or 4001
          secret: process.env.MASTERPASS or 'testingpass'
        gitter.fetch repo, "http://git:#{master.secret}@#{master.hostname}:#{master.port}/#{repo}/", (err) =>
          gitter.deploy {repo: repo, commit: commit}, (err) =>
            #@emit "error", outerErr,
            #  drone: @droneId
            #  id: id
            #  repo: repo
            #  commit: commit
            respawn()
      else
        #@emit "error", err,
        #  drone: @droneId
        #  id: id
        #  repo: repo
        #  commit: commit

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
drone = new Drone()
module.exports = drone
