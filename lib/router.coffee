mu = require 'mu2'
path = require 'path'
os = require 'os'
fs = require 'fs'
spawn = require('child_process').spawn
Stream = require('stream').Stream
util = require '../lib/util.coffee'
nginxPath = path.join process.cwd(), 'nginx'
fs.mkdir nginxPath, ->

Router = ->
  @pidpath = path.join process.cwd(), 'pids'
  nginxTempPath = nginxPath if process.env.NGINXLOCALTEMPFILE
  nginxTempPath = process.env.NGINXTEMPPATH if process.env.NGINXTEMPPATH?
  try
    fs.mkdirSync @pidpath
  @buildOpts = (routingTable) =>
    options =
      worker_processes: os.cpus().length
      access_log: path.join(nginxPath, 'access.log')
      error_log: path.join(nginxPath, 'error.log')
      pidfile: path.join(@pidpath, 'nginx.pid')
      temp_path: nginxTempPath if nginxTempPath?
    for name, data of routingTable

      options.server ?= []

      if Array.isArray domain
        domain = data.domain.join ' '
      else
        domain = data.domain

      server =
        domain: domain
        name: name
        directives: []
        location_arguments: []
        client_max_body_size: data.client_max_body_size || '1m'
      server.maintenance = data.maintenance
      if data.directives?
        for directive in data.directives
          server.directives.push {directive: directive}
      if data.location_arguments?
        for argument in data.location_arguments
          server.location_arguments.push {argument: argument}
      options.server.push server

      options.upstream ?= []
      upstream =
        name: name
        method: data.method ? "least_conn"
        routes: []
      for route in data.routes
        upstream.routes.push
          host: route.host
          port: route.port
      options.upstream.push upstream

    return options

  @writeFile = (routingTable, cb) =>
    tableHash = util.hashObj routingTable
    return cb tableHash if tableHash instanceof Error
    return cb null, false if tableHash is @currentHash
    options = @buildOpts routingTable
    options.mimePath = path.resolve(__dirname, '..', 'nginx', 'mime.types')
    mustache = mu.compileAndRender(path.resolve(__dirname, '..', 'nginx', 'nginx.conf.mustache'), options)
    output = fs.createWriteStream path.join(nginxPath, 'nginx.conf')
    mustache.pipe output
    mustache.on 'error', (err) =>
      @currentHash = undefined
      cb err
    output.on 'error', (err) =>
      @currentHash = undefined
      cb err
    output.on 'close', =>
      @currentHash = tableHash
      cb null, true

  @reload = (cb) =>
    #kill is a misnomer, this instructs nginx to re-read it's configuration and gracefully retire it's workers. http://nginx.org/en/docs/control.html
    @nginx.kill 'SIGHUP'
    @emit 'reloading'
    cb()
  @checkStale = (cb) =>
    fs.readFile path.join(@pidpath, 'nginx.pid'), (err, buf) =>
      if err?
        return cb()
      else
        stalePid = parseInt(buf.toString())
        return cb() if !stalePid # In case file is present but empty
        info = spawn 'ps', ['-p', stalePid, '-o', 'comm'] #Check that it's actually an nginx process and not something else
        calledBack = false
        info.stdout.once 'data', (data) ->
          if data.toString().indexOf('nginx') > -1
            process.kill stalePid
          cb() unless calledBack
          calledBack = true
        info.on 'exit', -> # Handles the case where ps returns no data on stdout
          cb() unless calledBack
          calledBack = true
        info.on 'error', (err) ->
          console.error "Err from staleness check", err
  @start = =>
    @checkStale =>
      @writeFile {}, (err) =>
        @nginx = spawn "nginx", ['-c', path.join(nginxPath, 'nginx.conf')]
        @emit 'ready'
        norespawn = false
        @on 'norespawn', ->
          norespawn = true
        @nginx.once 'exit', (code, signal) =>
          @start() unless norespawn
        #@nginx.on 'error', (err) ->
        #  console.error 'nginx error', err
        #@nginx.stderr.on 'data', (data) ->
        #  console.error 'nginx stderr says:', data.toString()
  @start()
  @nginx = null
  @takedown = =>
    @emit 'norespawn'
    @nginx.kill()
  @nginxlogrotate = =>
    files = ['error.log', 'access.log']
    for file in files
      loc = path.join(nginxPath, file)
      do (loc) =>
        fs.stat loc, (err, stat) =>
          return console.error err if err?
          return if !stat?
          if stat.size > process.env.MAXLOGFILESIZE or stat.size > 524288000 #500MB
            fs.rename loc, "#{loc}.1", (err) =>
              return console.error err if err?
              @nginx.kill 'SIGUSR1' #USR1 causes nginx to reopen its logfiles

  setInterval =>
    @nginxlogrotate()
  , 60 * 1000
  return this

Router.prototype = new Stream

router = new Router
module.exports = router
