assert = require 'assert'
path = require 'path'
rimraf = require 'rimraf'
testpath = path.resolve '.', 'testrepos'
opts =
  deploydir: path.join testpath, 'deploy'
  repodir: path.join testpath, 'repos'
gitter = require('../lib/gitter.coffee') opts
Stream = require('stream').Stream

describe "gitter", ->

  after (done) ->
    rimraf opts.repodir, ->
    rimraf opts.deploydir, ->
      done()

  it 'should be a Stream', ->
    assert gitter instanceof Stream
  it 'should fetch a repo without error', (done) ->
    @timeout 10000
    gitter.fetch "test1", "https://github.com/davidbanham/test1.git", (err) ->
      done err
  it 'should deploy a repo without error', (done) ->
    gitter.deploy
      name: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
    , (err, tookaction) ->
      assert.equal null, err
      assert tookaction
      done err

