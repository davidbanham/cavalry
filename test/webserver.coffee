assert = require "assert"
http = require 'http'
request = require 'request'
fs = require 'fs'
path = require 'path'
rimraf = require 'rimraf'
testpath = path.resolve '.', 'testrepos'
deploydir = path.join testpath, 'deploy'
runner = require "../lib/runner.coffee"
runner.deploydir = deploydir
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
  it 'should return an api version', (done) ->
    request.get "http://localhost:3000/apiVersion", (err, res, body) ->
      assert.equal err, null
      assert.equal body, '2'
      done()
    .auth "user", "testingpass"
  describe 'exec', ->
    it 'should reject if opts.once isnt set', (done) ->
      opts =
        repo: 'test1'
      request
        url: "http://localhost:3000/exec"
        method: "post"
        json: opts
        auth:
          user: "user"
          pass: "testingpass"
      , (err, res, body) ->
        done assert.equal res.statusCode, 400
    it 'should come back once the process is finished', (done) ->
      try fs.mkdirSync path.resolve testpath
      try
        fs.mkdirSync deploydir
      catch err
        assert.equal err.code, 'EEXIST'
      try
        fs.mkdir path.join(deploydir, 'test1.webservertest.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447')
      catch err
        assert.equal err.code, 'EEXIST'
      opts =
        repo: 'test1'
        commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
        command: ['echo', 'ohai']
        once: true
        testingPid: 'webservertest'
      request
        url: "http://localhost:3000/exec"
        method: "post"
        json: opts
        auth:
          user: "user"
          pass: "testingpass"
      , (err, res, body) ->
        rimraf deploydir, ->
          assert.equal body.code, 0
          done assert.equal body.stdout[0], 'ohai\n'
  it "Should update the config file when a new routing table is recieved", (done) ->
    request
      url: "http://localhost:3000/routingTable"
      method: "post"
      json:
        test1:
          routes: [
            {host: "testslave1.example.com", port: 8000}
            {host: "testslave2.example.com", port: 8000}
          ]
        test2:
          routes: [
            {host: "testslave1.example.com", port: 8001}
            {host: "testslave2.example.com", port: 8001}
          ]
      auth:
        user: "user"
        pass: "testingpass"
    , (err, res, body) ->
      assert.equal res.statusCode, 200
      assert.equal err, null
      done()
