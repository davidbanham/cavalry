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
  try
    fs.mkdirSync @repodir
  catch err
    throwUnlessExists err
  try
    fs.mkdirSync @deploydir
  catch err
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
  name = opts.name
  commit = opts.commit
  pid = opts.pid

  return cb new Error "Insufficient args" if !name? or !commit? or !pid?

  checkoutdir = path.join @deploydir, "#{name}.#{pid}.#{commit}"
  targetrepo = path.join @repodir, name
  fs.exists checkoutdir, (exists) =>
    return cb null, false if exists
    exec "git clone #{targetrepo} #{checkoutdir}", (err) =>
      return cb err if err?
      exec "git checkout #{commit}", {cwd: checkoutdir}, (err) =>
        @emit 'deploy',
          repo: name
          commit: commit
          cwd: checkoutdir
        cb err, true


module.exports = (opts) ->
  new Gitter opts
