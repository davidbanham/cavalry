path = require 'path'
util = require 'util'
Stream = require('stream').Stream
spawn = require('child_process').spawn
exec = require('child_process').exec
fs = require 'fs'
gitter = require('../lib/gitter.coffee')()

Slave = (opts={}) ->
  @processes = {}
  @slaveId = process.env.SLAVEID or "slave-#{Math.floor(Math.random() * (1 << 24)).toString(16)}"
  base = process.env.BASEDIR or process.cwd()
  @deploydir = path.resolve(process.env.DEPLOYDIR or path.join(base, 'deploy'))
  return this

Slave.prototype = new Stream

Slave.prototype.spawn = (opts, cb) ->
  id = opts.testingPid or Math.floor(Math.random() * (1 << 24)).toString(16)
  repo = opts.repo
  commit = opts.commit
  dir = opts.cwd or path.join(@deploydir, "#{repo}.#{id}.#{commit}")
  cmd = opts.command[0]
  args = opts.command.slice 1
  generateEnv = (supp) ->
    env = {}
    env[k] = v for k,v of process.env
    env[k] = v for k,v of opts.env
    return env

  respawn = =>
    env = generateEnv(opts.env)
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
      slave: @slaveId

    innerProcess.stdout.on "data", (buf) =>
      @emit "stdout", buf,
        slave: @slaveId
        id: id
        repo: repo
        commit: commit

    innerProcess.stderr.on "data", (buf) =>
      @emit "stderr", buf,
        slave: @slaveId
        id: id
        repo: repo
        commit: commit

    innerProcess.on "error", (err) =>
      #If it's an ENOENT, try fetching the repo from the master
      if err.code is "ENOENT"
        innerOpts = {pid: opts.id, name: opts.repo, commit: opts.commit}
        gitter.deploy innerOpts, (err) =>
          if err?
            return @emitErr "error", err,
              slave: @slaveId
              id: id
              repo: repo
              commit: commit
          gitter.check innerOpts, (err, complete) =>
            if err?
              return @emitErr "error", err,
                slave: @slaveId
                id: id
                repo: repo
                commit: commit
              return cb {}
            if !complete
              @emitErr "error", new Error('checkout incomplete'),
                slave: @slaveId
                id: id
                repo: repo
                commit: commit
              return cb {}
            respawn()
      else
        @emitErr "error", err,
          slave: @slaveId
          id: id
          repo: repo
          commit: commit

    innerProcess.once "exit", (code, signal) =>
      proc = @processes[id]
      @emit "exit", code, signal,
        slave: @slaveId
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
      else if proc.status is "stopped"
        delete @processes[id]

    @emit "spawn",
      slave: @slaveId
      id: id
      repo: repo
      commit: commit
      command: opts.command
      cwd: dir
  deployOpts =
    pid: id
    name: repo
    commit: commit
  fs.exists dir, (exists) =>
    if exists #this will probably only occur in testing
      runSetup()
    else
      gitter.deploy deployOpts, (err, actionTaken) =>
        if err?
          @emitErr "error", err,
            slave: @slaveId
            id: id
            repo: repo
            commit: commit
          return cb {}
        gitter.check deployOpts, (err, complete) =>
          if err?
            @emitErr "error", err,
              slave: @slaveId
              id: id
              repo: repo
              commit: commit
            return cb {}
          if !complete
            @emitErr "error", new Error('checkout incomplete'),
              slave: @slaveId
              id: id
              repo: repo
              commit: commit
            return cb {}
          runSetup()
  runSetup = =>
    if opts.setup? and Array.isArray(opts.setup)
      exec opts.setup.join(' '), {cwd: dir, env: generateEnv(opts.env)}, (err, stdout, stderr) =>
        if err?
          @emitErr "error", err,
            slave: @slaveId
            id: id
            repo: repo
            commit: commit
        if err?
          return cb {}
        @emit "setupComplete", {stdout: stdout, stderr: stderr},
          slave: @slaveId
          id: id
          repo: repo
          commit: commit
        firstSpawn()
    else
      firstSpawn()

  firstSpawn = =>
    respawn()
    cb @processes[id] if cb?

Slave.prototype.deploy = (opts, cb) =>
  innerOpts = {pid: opts.id, name: opts.repo, commit: opts.commit}
  gitter.deploy innerOpts, (err) ->
    return cb err if err
    gitter.check innerOpts, (err, complete) ->
      return cb err if err
      return cb new Error('checkout incomplete') if !complete
      cb null

Slave.prototype.stop = (ids) ->
  ids = [ ids ] if !Array.isArray(ids)
  for id in ids
    proc = @processes[id]
    return false if !proc?
    @emit "stop", @processes[id]
    proc.status = "stopped"
    proc.process.kill()

Slave.prototype.restart = (ids) ->
  ids = [ ids ] if !Array.isArray(ids)
  for id in ids
    proc = @processes[id]
    return false if !proc?
    @emit "restart", @processes[id]
    proc.process.kill()

Slave.prototype.emitErr = ->
  if @listeners('error').length > 0
    @emit.apply this, arguments

Slave.prototype.started = new Date().toISOString()

slave = new Slave()
module.exports = slave
