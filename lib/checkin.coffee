WebSocket = require 'ws'
runner = require('../lib/runner')
util = require('../lib/util')

Checkin = (innerOpts={})->
  @opts =
    hostname: process.env.MASTERHOST or "localhost"
    port: process.env.MASTERPORT or 4000
    secret: process.env.MASTERPASS or 'testingpass'
  @innerOpts = innerOpts
  @shouldRetryCheckin = true
  return this

Checkin.prototype.setRetry = (state) ->
  @shouldRetryCheckin = state

Checkin.prototype.startCheckin = ->
  checkinMessage = =>
    JSON.stringify
      secret: @opts.secret
      type: "checkin"
      id: runner.slaveId.toString()
      processes: util.clone runner.processes

  ws = new WebSocket "ws://#{@opts.hostname}:#{@opts.port}"
  ws.on 'open', =>
    ws.send checkinMessage()
    @interval = setInterval ->
      ws.send checkinMessage()
    , 500
  ws.on 'close', =>
    clearInterval @interval
    console.log "Checkin connection closed" unless @innerOpts.silent
    setTimeout =>
      @startCheckin() if @shouldRetryCheckin
    , 500
  ws.on 'error', (err) =>
    clearInterval @interval
    console.log "Checkin connection errored with", err unless @innerOpts.silent
    setTimeout =>
      @startCheckin() if @shouldRetryCheckin
    , 500

module.exports = (opts) ->
  new Checkin opts
