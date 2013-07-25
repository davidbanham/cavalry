http = require 'http'
runner = require('../lib/runner')()
util = require('../lib/util')

Checkin = (innerOpts={})->
  @opts =
    hostname: process.env.MASTERHOST or "localhost"
    port: process.env.MASTERPORT or 4000
    path: "/checkin"
    auth: "#{runner.droneId}:#{process.env.MASTERPASS or 'testingpass'}"
    agent: false
    method: "POST"
    headers:
      Connection: "keep-alive"
  @innerOpts = innerOpts
  @shouldRetryCheckin = true
  return this

Checkin.prototype.setRetry = (state) ->
  @shouldRetryCheckin = state

Checkin.prototype.startCheckin = ->
  checkinMessage = ->
    JSON.stringify
      id: runner.droneId.toString()
      processes: util.clone runner.processes

  longpoll = http.request @opts, (res) ->
  longpoll.on 'error', (e) =>
    console.log "Checkin error: #{e.message}" unless @innerOpts.silent
  longpoll.on 'close', =>
    console.log "Checkin connection closed" unless @innerOpts.silent
    @startCheckin() if @shouldRetryCheckin
  longpoll.on 'end', =>
    console.log "Checkin connection ended" unless @innerOpts.silent
    @startCheckin() if @shouldRetryCheckin
  longpoll.write checkinMessage()
  setInterval ->
    longpoll.write checkinMessage()
  , 500

module.exports = (opts) ->
  new Checkin opts
