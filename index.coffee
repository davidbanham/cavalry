server = require './lib/webserver.coffee'
checkin = require('./lib/checkin.coffee')()
cleaner = require './lib/cleaner.coffee'
util = require './lib/util.coffee'
opts = util.opter process.argv

start = ->
  server.listen process.env.PORT or 3000
  checkin.startCheckin()

if opts.create
  start()
else
  process.stdin.resume()
  process.stdin.setEncoding 'utf8'
  console.log "Cavalry needs to write files to the current working directory."
  console.log "process.cwd() is #{process.cwd()}"
  console.log "To avoid this message in future pass the --create option"
  console.log "Are you happy to have things written here? [y/N]"
  process.stdin.on 'data', (chunk) ->
    if chunk.toString().toLowerCase() is 'y\n'
      start()
    else throw new Error "User did not grant write permission"
