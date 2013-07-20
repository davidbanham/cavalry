assert = require 'assert'
fs = require 'fs'
path = require 'path'
testpath = path.resolve '.', 'testrepos'
drone = require('../index.coffee')
  deploydir: testpath
describe 'drone', ->
  it 'should have a processes object', ->
    assert drone.processes
  it 'should have a spawn method', ->
    assert drone.spawn
  it 'should spawn a process in the right directory', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['touch', rand]
      once: true
    drone.spawn opts, (proc) ->
      assert proc.status, "running"
      assert proc.repo, "test1"
      assert proc.commit, '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      setTimeout ->
        touchedFile = path.join testpath, proc.repo+'.'+proc.commit, rand
        assert fs.existsSync touchedFile
        fs.unlinkSync touchedFile
        done()
      , 1
  it 'should pass back stdout properly', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      once: true
    drone.spawn opts
    drone.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      done() if str is rand
  it 'should respawn the process when it dies', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
    drone.spawn opts
    count = 0
    drone.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      count++ if str is rand
      done() if count = 2
