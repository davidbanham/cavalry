assert = require 'assert'
rimraf = require 'rimraf'
cleaner = require '../lib/cleaner.coffee'
runner = require '../lib/runner'
Stream = require('stream').Stream
path = require 'path'
testpath = path.resolve '.', 'testrepos'
deploydir = path.join testpath, 'deploy'
fs = require 'fs'

describe "cleaner", ->

  before (done) ->
    try
      fs.mkdirSync deploydir
    catch
      done()
    done()

  after (done) ->
    rimraf deploydir, ->
      done()

  it 'should be a Stream', ->
    assert cleaner instanceof Stream

  it 'should delete stale directories', (done) ->
    fs.mkdirSync path.join deploydir, 'lol'
    fs.mkdirSync path.join deploydir, 'wut'
    cleaner.clean (err) ->
      assert.equal err, null
      assert.equal false, fs.existsSync path.join deploydir, 'lol'
      assert.equal false, fs.existsSync path.join deploydir, 'wut'
      done()

   it 'should not delete active directories', (done) ->
     runner.processes =
       'someactivepid': {}
     fs.mkdirSync path.join deploydir, 'reponame.someactivepid.biglongsha'
     cleaner.clean (err) ->
       assert.equal err, null
       assert fs.existsSync path.join deploydir, 'reponame.someactivepid.biglongsha'
       rimraf path.join(deploydir, 'reponame.someactivepid.biglongsha'), ->
         done()
describe 'rmIfDir', ->
  before (done) ->
    try
      fs.mkdirSync deploydir
    catch
      done()
    done()

  after (done) ->
    rimraf deploydir, ->
      done()

  it 'should delete directories', (done) ->
    dir = path.join deploydir, 'totallyadirectory'
    fs.mkdirSync dir
    cleaner.rmIfDir dir, (err) ->
      assert.equal err, null
      done assert !fs.existsSync dir

  it 'should not delete files', (done) ->
    afile = path.join deploydir, 'this is a file'
    fs.writeFileSync afile, new Buffer 'contents'
    assert fs.existsSync(afile), 'file not created'
    cleaner.rmIfDir afile, (err) ->
      assert fs.existsSync(afile), 'file was deleted'
      fs.unlinkSync afile
      done()
