assert = require "assert"
http = require 'http'
request = require 'request'
server = require "../lib/webserver.coffee"
describe "webserver", ->
  before (done) ->
    server.listen 3000
    done()
  after (done) ->
    server.close ->
      done()
  it 'should return a 401 if not authed', (done) ->
    request.get "http://localhost:3000", (err, res, body) ->
      done assert.equal res.statusCode, 401
  it 'should return a 401 on the wrong password', (done) ->
    request.get "http://localhost:3000", (err, res, body) ->
      done assert.equal res.statusCode, 401
    .auth "user", "wrongpass"
  it 'should return a 200 on the right password', (done) ->
    request.get "http://localhost:3000/health", (err, res, body) ->
      done assert.equal res.statusCode, 200
    .auth "user", "testingpass"
  it 'should return 404 on a null path', (done) ->
    request.get "http://localhost:3000", (err, res, body) ->
      done assert.equal res.statusCode, 404
    .auth "user", "testingpass"
  it 'should return an object on ps', (done) ->
    request.get "http://localhost:3000/ps", (err, res, body) =>
      assert.equal res.statusCode, 200
      assert.equal typeof JSON.parse(body), "object"
      done()
    .auth "user", "testingpass"
  it 'should return a port', (done) ->
    require("../lib/porter.coffee").basePort = 8000
    request.get "http://localhost:3000/port", (err, res, body) ->
      assert.deepEqual JSON.parse(body),
        port: 8001
      done()
    .auth "user", "testingpass"
