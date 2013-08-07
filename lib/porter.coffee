# Cribbed from https://github.com/indexzero/node-portfinder
net = require 'net'

exports.basePort = 8000
exports.neverTwice = false
exports.getPort = (options, callback) ->
  if !callback
    callback = options
    options = {}

  options.port = options.port or exports.marker or exports.basePort
  options.host = options.host or null
  options.server = options.server or net.createServer()

  onListen = ->
    options.server.removeListener 'error', onError
    options.server.close()
    exports.marker = options.port + 1 if exports.neverTwice
    if exports.upperLimit
      exports.marker = exports.basePort if exports.marker > exports.upperLimit
    callback null, options.port

  onError = (err) ->
    options.server.removeListener 'listening', onListen
    return callback err if err.code isnt 'EADDRINUSE' and err.code isnt 'EACCES'

    exports.getPort
      port: exports.nextPort options.port
      host: options.host
      server: options.server
    , callback

  options.server.once 'error', onError
  options.server.once 'listening', onListen
  options.server.listen options.port, options.host

  exports.nextPort = (port) ->
    return port + 1

module.exports = exports
