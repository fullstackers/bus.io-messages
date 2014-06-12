[![Build Status](https://travis-ci.org/turbonetix/bus.io-messages.svg?branch=master)](https://travis-ci.org/turbonetix/bus.io-messages.git)
[![NPM version](https://badge.fury.io/js/bus.io-messages.svg)](http://badge.fury.io/js/bus.io-messages)
[![David DM](https://david-dm.org/turbonetix/bus.io-messages.png)](https://david-dm.org/turbonetix/bus.io.png)

![Bus.IO](https://raw.github.com/turbonetix/bus.io/master/logo.png)

A **[bus.io](https://www.npmjs.org/package/bus.io "Bus.io")** dependency.

This produces messages as it listens for events on a socket.

# Installation and Environment Setup

Install node.js (See download and install instructions here: http://nodejs.org/).

Install coffee-script

    > npm install coffee-script -g

Clone this repository

    > git clone git@github.com:turbonetix/bus.io-messages.git

cd into the directory and install the dependencies

    > cd bus.io-messages
    > npm install && npm shrinkwrap --dev

# Examples

Here is how we can setup bus.io-messages and have it listen to socket.io.

```javascript

var io = require('socket.io')();
io.listen(3000);

var messages = require('bus.io-messages').listen(io);

```

A message encapsulates an actor performing an action on a target with some content.

Each socket needs an actor.  You must specifiy an method to grab the *actor*.  If you do
not specify the actor the assigned socket id will be used.

```javascript

messages.actor(function (socket, cb) {
  if (socket.handshake && 
      socket.handshake.session &&
      socket.handshake.session.name) {
     cb(null, socket.handshake.session.name);
  }
  else {
     cb(new Error('Invalid Session'));
  }
});

```
Messages have a *target* we can specify a method to extract the target from the *params* received.

```javascript

messages.target(function (socket, params, cb) {

  if (!params || !params.length)
    return cb(new Error('missing data'));

  var targetId = params.shift()

  cb(null, targetId);

});

```

We can listen to actions by calling *action* and passing in the *name* of the action.

```javascript

messages.action('say');

```

When the *socket* receives an *event*, *messages* will produce an object like this and trigger
a `message` event with the object.

```javascript

{
  "created":"2014-05-29T14:34:36.942Z",
  "action":"say",
  "actor":"vL3fesBeM5ixbqhNAAAA",
  "target":"you",
  "content":["hello, world!"]
}

```

You also have the ability to *auto-propagate* messages that way any event 
received on socket will be encapsualted as message and published onto the
exchange.  By default this is turned off.  If it is turned on *any* event
even ones not declared with `messages.action('some action')` will be
captured.

```javascript

messages.autoPropagate(true);

```

# API

## Messages

### Messages#()

```javascript

var messages = Messages();

```

### Messages#(io:SocketIO)

```javascript

var io = require('socket.io')(3000);

var messages = Messages(io);

```

### Messages#attach(io:SocketIO)

```javascript

var io = require('socket.io')(3000);
var messages = Messages();
messages.attach(io);

```

### Messages#actor(fn:Function)

```javascript

messages.actor(function (socket, cb) {
  cb(null, socket.id);
});

```

### Messages#target(fn:Function)

```javascript

messages.target(function (socket, params, cb) {
  cb(null, params.pop() || socket.id);
});

```

### Messages#action(v:String)

```javascript

messsages.action('shout');

```

### Messages#actions()

```javascript

var actions = messsages.actions();

```

### Messages#autoPropagate(v:Boolean)

```javascript

messages.autoPropagate(true);

```

### Messages#autoPropagate()

```javascript

var propagating = messages.autoPropagate();

```

### Events

#### error

Triggered when an `Error` occurs

```javascript

messages.on('error', function (err, socket, args) { 

});

```

#### action

Triggered when we add a new `action`

```javascript

messages.on('action', function (name) {

});

```

#### message

Triggered when we received a message from the socket.io connection

```javascript 

messages.on('message', function (message) {

});

```

# Running Tests

Tests are run using grunt.  You must first globally install the grunt-cli with npm.

    > sudo npm install -g grunt-cli

## Unit Tests

To run the tests, just run grunt

    > grunt spec:unit

# TODO
