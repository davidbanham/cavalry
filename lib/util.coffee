clone = (obj) =>
  return obj if !obj? or typeof obj isnt 'object'
  return new Date(obj.getTime()) if obj instanceof Date
  return '' if obj instanceof RegExp
  newInstance = new obj.constructor()
  for key of obj
    continue if key is "process" or key is "respawn" or key is "drone"
    newInstance[key] = clone obj[key]
  return newInstance

module.exports =
  clone: clone
