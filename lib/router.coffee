mu = require 'mu2'
path = require 'path'
os = require 'os'
fs = require 'fs'
spawn = require('child_process').spawn
Stream = require('stream').Stream
nginxPath = path.resolve 'nginx'

Router = ->
  @pidpath = path.resolve './pids'
  fs.mkdir @pidpath, ->
  @buildOpts = (routingTable) =>
    options =
      worker_processes: os.cpus().length
      access_log: path.join(nginxPath, 'access.log')
      error_log: path.join(nginxPath, 'error.log')
      pidfile: path.join(@pidpath, 'nginx.pid')
    for name, data of routingTable

      options.server ?= []
      server =
        domain: data.domain
        name: name
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
    options = @buildOpts routingTable
    mustache = mu.compileAndRender(path.resolve(nginxPath, 'nginx.conf.mustache'), options)
    output = fs.createWriteStream path.resolve(nginxPath, 'nginx.conf')
    mustache.pipe output
    mustache.on 'error', (err) ->
      cb err
    output.on 'error', (err) ->
      cb err
    output.on 'close', ->
      cb null

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
        info = spawn 'ps', ['-p', stalePid, '-o', 'comm'] #Check that it's actually an nginx process and not something else
        info.stdout.once 'data', (data) ->
          if data.toString().indexOf('nginx') > -1
            process.kill stalePid
          cb()
  @start = =>
    @checkStale =>
      @writeFile {}, (err) =>
        @nginx = spawn "nginx", ['-c', path.resolve(nginxPath, 'nginx.conf')]
        @emit 'ready'
        norespawn = false
        @on 'norespawn', ->
          norespawn = true
        @nginx.once 'exit', (code, signal) =>
          @start() unless norespawn
  @start()
  @nginx = null
  @takedown = =>
    @emit 'norespawn'
    @nginx.kill()
  @nginxlogrotate = =>
    files = ['error.log', 'access.log']
    for file in files
      loc = path.join(__dirname, 'nginx', file)
      do (loc) =>
        fs.stat loc, (err, stat) =>
          if stat.size > process.env.MAXLOGFILESIZE or 524288000 #500MB
            fs.rename loc, "#{loc}.1", (err) =>
              return console.error err if err?
              @nginx.kill 'USR1' #USR1 causes nginx to reopen its logfiles

  setInterval =>
    @nginxlogrotate()
  , 60 * 1000
  return this

Router.prototype = new Stream

router = new Router
module.exports = router
