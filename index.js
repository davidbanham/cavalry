#!/usr/bin/env node
var coffee = require('coffee-script');
if (typeof coffee.register !== 'undefined') coffee.register();
require('./index.coffee');
