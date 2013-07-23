Stream = require('stream').Stream
exec = require('child_process').exec
fs = require 'fs'
path = require 'path'

throwUnlessExists = (err) ->
  if err?
    throw err unless err.toString().split(' ')[1] is "EEXIST,"

Gitter = (opts={}) ->
  base = opts.basedir or process.cwd()
  @repodir = path.resolve(opts.repodir or path.join(base, 'repos'))
  @deploydir = path.resolve(opts.deploydir or path.join(base, 'deploy'))
  fs.mkdir @repodir, (err) ->
    throwUnlessExists err
  fs.mkdir @deploydir, (err) ->
    throwUnlessExists err

Gitter.prototype = new Stream

Gitter.prototype.fetch = (repo, url, cb) ->
  fetchdir = path.join @repodir, repo
  fs.mkdir fetchdir, (err) ->
    throwUnlessExists err
    exec "git init", {cwd: fetchdir}, (err) ->
      throw err if err?
      exec "git fetch #{url}", {cwd: fetchdir}, (err) ->
        cb err

Gitter.prototype.deploy = (opts, cb) ->
  repo = opts.repo
  commit = opts.commit

  checkoutdir = path.join @deploydir, "#{repo}.#{commit}"
  targetrepo = path.join @repodir, repo
  fs.exists checkoutdir, (exists) =>
    return cb null, false if exists
    exec "git clone #{targetrepo} #{checkoutdir}", (err) =>
      return cb err if err?
      exec "git checkout #{commit}", {cwd: checkoutdir}, (err) =>
        @emit 'deploy',
          repo: repo
          commit: commit
          cwd: checkoutdir
        cb err, true


module.exports = (opts) ->
  new Gitter opts
