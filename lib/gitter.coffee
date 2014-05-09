Stream = require('stream').Stream
exec = require('child_process').exec
fs = require 'fs'
path = require 'path'
rimraf = require 'rimraf'
find = require 'findit'
git = require 'gift'

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
    git.init fetchdir, (err, repo) ->
      throw err if err?
      repo.remote_fetch url, (err) ->
        if err?
          rimraf fetchdir, ->
            cb err
        else
          cb err

Gitter.prototype.deploy = (opts, cb) ->
  name = opts.name
  commit = opts.commit
  pid = opts.pid

  return cb new Error "Insufficient args" if !name? or !commit? or !pid?

  checkoutdir = path.join @deploydir, "#{name}.#{pid}.#{commit}"
  targetrepo = path.join @repodir, name
  fs.exists targetrepo, (exists) =>
    return innerDeploy() if exists
    master =
      hostname: process.env.MASTERHOST or "localhost"
      port: process.env.MASTERGITPORT or 4001
      secret: process.env.MASTERPASS or 'testingpass'
    @fetch name, "http://git:#{master.secret}@#{master.hostname}:#{master.port}/#{name}/", (err) =>
      return cb err if err?
      innerDeploy()

  innerDeploy = =>
    fs.exists checkoutdir, (exists) =>
      return cb null, false if exists
      git.clone targetrepo, checkoutdir, (err, repo) =>
        return cb err if err?
        repo.checkout commit, (errr) =>
          return cb err if err?
          @emit 'deploy',
            repo: name
            commit: commit
            cwd: checkoutdir
          cb err, true

Gitter.prototype.check = (opts, cb) ->
  #TODO check that the hashes are correct rather than just the correct number of files
  checkoutdir = path.join @deploydir, "#{opts.name}.#{opts.pid}.#{opts.commit}"
  exec "git ls-tree -r #{opts.commit}", {cwd: checkoutdir}, (err, stdout) =>
    return cb err, false if err

    file_data = stdout.split '\n'
    expected_files = []

    for file in file_data
      arr = file.split ' '
      continue if arr.length is 1

      arr2 = arr[2].split '\t'

      expected_files.push
        mode: arr[0]
        type: arr[1]
        sha: arr2[0]
        name: arr2[1]

    return cb new Error 'empty repository', false if expected_files.length is 0

    actual_files = []

    finder = find checkoutdir
    finder.on 'file', (file) ->
      actual_files.push
        name: path.relative checkoutdir, file

    finder.on 'link', (file) ->
      actual_files.push
        name: path.relative checkoutdir, file

    finder.on 'directory', (dir, stat, stop) ->
      stop() if dir.indexOf('.git') > -1

    finder.on 'end', ->
      return cb null, false if actual_files.length isnt expected_files.length
      file_names = actual_files.map (file) ->
        return file.name
      for file in expected_files
        return cb new Error('file missing'), false if file_names.indexOf(file.name) < 0
      return cb null, true

Gitter.prototype.deploy_and_check = (opts, cb) ->
  @deploy opts, (err, actionTaken) =>
    return cb err if err?
    @check opts, (err, complete) =>
      return cb err if err?
      return cb new Error('checkout incomplete') if !complete
      return cb null, actionTaken

module.exports = (opts) ->
  new Gitter opts
