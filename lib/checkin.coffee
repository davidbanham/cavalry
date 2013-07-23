http = require 'http'
runner = require('../lib/runner')()

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

Checkin.prototype.setRetry = (state) ->
  @shouldRetryCheckin = state

Checkin.prototype.startCheckin = ->
  longpoll = http.request @opts, (res) ->
  longpoll.on 'error', (e) =>
    console.log "Checkin error: #{e.message}" unless @innerOpts.silent
  longpoll.on 'close', =>
    console.log "Checkin connection closed" unless @innerOpts.silent
    @startCheckin() if @shouldRetryCheckin
  longpoll.on 'end', =>
    console.log "Checkin connection ended" unless @innerOpts.silent
    @startCheckin() if @shouldRetryCheckin
  longpoll.write runner.droneId.toString()
  setInterval ->
    longpoll.write runner.droneId.toString()
  , 500

module.exports = (opts) ->
  new Checkin opts
