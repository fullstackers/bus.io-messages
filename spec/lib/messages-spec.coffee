EventEmitter = require('events').EventEmitter

describe 'Messages', ->

  Given ->
    @Message = class Message
      constructor: ->
        if not (@ instanceof Message)
          return new Message
        @data =
          actor: 'me'
          action: 'say'
          content: 'hello'
          target: 'you'
          created: new Date
          reference: null
          id: 1
      actor: -> @data.actor
      target: -> @data.target
      content: -> @data.content
      action: -> @data.action
      clone: ->
        return new Message

  Given -> @Messages = requireSubject 'lib/messages', {
    'bus.io-common': @Message
  }

  Given ->
    @io = new EventEmitter
    @io.sockets = fns: []
    @io.use = (fn) -> @sockets.fns.push fn
    spyOn(@io,['on']).andCallThrough()
    spyOn(@io,['removeListener']).andCallThrough()
    spyOn(@io,['use']).andCallThrough()

  describe '#', ->
    When -> @res = @Messages()
    Then -> expect(@res instanceof @Messages).toBe true

  describe '#make', ->
    When -> @res = @Messages.make()
    Then -> expect(@res instanceof @Messages).toBe true
  
  describe '#listen', ->
    Given -> spyOn(@Messages,['make']).andCallThrough()
    When -> @res = @Messages.listen @io
    Then -> expect(@Messages.make).toHaveBeenCalled()
    And -> expect(@io.on).toHaveBeenCalledWith 'connection', @res.onConnection

  context 'an instance', ->

    Given ->
      @socket = new EventEmitter
      @socket.handshake =
        session:
          name: 'I'
      @socket.id = 'Me'
      spyOn(@socket,['emit']).andCallThrough()
      spyOn(@socket,['on']).andCallThrough()
    Given ->
      @instance = new @Messages
      spyOn(@instance,['emit']).andCallThrough()

    describe '#attach', ->

      When -> @instance.attach @io
      Then -> expect(@io.on).toHaveBeenCalledWith 'connection', @instance.onConnection
      And -> expect(@io.use).toHaveBeenCalledWith @instance.middleware

    describe '#actor', ->

      Given -> @fn = (socket, cb) ->
        cb null, socket.handshake.session.name

      context 'with a function', ->

        When -> @res = @instance.actor(@fn).actor()
        Then -> expect(@res).toBe @fn

      context 'with an object, and callback', ->

        context 'with the default method', ->

          Given -> @cb = jasmine.createSpy 'cb'
          When -> @instance.actor @socket, @cb
          Then -> expect(@cb).toHaveBeenCalledWith null, 'Me'

        context 'with a custom method', ->

          Given -> @cb = jasmine.createSpy 'cb'
          Given -> @instance.actor @fn
          When -> @instance.actor @socket, @cb
          Then -> expect(@cb).toHaveBeenCalledWith null, 'I'

    describe '#target', ->

      Given -> @fn = (socket, params, cb) ->
        cb null, params.shift()

      context 'with a function', ->

        When -> @res = @instance.target(@fn).target()
        Then -> expect(@res).toBe @fn

      context 'with param list, and callback', ->

        Given -> @params = ['You']

        context 'with the default method', ->

          Given -> @cb = jasmine.createSpy 'cb'
          When -> @instance.target @socket, @params, @cb
          Then -> expect(@cb).toHaveBeenCalledWith null, 'Me'

        context 'with a custom method', ->

          Given -> @cb = jasmine.createSpy 'cb'
          Given -> @instance.target @fn
          When -> @instance.target @socket, @params, @cb
          Then -> expect(@cb).toHaveBeenCalledWith null, 'You'

    describe '#actions', ->

      When -> @res = @instance.actions()
      Then -> expect(@res).toEqual []

    describe '#action', ->

      Given -> @name = 'say'
      When -> @instance.action @name
      Then -> expect(@instance.emit).toHaveBeenCalledWith 'action', @name
      And -> expect(@instance.actions()).toEqual [@name]

    describe '#onConnection', ->

      Given -> @other = 'other'
      Given -> @name = 'say'
      When ->
        @instance.action @other
        @instance.onConnection @socket
        @instance.action @name
      Then -> expect(@socket.on).toHaveBeenCalledWith @name, jasmine.any(Function)
      And -> expect(@socket.listeners(@other).length).toBe 1
      And -> expect(@socket.listeners(@name).length).toBe 1

      describe 'socket emits action', ->
        Given -> @a = 'you'
        Given -> @b = 'what'
        Given -> spyOn(@instance,['onMessage'])
        When -> @socket.emit @name, @a, @b
        Then -> expect(@instance.onMessage).toHaveBeenCalledWith @socket, [@name, @a, @b]

      describe 'when the socket is disconnected', ->
        Given -> spyOn(@socket,['removeAllListeners']).andCallThrough()
        When -> @socket.emit 'disconnect'
        Then -> expect(@instance.listeners('action').length).toBe 0
        And -> expect(@socket.listeners(@other).length).toBe 0
        And -> expect(@socket.listeners(@name).length).toBe 0
        And -> expect(@socket.removeAllListeners).toHaveBeenCalled()

    describe '#onMessage', ->
      Given -> @actor = 'I'
      Given -> @action = 'say'
      Given -> @target = 'You'
      Given -> @content = 'what'
      Given -> @params = [@action, @target, @content]
      Given -> spyOn(@instance,['actor']).andCallThrough()
      Given -> spyOn(@instance,['target']).andCallThrough()
      Given -> @instance.actor (socket, cb) -> cb null, socket.handshake.session.name
      Given -> @instance.target (socket, args, cb) -> cb null, args.shift()
      When -> @instance.onMessage @socket, @params
      Then -> expect(@instance.actor).toHaveBeenCalledWith @socket, jasmine.any(Function)
      And -> expect(@instance.target).toHaveBeenCalledWith @socket, [@content], jasmine.any(Function)
      And -> expect(@instance.emit).toHaveBeenCalled()
      And -> expect(@instance.emit.mostRecentCall.args[0]).toBe 'message'
      And -> expect(@instance.emit.mostRecentCall.args[1].data.created instanceof Date).toBe true
      And -> expect(@instance.emit.mostRecentCall.args[1].data.actor).toBe @actor
      And -> expect(@instance.emit.mostRecentCall.args[1].data.target).toBe @target
      And -> expect(@instance.emit.mostRecentCall.args[1].data.action).toBe @action
      And -> expect(@instance.emit.mostRecentCall.args[1].data.content).toEqual [@content]
      And -> expect(@instance.emit.mostRecentCall.args[2]).toEqual @socket

    describe '#autoPropagate', ->

      Then -> expect(@instance.autoPropagate()).toBe false

    describe '#autoPropagate (v:Boolean=false)', ->

      When -> @instance.autoPropagate false
      Then -> expect(@instance.autoPropagate()).toBe false

    describe '#autoPropagate (v:Boolean=true)', ->

      When -> @instance.autoPropagate true
      Then -> expect(@instance.autoPropagate()).toBe true

    describe '#middleware (socket:Object, next:Function)', ->

      Given -> @socket = new EventEmitter
      Given -> @next = jasmine.createSpy 'next'
      When -> @instance.middleware @socket, @next
      Then -> expect(@socket.onevent).toBe @instance.onSocketEvent
      And -> expect(@next).toHaveBeenCalled()

    describe '#onSocketEvent (packet:Object)', ->

      context 'autoPropagation(v:Boolean=false)', ->

        Given -> spyOn(EventEmitter.prototype.emit,['apply']).andCallThrough()
        Given -> @socket = new EventEmitter
        Given -> @cb = jasmine.createSpy 'cb'
        Given -> @socket.addListener 'test', @cb
        Given -> spyOn(@socket,['emit']).andCallThrough()
        Given -> @fn = ->
        Given -> @socket.ack = (a) => @fn
        Given -> spyOn(@socket,['ack']).andCallThrough()
        Given -> @socket.onSocketEvent = @instance.onSocketEvent
        Given -> @packet = id: 1, data: ['test']
        Given -> @instance.autoPropagate false
        When -> @socket.onSocketEvent @packet
        Then -> expect(@socket.ack).toHaveBeenCalledWith @packet.id
        And -> expect(EventEmitter.prototype.emit.apply).toHaveBeenCalledWith @socket, ['test', @fn]
        And -> expect(@cb).toHaveBeenCalledWith @fn

      context 'autoPropagation(v:Boolean=true)', ->

        Given -> spyOn(@instance,['onMessage'])
        Given -> @socket = new EventEmitter
        Given -> spyOn(@socket,['emit']).andCallThrough()
        Given -> @fn = ->
        Given -> @socket.ack = (a) => @fn
        Given -> spyOn(@socket,['ack']).andCallThrough()
        Given -> @socket.onSocketEvent = @instance.onSocketEvent
        Given -> @packet = id: 1, data: ['test']
        Given -> @instance.autoPropagate true
        When -> @socket.onSocketEvent @packet
        Then -> expect(@socket.ack).toHaveBeenCalledWith @packet.id
        And -> expect(@instance.onMessage).toHaveBeenCalledWith @socket, ['test', @fn]
