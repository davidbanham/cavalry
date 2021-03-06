# Cavalry

Cavalry is a way to get git repositories onto machines, then run the code in them. It's heavily inspired by [fleet](https://github.com/substack/fleet) and [propagit](https://github.com/substack/propagit).

Cavalry is designed to work in conjuction with [Field Marshal](https://github.com/davidbanham/field-marshal)

[![Build Status](https://travis-ci.org/davidbanham/cavalry.png?branch=master)](https://travis-ci.org/davidbanham/cavalry)

# Installation

Cavalry expects nginx to be present on the system.
Ports:
- 3000 will need to be accessible by the master.
- 7005 is where nginx is listening
- 8000-9000 Web accessible services, if they ask, will be assigned ports between 8000 and 9000.

It's in npm, so just:
    npm install -g cavalry

# Running it

Configuration paramaters are passed in via environment variables. eg:

    SLAVEID=us-1 MASTERHOST=localhost MASTERPASS=masterpassword SECRET=password node index.js

If they're not present, a default will be substituted.
- SLAVEID is the identifier for the machine
- MASTERHOST is the fqdn/ip where the master can be found
- MASTERPASS is the password used to authenticate with the master
- SECRET is the password the master will use to authenticate with this slave
