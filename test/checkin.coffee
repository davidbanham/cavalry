assert = require "assert"
http = require 'http'
checkin = require('../lib/checkin.coffee')({silent: true})
master = http.createServer()
describe "checkin", ->
  before (done) ->
    master.listen 4000
    checkin.setRetry true
    done()
  after (done) ->
    master.close ->
      done()

  it 'should check in with a master', (done) ->
    checkin.startCheckin()
    master.on 'request', (req, res) ->
      checkin.setRetry false
      res.end()
      assert.equal req.url, '/checkin'
      assert req.headers.authorization?
      done()
