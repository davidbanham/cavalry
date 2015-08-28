runner = require '../lib/runner'
syslogh = require 'syslogh'

syslogh.openlog 'cavalry', syslogh.PID, syslogh.LOCAL7

runner.on "stdout", (buf, info) ->
  syslogh.syslog syslogh.NOTICE, "#{info.repo} #{info.id} - #{addNewline buf.toString()}"
runner.on "stderr", (buf, info) ->
  syslogh.syslog syslogh.ERR, "#{info.repo} #{info.id} - #{addNewline buf.toString()}"
runner.on "spawn", (info) ->
  syslogh.syslog syslogh.INFO, "#{info.repo} #{info.id} spawn\r\n"
runner.on "stop", (info) ->
  syslogh.syslog syslogh.INFO, "#{info.repo} #{info.id} stop\r\n"
runner.on "restart", (info) ->
  syslogh.syslog syslogh.INFO, "#{info.repo} #{info.id} restart\r\n"
runner.on "exit", (code, signal, info) ->
  str = "#{info.repo} exited with code #{code}"
  str += " from signal #{signal}" if signal?
  syslogh.syslog syslogh.INFO, str+"\r\n"
runner.on "error", (err, info) ->
  syslogh.syslog syslogh.CRIT, "#{info.repo} #{info.id} error - #{addNewline err.toString()}"

addNewline = (str) ->
  return str += '\r\n' if str.charAt(str.length - 1) isnt '\n'
  return str
