assert = require 'assert'
fs = require 'fs'
path = require 'path'
rimraf = require 'rimraf'
testpath = path.resolve '.', 'testrepos'
deploydir = path.join testpath, 'deploy'
slave = require('../lib/runner.coffee')
slave.deploydir = deploydir
describe 'slave', ->
  specifiedPid = Math.floor(Math.random() * (1 << 24)).toString(16)
  before (done) ->
    specifiedPid = Math.floor(Math.random() * (1 << 24)).toString(16)
    fs.mkdir testpath, ->
    fs.mkdir deploydir, ->
    fs.symlink path.join(testpath, "test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), path.join(testpath, "deploy", "test1.#{specifiedPid}.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), ->
      done()
  after (done) ->
    rimraf deploydir, ->
      done()
  it 'should have a processes object', ->
    assert slave.processes
  it 'should have a spawn method', ->
    assert slave.spawn
  it 'should spawn a process in the right directory', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['touch', rand]
      once: true
      testingPid: specifiedPid
    slave.spawn opts, (proc) ->
      assert proc.status, "running"
      assert proc.repo, "test1"
      assert proc.commit, '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      setTimeout ->
        touchedFile = path.join deploydir, "#{proc.repo}.#{proc.id}.#{proc.commit}", rand
        assert fs.existsSync touchedFile
        fs.unlinkSync touchedFile
        done()
      , 5

describe 'process', ->
  specifiedPid = null
  specifiedPid2 = null
  beforeEach (done) ->
    specifiedPid = Math.floor(Math.random() * (1 << 24)).toString(16)
    specifiedPid2 = Math.floor(Math.random() * (1 << 24)).toString(16)
    try
      fs.mkdirSync testpath
    try
      fs.mkdirSync deploydir
    fs.mkdir path.join(deploydir, "test1.#{specifiedPid}.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), (err) ->
      fs.mkdir path.join(deploydir, "test1.#{specifiedPid2}.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), (err) ->
        assert.equal err, null, "Error creating test directory #{err}"
        done()
  afterEach (done) ->
    rimraf deploydir, ->
      done()

  it 'should pass back stdout properly', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      once: true
      testingPid: specifiedPid
    slave.spawn opts
    slave.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      done() if str is rand

  it 'should respawn the process when it dies', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
      testingPid: specifiedPid
    pid = null
    slave.spawn opts, (proc) ->
      pid = proc.id
    count = 0
    slave.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      count++ if str is rand
      slave.removeAllListeners() if count is 2
      slave.stop pid if count is 2
      done() if count is 2

  it 'should stop the process when told', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
      testingPid: specifiedPid
    slave.spawn opts, (proc) ->
      slave.on 'stop', (info) ->
        done() if info.id is proc.id
      slave.stop proc.id
      slave.on 'stdout', (buf, info) ->
        assert.notEqual proc.id, info.id

  it 'should stop a range of ids', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    rand2 = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
      testingPid: specifiedPid
    opts2 =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand2}');"]
      debounce: 1
      testingPid: specifiedPid2
    pids = []
    count = 0
    slave.spawn opts, (proc) ->
      pids.push proc.id
    slave.spawn opts2, (proc) ->
      pids.push proc.id
      slave.on 'stop', (info) ->
        count++ if info.id is pid for pid in pids
        done() if count is pids.length
      slave.stop pids
      slave.on 'stdout', (buf, info) ->
        assert.notEqual proc.id, info.id
  it 'should restart the process when told', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', 'server.js']
      debounce: 1
      testingPid: specifiedPid
    slave.spawn opts, (proc) ->
      slave.on 'exit', (code, signal, info) ->
        slave.stop proc.id if info.id is proc.id
        done() if info.id is proc.id
      slave.restart proc.id
  it 'should expose the deploy directory', ->
    assert slave.deploydir

describe 'setup', ->
  specifiedPid = Math.floor(Math.random() * (1 << 24)).toString(16)
  before (done) ->
    fs.mkdir testpath, ->
    fs.mkdir deploydir, ->
    fs.symlink path.join(testpath, "test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), path.join(testpath, "deploy", "test1.#{specifiedPid}.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), ->
      done()

  after (done) ->
    rimraf deploydir, ->
      done()

  it 'should accept a setup task within a spawn call', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      setup: ['touch', rand]
      command: ['echo']
      once: true
      testingPid: specifiedPid
    slave.spawn opts, (proc) ->
      setTimeout ->
        touchedFile = path.join deploydir, "#{proc.repo}.#{proc.id}.#{proc.commit}", rand
        assert fs.existsSync touchedFile
        fs.unlinkSync touchedFile
        done()
