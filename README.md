# Cavalry

Cavalry is a way to get git repositories onto machines, then run the code in them. It's heavily inspired by [fleet](https://github.com/substack/fleet) and [propagit](https://github.com/substack/propagit).

Cavalry is designed to work in conjuction with [Rear-Admiral](https://github.com/davidbanham/rear-admiral)

[![Build Status](https://travis-ci.org/davidbanham/cavalry.png?branch=master)](https://travis-ci.org/davidbanham/cavalry)

# Installation

Cavalry expects nginx to be present on the system. Port 3000 will need to be accessible by the master. Web accessible services, if they ask, will be assigned ports between 8000 and 9000.

It's in npm, so just:
    npm install -g cavalry

# Running it

Configuration paramaters are passed in via environment variables. eg:

    MASTERHOST=localhost MASTERPASS=masterpassword SECRET=password node index.js

If they're not present, a default will be substituted.
- MASTERHOST is the fqdn/ip where the master can be found
- MASTERPASS is the password used to authenticate with the master
- SECRET is the password the master will use to authenticate with this slave
