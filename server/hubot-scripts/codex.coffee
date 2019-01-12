# Description:
#   Utility commands for Codexbot
#
# Commands:
#   hubot bot: The answer to <puzzle> is <answer>
#   hubot bot: Call in <answer> [for <puzzle>]
#   hubot bot: Delete the answer to <puzzle>
#   hubot bot: <puzzle> is a new puzzle in round <round>
#   hubot bot: Delete puzzle <puzzle>
#   hubot bot: <round> is a new round in group <group>
#   hubot bot: Delete round <name>
#   hubot bot: <roundgroup> is a new round group
#   hubot bot: Delete round group <roundgroup>
#   hubot bot: New quip: <quip>
#   hubot bot: stuck [on <puzzle>] [because <reason>]
#   hubot bot: unstuck [on <puzzle>]
#   hubot bot: announce <message>

# helper function: concat regexes
rejoin = (regs...) ->
  [...,last] = regs
  flags = if last instanceof RegExp
    # use the flags of the last regexp, if there are any
    ( /\/([gimy]*)$/.exec last.toString() )?[1]
  else if typeof last is 'object'
    # use the flags property of the last object parameter
    regs.pop().flags
  return new RegExp( regs.reduce( (acc,r) ->
    acc + if r instanceof RegExp then r.source else r
  , '' ), flags ? '')

