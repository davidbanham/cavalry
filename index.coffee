server = require './lib/webserver.coffee'
checkin = require('./lib/checkin.coffee')()

server.listen process.env.PORT or 3000
checkin.startCheckin()
