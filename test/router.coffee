assert = require 'assert'
fs = require 'fs'
path = require 'path'
router = require '../lib/router.coffee'
describe 'routes', ->
  before (done) ->
    if router.nginx.stdout?
      done()
    else
      router.once 'ready', ->
        #router.nginx.stdout.on 'data', (buf) ->
        #  console.log buf.toString()
        #router.nginx.stderr.on 'data', (buf) ->
        #  console.log buf.toString()
        #router.nginx.on 'exit', (code, signal) ->
        #  console.log "nginx exited", code, signal
        #router.nginx.on 'error', (err) ->
        #  console.log "nginx err", err
        done()
  after (done) ->
    #router.takedown()
    #router.nginx.once 'exit', ->
    done()
  routingTable =
    repo1:
      domain: 'repo1.example.com'
      routes: [
        {
          host: 'drone1.example.com'
          port: 8000
        }
        {
          host: 'drone2.example.com'
          port: 8001
        }
      ]
    repo2:
      domain: 'repo2.example.com'
      method: 'ip_hash'
      routes: [
        {
          host: 'drone1.example.com'
          port: 8001
        }
      ]
    repo3:
      domain: 'repo3.example.com'
      routes: [
        {
          host: 'drone2.example.com'
          port: 8000
        }
      ]
  it "Should build the mustache options object correctly", ->
    options = router.buildOpts routingTable
    assert.deepEqual options.server,
      [
        { domain: 'repo1.example.com', name: 'repo1' }
        { domain: 'repo2.example.com', name: 'repo2' }
        { domain: 'repo3.example.com', name: 'repo3' }
      ]
    assert.deepEqual options.upstream,
      [
        {
          name: 'repo1', method: 'least_conn', routes: [
            { host: 'drone1.example.com', port: 8000 }
            { host: 'drone2.example.com', port: 8001 }
          ]
        }
        {
          name: 'repo2', method: 'ip_hash', routes: [
            { host: 'drone1.example.com', port: 8001 }
          ]
        }
        {
          name: 'repo3', method: 'least_conn', routes: [
            { host: 'drone2.example.com', port: 8000 }
          ]
        }
      ]
  it "Should render the template without throwing an error", (done) ->
    router.writeFile routingTable, (err) ->
      assert.equal null, err
      done()
  it "Should spawn an nginx process on start", (done) ->
    assert router.nginx.stdout?
    done()
  it "Should write an nginx pidfile", (done) ->
    return done() if process.env.TRAVIS
    setTimeout ->
      assert fs.existsSync path.join router.pidpath, "nginx.pid"
      assert.equal fs.readFileSync(path.join router.pidpath, "nginx.pid").toString(), router.nginx.pid
      done()
    , 50
