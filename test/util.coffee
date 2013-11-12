assert = require 'assert'
util = require '../lib/util.coffee'
describe 'util', ->
  it 'should return an opts object', ->
    opts = util.opter ['node', '/some/path', '--foo', '--bar']
    assert opts.foo
    assert opts.bar
  it 'should return the api version', ->
    assert.equal util.apiVersion, 2
