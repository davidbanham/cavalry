assert = require 'assert'
http = require 'http'
porter = require '../lib/porter.coffee'

describe 'porter', ->
  describe 'with running servers', (done) ->
    servers = []
    before ->
      range = [8000...8005]
      for port in range
        servers.push http.createServer()
        servers[servers.length - 1].listen port
    after ->
      for server in servers
        server.removeAllListeners()
        server.close()
    it 'should respond with the first free port', (done) ->
      porter.getPort (err, port) ->
        assert.equal err, null
        assert.equal port, 8005
        done()
  describe 'without running servers', ->
    beforeEach ->
      porter.basePort = 8000
      porter.marker = undefined
      porter.neverTwice = false
      porter.upperLimit = undefined
    it 'should respond with the first free port', (done) ->
      porter.getPort (err, port) ->
        assert.equal err, null
        assert.equal port, 8000
        done()
    it 'should respond to a new basePort being set', (done) ->
      porter.basePort = 8010
      porter.getPort (err, port) ->
        assert.equal err, null
        assert.equal port, 8010
        done()
    it 'should not return the same port twice if asked', (done) ->
      porter.neverTwice = true
      porter.getPort (err, outerPort) ->
        assert.equal err, null
        porter.getPort (err, innerPort) ->
          assert.equal err, null
          assert.notEqual outerPort, innerPort
          done()
    it 'should accept an upper limit on defined ports', (done) ->
      porter.upperLimit = 8001
      porter.neverTwice = true
      porter.getPort (err, port) ->
        assert.equal err, null
        assert.equal port, 8000
        porter.getPort (err, port) ->
          assert.equal err, null
          assert.equal port, 8001
          porter.getPort (err, port) ->
            assert.equal err, null
            assert.equal port, 8000
            done()
