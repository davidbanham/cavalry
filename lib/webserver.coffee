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
    try
      parsed = JSON.parse optStr
    catch e
      cb e, null
    cb null, parsed

respondJSONerr = (err, res) ->
  res.writeHead 400
  res.end err

server.on 'request', (req, res) ->
  res.setHeader "Access-Control-Allow-Origin", "*"
  res.setHeader "Access-Control-Allow-Headers", req.headers["access-control-request-headers"]
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
      getJSON req, (err, repo) ->
        return respondJSONerr err, res if err?
        gitter.fetch repo.name, repo.url, (err) ->
          res.writeHead 500 if err?
          return res.end err.toString() if err?
          res.end()
    when "/#{util.apiVersion}/stop"
      getJSON req, (err, ids) ->
        return respondJSONerr err, res if err?
        runner.stop ids
        res.end()
    when "/#{util.apiVersion}/restart"
      getJSON req, (err, ids) ->
        return respondJSONerr err, res if err?
        runner.restart ids
        res.end()
    when "/#{util.apiVersion}/spawn"
      getJSON req, (err, opts) ->
        return respondJSONerr err, res if err?
        runner.spawn opts, (processes)->
          res.write JSON.stringify util.clone processes
          res.end()
    when "/#{util.apiVersion}/exec"
      getJSON req, (err, opts) ->
        return respondJSONerr err, res if err?
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
      getJSON req, (err, table) ->
        return respondJSONerr err, res if err?
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
      res.setTimeout 60 * 60 * 1000 # 1 hour
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
      runner.on "error", (err) ->
        res.write "#{info.repo} #{info.id} error - #{err.toString()}"
      gitter.on "deploy", (info) ->
        res.write "#{info.repo} #{info.commit} deploy\r\n"
    when '/apiVersion'
      res.writeHead 200
      res.write util.apiVersion.toString()
      res.end()
    when '/uptime'
      res.writeHead 200
      res.write (new Date() - new Date(runner.started)).toString()
      res.end()
    else
      res.writeHead 404
      res.end "not found"

module.exports = server
