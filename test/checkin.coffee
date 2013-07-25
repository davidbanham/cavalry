assert = require "assert"
http = require 'http'
checkin = require('../lib/checkin.coffee')({silent: true})
runner = require '../lib/runner.coffee'
master = null
describe "checkin", ->
  beforeEach (done) ->
    master = http.createServer()
    master.listen 4000
    checkin.setRetry false
    done()
  afterEach (done) ->
    master.close ->
      done()

  it 'should check in with a master', (done) ->
    checkin.startCheckin()
    master.on 'request', (req, res) ->
      checkin.setRetry false
      res.destroy()
      res.end()
      assert.equal req.url, '/checkin'
      assert req.headers.authorization?
      done()
  it 'should send the proceses object with the checkin', (done) ->
    runner.processes =
      c904bf:
        id: 'c904bf'
        status: 'running'
        repo: 'test1'
        commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
        command: [ 'touch', 'acd82b' ]
        cwd: '/Users/davidbanham/Dropbox/repos/cavalry/testrepos/deploy/test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
    checkin.startCheckin()
    master.on 'request', (req, res) ->
      req.on "data", (buf) ->
        checkinData = JSON.parse buf.toString()
        checkin.setRetry false
        res.destroy()
        res.end()
        done assert.deepEqual checkinData.processes,
          c904bf:
            id: 'c904bf'
            status: 'running'
            repo: 'test1'
            commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
            command: [ 'touch', 'acd82b' ]
            cwd: '/Users/davidbanham/Dropbox/repos/cavalry/testrepos/deploy/test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
