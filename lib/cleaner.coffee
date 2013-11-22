Stream = require('stream').Stream
runner = require '../lib/runner'
rimraf = require 'rimraf'
fs = require 'fs'
path = require 'path'

Cleaner = ->
  setInterval =>
    @clean ->
  , 60 * 1000
  return this

Cleaner.prototype = new Stream

Cleaner.prototype.clean = (cb) ->
  deploydir = runner.deploydir
  total = 0
  errs = []
  fs.readdir deploydir, (err, files) =>
    total = files.length - 1
    throw err if err?
    for dir, i in files
      do (dir, i) =>
        pid = dir.split('.')[1]
        return checkDone i if dir.charAt(0) is '.'
        return checkDone i if Object.keys(runner.processes).indexOf(pid) > -1
        @rmIfDir path.join(deploydir, dir), (err) ->
          errs = [] if !errs?
          errs.push err if err?
          checkDone i

  checkDone = (i) ->
    if i is total
      errs = null if errs.length is 0
      cb errs

Cleaner.prototype.rmIfDir = (dir, cb) ->
  fs.stat dir, (err, stats) =>
    return cb null if !stats.isDirectory()
    rimraf dir, (err) =>
      @emit 'pruned directory', dir unless err?
      cb err

module.exports = new Cleaner
