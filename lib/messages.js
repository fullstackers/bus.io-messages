var util = require('util')
  , events = require('events')
  , debug = require('debug')('bus.io-messages:messages')
  , common = require('bus.io-common')
  , Message = common.Message
  ;

module.exports = Messages;

/**
 * Produces and publishes socket messages
 */

function Messages () {
  var self = this;

  if (!(this instanceof Messages)) return new Messages();

  events.EventEmitter.call(this);

  debug('new messages');

  /**
   * When a socket is accepted
   *
   * @param {object} socket
   */

  this.onConnection = function (socket) {

    debug('on connection %s', socket.id);

    /**
     * This is used to add listeners to sockets when the Messages.prototype.action()
     * method is invoked
     *
     * @param {string} name
     */

    function onAction (name) {
      debug('on action %s', name);
      if (socket.listeners(name).indexOf(self.onMessage) < 0) {
        socket.on(name, function () {
          debug('socket on %s', name);
          var args = Array.prototype.slice.call(arguments);
          self.onMessage(socket, [name].concat(args));
        });
      }
    }
   
    self.on('action', onAction);

    /*
     * take the current actions and set up handlers for them
     */

    if (self.actions()) {
      self.actions().forEach(onAction);
    }


    /*
     * when we disconnect we want to remove the handlers and the onAction
     * method
     */

    socket.on('disconnect', function () {
      debug('on disconnect %s', socket.id);
      self.removeListener('action', onAction);
      self.actions().forEach(function (name) {
        debug('removing listeners for %s', name);
        socket.removeAllListeners(name);
        debug('listener count %s for %s', socket.listeners(name).length, name);
      });
    });

  };

  /*
   * Called when we receive data from the socket
   * It will build up the actor, target, and content
   * to produce a json object that will be published
   * onto an publisher / event emitter
   */

  this.onMessage = function (socket, args) {
    debug('on message %s', socket.id);
    args = args || [];
    if (!args.length) return;
    var message, isMessage = false;
    if (args.length === 2 && args[1] && args[1].isMessage) {
      isMessage = true;
      message = Message(args[1]);  
    }
    else {
      message = Message();
    }
    message.action(args.shift());
    self.actor(socket, function (err, actor) {
      debug('on actor %s, %s', socket.id, actor);
      if (err) {
        return self.emit('error', err, socket, args);
      }
      message.actor(actor);
      self.target(socket, args, function (err, target) {
        debug('on target %s, %s', socket.id, actor);
        if (err) {
          return self.emit('error', err, socket, args);
        }
        message.target(target);
        if (!isMessage) message.content(args);
        self.emit('message', message, socket);
      });
    });
  };

  /*
   * the middleware fucntion we attach to socket.io. It looks for events and if
   * we have auto propagation turned on it will trigger events that are *not*
   * in the current action set.
   */

  this.middleware = function (socket, next) {
    debug('middleware invoked on socket %s', socket.id);
    socket.onevent = self.onSocketEvent;
    next();
  };

  /*
   * The function we override the onevent with.
   */

  // TODO lets use socket.io-events

  this.onSocketEvent = function(packet) {
    debug('on socket event for socket %s', this.id);
    var args = packet.data || [];

    if (null != packet.id) {
      args.push(this.ack(packet.id));
    }

    if (this.listeners(args[0]).length) {
      events.EventEmitter.prototype.emit.apply(this, args);
    }
    else if (self.autoPropagate()) {
      self.onMessage(this, args);
    }

  };

  this.setMaxListeners(0);
}

util.inherits(Messages, events.EventEmitter);

/**
 * @api public
 * @return Messages
 */

Messages.make = function () {
  debug('make');
  return new Messages();
};

/**
 * Creates a new instance and has it listen to "io"
 *
 * @api public
 * @param {object} io
 * @return Messages
 */

Messages.listen = function (io) {
  debug('listen');
  var messages = this.make();
  messages.attach(io);
  return messages;
};

/**
 * Attaches our #onConnection method to the io object
 *
 * @api public
 * @param {object} io
 * @return Messages
 */

Messages.prototype.attach = function (io) {
  debug('attach');
  if (io.sockets.fns.indexOf(this.middleware) < 0) {
    io.use(this.middleware);
  }
  io.on('connection', this.onConnection);
  return this;
};

/**
 * Either sets the actor query method or invokes it
 *
 * Set
 *
 * @api public
 * @param {Function} o
 *
 * Invoke
 *
 * @param {Object} o The socket
 * @param {Function} cb
 *
 * @return Messages
 */

Messages.prototype.actor = function (o, cb) {
  debug('actor');
  var type = typeof o;  
  if (arguments.length === 0) {
    if (!this._actor) {
      this._actor = function (socket, cb) {
        if (typeof cb === 'function') {
          cb(null, socket.id);
        }
      };
    }
    return this._actor;
  }
  else if (arguments.length === 1) {
    if (type === 'undefined' || !o) {
      return this;
    }
    if (type === 'function') {
      this._actor = o
    }
  }
  else if (arguments.length > 1) {
    if (type !== 'function') {
      if (!this._actor) {
        this._actor = function (socket, cb) {
          if (typeof cb === 'function') {
            cb(null, socket.id);
          }
        };
      }
      this._actor(o, cb);
    }
  }
  return this;
};

/**
 * Either sets the target query method or invokes it
 *
 * Set
 *
 * @api public
 * @param {Function} o
 *
 * Invoke
 *
 * @param {Object} o The socket
 * @param {Array} p The arguments emitted from the socket
 * @param {Function} cb
 *
 * @return Messages
 */

Messages.prototype.target = function (o, p, cb) {
  debug('target');
  var type = typeof o;  
  if (arguments.length === 0) {
    if (!this._target) {
      this._target = function (socket, params, cb) {
        if (typeof cb === 'function') {
          cb(null, socket.id);
        }
      };
    }
    return this._target;
  }
  else if (arguments.length === 1) {
    if (type === 'undefined' || !o) {
      return this;
    }
    if (type === 'function') {
      this._target = o
    }
  }
  else if (arguments.length > 2) {
    if (type !== 'function') {
      if (!this._target) {
        this._target = function (sock, params, cb) {
          if (typeof cb === 'function') {
            if (params[0] && params[0].isMessage) {
              cb(null, params[0].target || sock.id);
            }
            else {
              cb(null, sock.id);
            }
          }
        };
      }
      this._target(o, p, cb);
    }
  }
  return this;
};

/**
 * Triggers the binding of an event handler to all sockets for the given event name
 *
 * @api public
 * @param {string} name
 * @return Messages
 */

Messages.prototype.action = function (name) {
  if (typeof name === 'string' && this.actions().indexOf(name) < 0) {
    debug('add action %s', name);
    this.actions().push(name)
    this.emit('action', name);
  }
  return this;
};

/**
 * initializes the actions we have set so fare
 *
 * @api public
 * @return Array
 */

Messages.prototype.actions = function () {
  if (!this._actions) {
    this._actions = [];
  }
  return this._actions;
};

/**
 * Gets / Sets the state of auto propagation
 *
 * @api public
 * @return Boolean
 */

Messages.prototype.autoPropagate = function (v) {
  debug('autoPropagate %s', v);
  if (typeof v === 'boolean') {
    this._autoPropagate = v;
    return this;
  }
  if (typeof this._autoPropagate !== 'boolean') {
    this.autoPropagate(false);
  }
  return this._autoPropagate;
};