# regexp for puzzle/round/group name, w/ optional quotes
# don't allow empty strings to be things, that's just confusing
# leading and trailing spaces should not be taken (unless in quotes)
thingRE = /// (
 \"(?: [^\"\\] | \\\" )+\" |
 \'(?: [^\'\\] | \\\' )+\' |
 \S(?:.*?\S)?
) ///
strip = (s) ->
  if (/^[\"\']/.test s) and s[0] == s[s.length-1]
    try return JSON.parse(s)
  s

# BEWARE: regular expressions can't start with whitespace in coffeescript
# (https://github.com/jashkenas/coffeescript/issues/3756)
# We need to use a backslash escape as a workaround.

share.hubot.codex = (robot) ->

## ANSWERS

# setAnswer
  robot.commands.push 'bot the answer to <puzzle> is <answer> - Updates codex blackboard'
  robot.respond (rejoin /The answer to /,thingRE,/\ is /,thingRE,/$/i), (msg) ->
    name = strip msg.match[1]
    answer = strip msg.match[2]
    who = msg.envelope.user.id
    target = Meteor.callAs "getByName", who,
      name: name
      optional_type: "puzzles"
    if not target
      target = Meteor.callAs "getByName", who,
        name: name
    if not target
      msg.reply useful: true, "I can't find a puzzle called \"#{name}\"."
      return msg.finish()
    res = Meteor.callAs "setAnswer", who,
      type: target.type
      target: target.object._id
      answer: answer
    unless res
      msg.reply useful: true, msg.random ["I knew that!","Not news to me.","Already known.", "It is known.", "So say we all."]
      return
    solution_banter = [
      "Huzzah!"
      "Yay!"
      "Pterrific!"
      "I'm codexstactic!"
      "Who'd have thought?"
      "#{answer}?  Really?  Whoa."
      "Rock on!"
      "#{target.object.name} bites the dust!"
      "#{target.object.name}, meet #{answer}.  We rock!"
    ]
    msg.reply useful: true, msg.random solution_banter
    msg.finish()

  # helper function
  objectFromRoom = (msg) ->
    # get puzzle id from room name
    room = msg.envelope.room
    who = msg.envelope.user.id
    [type,id] = room.split('/', 2)
    if type is "general"
      msg.reply useful: true, "You need to tell me which puzzle this is for."
      msg.finish()
      return
    unless type is 'puzzles' or type is 'rounds' or type is 'roundgroups'
      msg.reply useful: true, "I don't understand the type: #{type}."
      msg.finish()
      return
    object = Meteor.callAs "get", who, type, id
    unless object
      msg.reply useful: true, "Something went wrong.  I can't look up #{room}."
      msg.finish()
      return
    {type: type, object: object}

  # newCallIn
  robot.commands.push 'bot call in <answer> [for <puzzle>] - Updates codex blackboard'
  robot.respond (rejoin /Call\s*in((?: (?:backsolved?|provided))*)( answer)? /,thingRE,'(?:',/\ for (?:(puzzle|round|round group) )?/,thingRE,')?',/$/i), (msg) ->
    backsolve = /backsolve/.test(msg.match[1])
    provided = /provided/.test(msg.match[1])
    answer = strip msg.match[3]
    type = if msg.match[4]? then msg.match[4].replace(/\s+/g,'')+'s'
    name = if msg.match[5]? then strip msg.match[5]
    who = msg.envelope.user.id
    if name?
      target = Meteor.callAs "getByName", who,
        name: name
        optional_type: type ? "puzzles"
      if not target and not type?
        target = Meteor.callAs "getByName", who, name: name
      if not target
        msg.reply useful: true, "I can't find a puzzle called \"#{name}\"."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    Meteor.callAs "newCallIn", who,
      type: target.type
      target: target.object._id
      answer: answer
      backsolve: backsolve
      provided: provided
      # I don't mind a little redundancy, but if it bothers you uncomment this:
      #suppressRoom: msg.envelope.room
    msg.reply useful: true, "Okay, \"#{answer}\" for #{target.object.name} added to call-in list!"
    msg.finish()

# deleteAnswer
  robot.commands.push 'bot delete the answer to <puzzle> - Updates codex blackboard'
  robot.respond (rejoin /Delete( the)? answer (to|for)( puzzle)? /,thingRE,/$/i), (msg) ->
    name = strip msg.match[4]
    who = msg.envelope.user.id
    target = Meteor.callAs "getByName", who,
      name: name
      optional_type: "puzzles"
    if not target
      target = Meteor.callAs "getByName", who, name: name
    if not target
      msg.reply useful: true, "I can't find a puzzle called \"#{name}\"."
      return
    Meteor.callAs "deleteAnswer", who,
      type: target.type
      target: target.object._id
    msg.reply useful: true, "Okay, I deleted the answer to \"#{target.object.name}\"."
    msg.finish()

## PUZZLES

# newPuzzle
  robot.commands.push 'bot <puzzle> is a new puzzle in round <round> - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new puzzle in( round)? /,thingRE,/$/i), (msg) ->
    pname = strip msg.match[1]
    rname = strip msg.match[3]
    who = msg.envelope.user.id
    round = Meteor.callAs "getByName", who,
      name: rname
      optional_type: "rounds"
    if not round
      msg.reply useful: true, "I can't find a round called \"#{rname}\"."
      return
    puzzle = Meteor.callAs "newPuzzle", who,
      name: pname
    Meteor.callAs "addPuzzleToRound", who,
      round: round.object._id
      puzzle: puzzle._id
    puzz_url = Meteor._relativeToSiteRootUrl "/puzzles/#{puzzle._id}"
    round_url = Meteor._relativeToSiteRootUrl "/rounds/#{round.object._id}"
    msg.reply {useful: true, bodyIsHtml: true}, "Okay, I added <a class='puzzles-link' href='#{UI._escape puzz_url}'>#{UI._escape puzzle.name}</a> to <a class='rounds-link' href='#{UI._escape round_url}'>#{UI._escape round.object.name}</a>."
    msg.finish()

# deletePuzzle
  robot.commands.push 'bot delete puzzle <puzzle> - Updates codex blackboard'
  robot.respond (rejoin /Delete puzzle /,thingRE,/$/i), (msg) ->
    name = strip msg.match[1]
    who = msg.envelope.user.id
    puzzle = Meteor.callAs "getByName", who,
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply useful: true, "I can't find a puzzle called \"#{name}\"."
      return
    res = Meteor.callAs "deletePuzzle", who, puzzle.object._id
    if res
      msg.reply useful: true, "Okay, I deleted \"#{puzzle.object.name}\"."
    else
      msg.reply useful: true, "Something went wrong."
    msg.finish()

## ROUNDS

# newRound
  robot.commands.push 'bot <round> is a new round in group <group> - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new round in( group)? /,thingRE,/$/i), (msg) ->
    rname = strip msg.match[1]
    gname = strip msg.match[3]
    who = msg.envelope.user.id
    group = Meteor.callAs "getByName", who,
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply useful: true, "I can't find a round group called \"#{gname}\"."
      return
    round = Meteor.callAs "newRound", who,
      name: rname
    unless round
      msg.reply useful: true, "Something went wrong (couldn't create new round)."
      return
    res = Meteor.callAs "addRoundToGroup", who,
      round: round._id
      group: group.object._id
    unless res
      msg.reply useful: true, "Something went wrong (couldn't add round to group)"
      return
    round_url = Meteor._relativeToSiteRootUrl "/rounds/#{round._id}"
    group_url = Meteor._relativeToSiteRootUrl "/roundgroups/#{group.object._id}"
    msg.reply {useful: true, bodyIsHtml: true}, "Okay, I created round <a class='rounds-link' href='#{UI._escape round_url}'>#{UI._escape rname}</a> in <a class='roundgroups-link' href='#{UI._escape group_url}'>#{UI._escape group.object.name}</a>."
    msg.finish()

# deleteRound
  robot.commands.push 'bot delete round <round> - Updates codex blackboard'
  robot.respond (rejoin /Delete round /,thingRE,/$/i), (msg) ->
    rname = strip msg.match[1]
    who = msg.envelope.user.id
    round = Meteor.callAs "getByName", who,
      name: rname
      optional_type: "rounds"
    unless round
      msg.reply useful: true, "I can't find a round called \"#{rname}\"."
      return
    res = Meteor.callAs "deleteRound", who, round.object._id
    unless res
      msg.reply useful: true, "Couldn't delete round. (Are there still puzzles in it?)"
      return
    msg.reply useful: true, "Okay, I deleted round \"#{round.object.name}\"."
    msg.finish()

## ROUND GROUPS

# newRoundGroup
  robot.commands.push 'bot <group> is a new round group - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new round group$/i), (msg) ->
    gname = strip msg.match[1]
    who = msg.envelope.user.id
    group = Meteor.callAs "newRoundGroup", who, name: gname
    msg.reply useful: true, "Okay, I created round group \"#{group.name}\"."
    msg.finish()

# deleteRoundGroup
  robot.commands.push 'bot delete round group <group> - Updates codex blackboard'
  robot.respond (rejoin /Delete round group /,thingRE,/$/i), (msg) ->
    gname = strip msg.match[1]
    who = msg.envelope.user.id
    group = Meteor.callAs "getByName", who,
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply useful: true, "I can't find a round group called \"#{gname}\"."
      return
    res = Meteor.callAs "deleteRoundGroup", who, group.object._id
    unless res
      msg.reply useful: true, "Somthing went wrong."
      return
    msg.reply useful: true, "Okay, I deleted round group \"#{gname}\"."
    msg.finish()

# Quips
  robot.commands.push 'bot new quip <quip> - Updates codex quips list'
  robot.respond (rejoin /new quip:? /,thingRE,/$/i), (msg) ->
    text = strip msg.match[1]
    who = msg.envelope.user.id
    quip = Meteor.callAs "newQuip", who, text
    msg.reply "Okay, added quip.  I'm naming this one \"#{quip.name}\"."
    msg.finish()

# Tags
  robot.commands.push 'bot set <tag> [of <puzzle|round>] to <value> - Adds additional information to blackboard'
  robot.respond (rejoin /set (?:the )?/,thingRE,'(',/\ (?:of|for) (?:(puzzle|round|round group) )?/,thingRE,')? to ',thingRE,/$/i), (msg) ->
    tag_name = strip msg.match[1]
    tag_value = strip msg.match[5]
    who = msg.envelope.user.id
    if msg.match[2]?
      type = if msg.match[3]? then msg.match[3].replace(/\s+/g,'')+'s'
      target = Meteor.callAs 'getByName', who,
        name: strip msg.match[4]
        optional_type: type
      if not target?
        msg.reply useful: true, "I can't find a puzzle called \"#{strip msg.match[4]}\"."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    Meteor.callAs 'setTag', who,
      type: target.type
      object: target.object._id
      name: tag_name
      value: tag_value
    msg.reply useful: true, "The #{tag_name} for #{target.object.name} is now \"#{tag_value}\"."
    msg.finish()

# Stuck
  robot.commands.push 'bot stuck[ on <puzzle|round>][ because <reason>] - summons help and marks puzzle as stuck on the blackboard'
  robot.respond (rejoin 'stuck(?: on ',thingRE,')?(?: because ',thingRE,')?',/$/i), (msg) ->
    who = msg.envelope.user.id
    if msg.match[1]?
      target = Meteor.callAs 'getByName', who, name: msg.match[1]
      if not target?
        msg.reply useful: true, "I don't know what \"#{msg.match[1]}\" is."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    result = Meteor.callAs 'summon', who,
      type: target.type
      object: target.object._id
      how: msg.match[2]
    if result?
      msg.reply useful: true, result
      return msg.finish()
    if msg.envelope.room isnt "general/0" and \
       msg.envelope.room isnt "#{target.type}/#{target.object._id}"
      msg.reply useful: true, "Help is on the way."
    msg.finish()

  robot.commands.push 'but unstuck[ on <puzzle|round>] - marks puzzle no longer stuck on the blackboard'
  robot.respond (rejoin 'unstuck(?: on ',thingRE,')?',/$/i), (msg) ->
    who = msg.envelope.user.id
    if msg.match[1]?
      target = Meteor.callAs 'getByName', who, name: msg.match[1]
      if not target?
        msg.reply useful: true, "I don't know what \"#{msg.match[1]}\" is."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    result = Meteor.callAs 'unsummon', who,
      type: target.type
      object: target.object._id
    if result?
      msg.reply useful: true, result
      return msg.finish()
    if msg.envelope.room isnt "general/0" and \
       msg.envelope.room isnt "#{target.type}/#{target.object._id}"
      msg.reply useful: true, "Call for help cancelled"
    msg.finish()

  robot.commands.push 'bot announce <message>'
  robot.respond /announce (.*)$/i, (msg) ->
    Meteor.callAs 'newMessage', msg.envelope.user.id,
      oplog: true
      body: "Announcement: #{msg.match[1]}"
      stream: 'announcements'
    msg.finish()

  wordOrQuote = /([^\"\'\s]+|\"[^\"]+\"|\'[^\']+\')/

  robot.commands.push 'bot poll "Your question" "option 1" "option 2"...'
  robot.respond (rejoin 'poll ', wordOrQuote, '((?: ', wordOrQuote, ')+)', /$/i), (msg) ->
    optsRe = new RegExp rejoin(' ', wordOrQuote), 'g'
    opts = while m = optsRe.exec msg.match[2]
      strip m[1]
    Meteor.callAs 'newPoll', msg.envelope.user.id, msg.envelope.room, strip(msg.match[1]), opts

