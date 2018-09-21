# Start a hubot, connected to our chat room.
'use strict'
model = share.model # import

# Log messages?
DEBUG = !Meteor.isProduction

BOTNAME = Meteor.settings?.botname or process.env.BOTNAME or 'codexbot'

# Monkey-patch Hubot to support private messages
Hubot.Response::priv = (strings...) ->
  @robot.adapter.priv @envelope, strings...
# More monkey-patching
Hubot.Robot::loadAdapter = -> # disable

# grrrr, Meteor.bindEnvironment doesn't preserve `this` apparently
bind = (f) ->
  g = Meteor.bindEnvironment (self, args...) -> f.apply(self, args)
  (args...) -> g @, args...

class Robot extends Hubot.Robot
  constructor: (args...) ->
    super args...
    @hear = bind @hear
    @respond = bind @respond
    @enter = bind @enter
    @leave = bind @leave
    @topic = bind @topic
    @error = bind @error
    @catchAll = bind @catchAll
  loadAdapter: -> false
  hear:    (regex, callback) -> super regex, Meteor.bindEnvironment callback
  respond: (regex, callback) -> super regex, Meteor.bindEnvironment callback
  enter: (callback) -> super Meteor.bindEnvironment(callback)
  leave: (callback) -> super Meteor.bindEnvironment(callback)
  topic: (callback) -> super Meteor.bindEnvironment(callback)
  error: (callback) -> super Meteor.bindEnvironment(callback)
  catchAll: (callback) -> super Meteor.bindEnvironment(callback)

sendHelper = Meteor.bindEnvironment (robot, envelope, strings, map) ->
  # be present in the room
  try
    Meteor.callAs 'setPresence', 'codexbot',
      room_name: envelope.room
      present: true
      foreground: true
  props = Object.create(null)
  lines = []
  while strings.length > 0
    if typeof(strings[0]) is 'function'
      strings[0] = strings[0]()
      continue
    string = strings.shift()
    if typeof(string) is 'object'
      Object.assign props, string
      continue
    if string?
      lines.push string
  if lines.length and envelope.message.direct and (not props.useful)
    model.Messages.update envelope.message.id, $set: useless_cmd: true
  lines.map (line) ->
    try
      map(line, props)
    catch err
      console.error "Hubot error: #{err}" if DEBUG
      robot.logger.error "Blackboard send error: #{err}"

tweakStrings = (strings, f) -> strings.map (obj) ->
  if typeof(obj) == 'string' then f(obj) else obj

class BlackboardAdapter extends Hubot.Adapter
  # Public: Raw method for sending data back to the chat source. Extend this.
  #
  # envelope - A Object with message, room and user details.
  # strings  - One or more Strings for each message to send.
  #
  # Returns nothing.
  send: (envelope, strings...) ->
    return @priv envelope, strings... if envelope.message.private
    sendHelper @robot, envelope, strings, (string, props) ->
      console.log "send #{envelope.room}: #{string} (#{envelope.user.id})" if DEBUG
      if envelope.message.direct and (not props.useful)
        unless string.startsWith(envelope.user.id)
          string = "#{envelope.user.id}: #{string}"
      Meteor.callAs "newMessage", 'codexbot', Object.assign {}, props,
        body: string
        room_name: envelope.room
        bot_ignore: true

  # Public: Raw method for sending emote data back to the chat source.
  #
  # envelope - A Object with message, room and user details.
  # strings  - One or more Strings for each message to send.
  #
  # Returns nothing.
  emote: (envelope, strings...) ->
    if envelope.message.private
        return @priv envelope, tweakStrings(strings, (s) -> "*** #{s} ***")...
    sendHelper @robot, envelope, strings, (string, props) ->
      console.log "emote #{envelope.room}: #{string} (#{envelope.user.id})" if DEBUG
      Meteor.callAs "newMessage", 'codexbot', Object.assign {}, props,
        body: string
        room_name: envelope.room
        action: true
        bot_ignore: true

  # Priv: our extension -- send a PM to user
  priv: (envelope, strings...) ->
    sendHelper @robot, envelope, strings, (string, props) ->
      console.log "priv #{envelope.room}: #{string} (#{envelope.user.id})" if DEBUG
      Meteor.callAs "newMessage", 'codexbot', Object.assign {}, props,
        to: "#{envelope.user.id}"
        body: string
        room_name: envelope.room
        bot_ignore: true

  # Public: Raw method for building a reply and sending it back to the chat
  # source. Extend this.
  #
  # envelope - A Object with message, room and user details.
  # strings  - One or more Strings for each reply to send.
  #
  # Returns nothing.
  reply: (envelope, strings...) ->
    if envelope.message.private
      @priv envelope, strings...
    else
      @send envelope, tweakStrings(strings, (str) -> "#{envelope.user.id}: #{str}")...

  # Public: Raw method for setting a topic on the chat source. Extend this.
  #
  # envelope - A Object with message, room and user details.
  # strings  - One more more Strings to set as the topic.
  #
  # Returns nothing.
  topic: (envelope, strings...) ->

  # Public: Raw method for playing a sound in the chat source. Extend this.
  #
  # envelope - A Object with message, room and user details.
  # strings  - One or more strings for each play message to send.
  #
  # Returns nothing
  play: (envelope, strings...) ->

  # Public: Raw method for invoking the bot to run. Extend this.
  #
  # Returns nothing.
  run: ->

  # Public: Raw method for shutting the bot down. Extend this.
  #
  # Returns nothing.
  close: ->

return unless share.DO_BATCH_PROCESSING
IGNORED_NICKS =
  'codexbot': true
  '': true
Meteor.startup ->
  robot = new Robot null, null, false, BOTNAME
  robot.alias = 'bot'
  adapter = robot.adapter = new BlackboardAdapter robot
  # what's (the regexp for) my name?
  robot.respond /(?:)/, -> false
  mynameRE = robot.listeners.pop().regex
  # register scripts
  HubotScripts(robot)
  Object.keys(share.hubot).forEach (scriptName) ->
    console.log "Loading hubot script: #{scriptName}"
    share.hubot[scriptName](robot)
  robot.brain.emit('loaded')
  # register our nick
  Meteor.users.upsert 'codexbot',
    $set:
      nickname: 'codexbot'
      gravatar: 'codex@printf.net'
    $unset: services: ''
  # register our presence in general chat
  keepalive = -> Meteor.callAs 'setPresence', 'codexbot',
    room_name: 'general/0'
    present: true
    foreground: true
  keepalive()
  Meteor.setInterval keepalive, 30*1000 # every 30s refresh presence
  # listen to the chat room, ignoring messages sent before we startup
  startup = true
  model.Messages.find({}).observeChanges
    added: (id, msg) ->
      return if startup
      return if msg.bot_ignore
      return if IGNORED_NICKS[msg.nick]?
      return if msg.system or msg.action or msg.oplog or msg.bodyIsHtml
      console.log "Received from #{msg.nick} in #{msg.room_name}: #{msg.body}"\
        if DEBUG
      user = new Hubot.User(msg.nick, room: msg.room_name)
      tm = new Hubot.TextMessage(user, msg.body, id)
      tm.private = msg.to?
      # if private, ensure it's treated as a direct address
      if tm.private and not mynameRE.test(tm.text)
        tm.text = "#{robot.name} #{tm.text}"
      tm.direct = mynameRE.test(tm.text)
      adapter.receive tm
  startup = false
  Meteor.callAs "newMessage", 'codexbot',
    body: 'wakes up'
    room_name: 'general/0'
    action: true
    bot_ignore: true
