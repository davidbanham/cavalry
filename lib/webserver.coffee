http = require 'http'
qs = require "querystring"
url = require 'url'
server = http.createServer()
gitter = require('../lib/gitter')()
runner = require('../lib/runner')
porter = require('../lib/porter')
router = require('../lib/router')
util = require ('../lib/util')

porter.neverTwice = true # Don't return the same port twice

SECRET = process.env.SECRET or "testingpass"

getJSON = (req, cb) ->
  optStr = ""
  req.on "data", (buf) ->
    optStr += buf.toString()
  req.on "end", ->
    cb JSON.parse optStr

server.on 'request', (req, res) ->
  if !req.headers.authorization?
    res.writeHead 401
    return res.end "auth required"
  authArray = new Buffer(req.headers.authorization.split(' ')[1], 'base64').toString('ascii').split(':')
  if authArray[1] isnt SECRET
    res.writeHead 401
    return res.end "wrong secret"

  parsed = url.parse(req.url, true)
  switch parsed.pathname
    when "/health"
      res.end "ok"
    when "/ps"
      res.setHeader "Content-Type", "application/json"
      ps = util.clone runner.processes
      delete proc.process for _, proc of ps
      res.write JSON.stringify ps, null, 2
      res.end()
    when "/fetch"
      getJSON req, (repo) ->
        gitter.fetch repo.name, repo.url, (err) ->
          res.writeHead 500 if err?
          return res.end err.toString() if err?
          res.end()
    when "/deploy"
      getJSON req, (opts) ->
        gitter.deploy opts, (err, action) ->
          res.writeHead 500 if err?
          res.end "#{err or ''}, #{action}"
    when "/stop"
      getJSON req, (ids) ->
        runner.stop ids
        res.end()
    when "/restart"
      getJSON req, (ids) ->
        runner.restart ids
        res.end()
    when "/spawn"
      getJSON req, (opts) ->
        runner.spawn opts, (processes)->
          res.write JSON.stringify util.clone processes
          res.end()
    when "/exec"
      getJSON req, (opts) ->
        unless opts.once
          res.writeHead 400
          return res.end()
        res.setHeader "Content-Type", "application/json"
        runner.spawn opts, (proc) ->
          output =
            stdout: []
            stderr: []
          proc.process.stdout.on 'data', (buf) ->
            output.stdout.push buf.toString()
          proc.process.stderr.on 'data', (buf) ->
            output.stderr.push buf.toString()
          proc.process.on 'close', (code, signal) ->
            output.code = code
            output.signal = signal
            res.end JSON.stringify output
    when "/routingTable"
      getJSON req, (table) ->
        router.writeFile table, (err, action) ->
          throw new Error err if err?
          router.reload ->
            res.end()
    when "/port"
      porter.getPort (err, port) ->
        res.setHeader "Content-Type", "application/json"
        res.write JSON.stringify
          port: port
        res.end()
    when "/monitor"
      res.writeHead 200
      res.write "Monitoring #{runner.slaveId}\r\n"
      runner.on "stdout", (buf, info) ->
        res.write "#{info.repo} #{info.id} - #{buf.toString()}\r\n"
      runner.on "stderr", (buf, info) ->
        res.write "#{info.repo} #{info.id} - #{buf.toString()}\r\n"
      runner.on "spawn", (info) ->
        res.write "#{info.repo} #{info.id} spawn\r\n"
      runner.on "stop", (info) ->
        res.write "#{info.repo} #{info.id} stop\r\n"
      runner.on "restart", (info) ->
        res.write "#{info.repo} #{info.id} restart\r\n"
      runner.on "exit", (code, signal, info) ->
        str = "#{info.repo} exited with code #{code}"
        str += " from signal #{signal}" if signal?
        res.write str+"\r\n"
      gitter.on "deploy", (info) ->
        res.write "#{info.repo} #{info.commit} deploy\r\n"
    else
      res.writeHead 404
      res.end "not found"

module.exports = server
