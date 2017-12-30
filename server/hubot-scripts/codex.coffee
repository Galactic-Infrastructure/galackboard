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
  (try return JSON.parse(s)) if (/^[\"\']/.test s) and s[0] == s[s.length-1]
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
    target = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not target
      target = Meteor.call "getByName",
        name: name
    if not target
      msg.reply new share.Useful, "I can't find a puzzle called \"#{name}\"."
      return msg.finish()
    res = Meteor.call "setAnswer",
      type: target.type
      target: target.object._id
      answer: answer
      who: who
    unless res
      msg.reply new share.Useful, msg.random ["I knew that!","Not news to me.","Already known."]
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
    msg.reply new share.Useful, msg.random solution_banter
    msg.finish()

  # helper function
  objectFromRoom = (msg) ->
    # get puzzle id from room name
    room = msg.envelope.room
    [type,id] = room.split('/', 2)
    if type is "general"
      msg.reply new share.Useful, "You need to tell me which puzzle this is for."
      msg.finish()
      return
    unless type is 'puzzles' or type is 'rounds' or type is 'roundgroups'
      msg.reply new share.Useful, "I don't understand the type: #{type}."
      msg.finish()
      return
    object = Meteor.call "get", type, id
    unless object
      msg.reply new share.Useful, "Something went wrong.  I can't look up #{room}."
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
      target = Meteor.call "getByName",
        name: name
        optional_type: type ? "puzzles"
      if not target and not type?
        target = Meteor.call "getByName",
          name: name
      if not target
        msg.reply new share.Useful, "I can't find a puzzle called \"#{name}\"."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    Meteor.call "newCallIn",
      type: target.type
      target: target.object._id
      answer: answer
      who: who
      backsolve: backsolve
      provided: provided
    if target.type is "puzzles"
      round = share.model.Rounds.findOne(puzzles: target.object._id)
    unless msg.envelope.room is "general/0" or \
           msg.envelope.room is "#{target.type}/#{target.object._id}" or \
           (round? and msg.envelope.room is "rounds/#{round._id}")
      msg.reply new share.Useful, "Okay, \"#{answer}\" for #{target.object.name} added to call-in list!"
    msg.finish()

# deleteAnswer
  robot.commands.push 'bot delete the answer to <puzzle> - Updates codex blackboard'
  robot.respond (rejoin /Delete( the)? answer (to|for)( puzzle)? /,thingRE,/$/i), (msg) ->
    name = strip msg.match[4]
    who = msg.envelope.user.id
    target = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not target
      target = Meteor.call "getByName",
        name: name
    if not target
      msg.reply new share.Useful, "I can't find a puzzle called \"#{name}\"."
      return
    Meteor.call "deleteAnswer",
      type: target.type
      puzzle: target.object._id
      who: who
    msg.reply new share.Useful, "Okay, I deleted the answer to \"#{target.object.name}\"."
    msg.finish()

## PUZZLES

# newPuzzle
  robot.commands.push 'bot <puzzle> is a new puzzle in round <round> - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new puzzle in( round)? /,thingRE,/$/i), (msg) ->
    pname = strip msg.match[1]
    rname = strip msg.match[3]
    who = msg.envelope.user.id
    round = Meteor.call "getByName",
      name: rname
      optional_type: "rounds"
    if not round
      msg.reply new share.Useful, "I can't find a round called \"#{rname}\"."
      return
    puzzle = Meteor.call "newPuzzle",
      name: pname
      who: who
    Meteor.call "addPuzzleToRound",
      round: round.object._id
      puzzle: puzzle._id
      who: who
    msg.reply new share.Useful, "Okay, I added #{puzzle.name} to #{round.object.name}."
    msg.finish()

# deletePuzzle
  robot.commands.push 'bot delete puzzle <puzzle> - Updates codex blackboard'
  robot.respond (rejoin /Delete puzzle /,thingRE,/$/i), (msg) ->
    name = strip msg.match[1]
    who = msg.envelope.user.id
    puzzle = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply new share.Useful, "I can't find a puzzle called \"#{name}\"."
      return
    res = Meteor.call "deletePuzzle",
      id: puzzle.object._id
      who: who
    if res
      msg.reply new share.Useful, "Okay, I deleted \"#{puzzle.object.name}\"."
    else
      msg.reply new share.Useful, "Something went wrong."
    msg.finish()

## ROUNDS

# newRound
  robot.commands.push 'bot <round> is a new round in group <group> - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new round in( group)? /,thingRE,/$/i), (msg) ->
    rname = strip msg.match[1]
    gname = strip msg.match[3]
    who = msg.envelope.user.id
    group = Meteor.call "getByName",
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply new share.Useful, "I can't find a round group called \"#{gname}\"."
      return
    round = Meteor.call "newRound",
      name: rname
      who: who
    unless round
      msg.reply new share.Useful, "Something went wrong (couldn't create new round)."
      return
    res = Meteor.call "addRoundToGroup",
      round: round._id
      group: group.object._id
      who: who
    unless res
      msg.reply new share.Useful, "Something went wrong (couldn't add round to group)"
      return
    msg.reply new share.Useful, "Okay, I created round \"#{rname}\" in #{group.object.name}."
    msg.finish()

# deleteRound
  robot.commands.push 'bot delete round <round> - Updates codex blackboard'
  robot.respond (rejoin /Delete round /,thingRE,/$/i), (msg) ->
    rname = strip msg.match[1]
    who = msg.envelope.user.id
    round = Meteor.call "getByName",
      name: rname
      optional_type: "rounds"
    unless round
      msg.reply new share.Useful, "I can't find a round called \"#{rname}\"."
      return
    res = Meteor.call "deleteRound",
      id: round.object._id
      who: who
    unless res
      msg.reply new share.Useful, "Couldn't delete round. (Are there still puzzles in it?)"
      return
    msg.reply new share.Useful, "Okay, I deleted round \"#{round.object.name}\"."
    msg.finish()

## ROUND GROUPS

# newRoundGroup
  robot.commands.push 'bot <group> is a new round group - Updates codex blackboard'
  robot.respond (rejoin thingRE,/\ is a new round group$/i), (msg) ->
    gname = strip msg.match[1]
    group = Meteor.call "newRoundGroup",
      name: gname
      who: "codexbot"
    msg.reply new share.Useful, "Okay, I created round group \"#{group.name}\"."
    msg.finish()

# deleteRoundGroup
  robot.commands.push 'bot delete round group <group> - Updates codex blackboard'
  robot.respond (rejoin /Delete round group /,thingRE,/$/i), (msg) ->
    gname = strip msg.match[1]
    who = msg.envelope.user.id
    group = Meteor.call "getByName",
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply new share.Useful, "I can't find a round group called \"#{gname}\"."
      return
    res = Meteor.call "deleteRoundGroup",
      id: group.object._id
      who: who
    unless res
      msg.reply new share.Useful, "Somthing went wrong."
      return
    msg.reply new share.Useful, "Okay, I deleted round group \"#{gname}\"."
    msg.finish()

# Quips
  robot.commands.push 'bot new quip <quip> - Updates codex quips list'
  robot.respond (rejoin /new quip:? /,thingRE,/$/i), (msg) ->
    text = strip msg.match[1]
    who = msg.envelope.user.id
    quip = Meteor.call "newQuip",
      text: text
      who: who
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
      target = Meteor.call 'getByName',
        name: strip msg.match[4]
        optional_type: type
      if not target?
        msg.reply new share.Useful, "I can't find a puzzle called \"#{strip msg.match[4]}\"."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    Meteor.call 'setTag',
      type: target.type
      object: target.object._id
      name: tag_name
      value: tag_value
      who: who
    msg.reply new share.Useful, "The #{tag_name} for #{target.object.name} is now \"#{tag_value}\"."
    msg.finish()

# Stuck
  robot.commands.push 'bot stuck[ on <puzzle|round>][ because <reason>]'
  robot.respond (rejoin 'stuck(?: on ',thingRE,')?(?: because ',thingRE,')?',/$/i), (msg) ->
    if msg.match[1]?
      target = Meteor.call 'getByName', name: msg.match[1]
      if not target?
        msg.reply new share.Useful, "I don't know what \"#{msg.match[1]}\" is."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    result = Meteor.call 'summon',
      type: target.type
      object: target.object._id
      value: msg.match[2]
      who: msg.envelope.user.id
    if result?
      msg.reply new share.Useful, result
      return msg.finish()
    if msg.envelope.room isnt "general/0" and \
       msg.envelope.room isnt "#{target.type}/#{target.object._id}"
      msg.reply new share.Useful, "Help is on the way."
    msg.finish()

  robot.commands.push 'but unstuck[ on <puzzle|round>]'
  robot.respond (rejoin 'unstuck(?: on ',thingRE,')?',/$/i), (msg) ->
    if msg.match[1]?
      target = Meteor.call 'getByName', name: msg.match[1]
      if not target?
        msg.reply new share.Useful, "I don't know what \"#{msg.match[1]}\" is."
        return msg.finish()
    else
      target = objectFromRoom msg
      return unless target?
    result = Meteor.call 'unsummon',
      type: target.type
      object: target.object._id
      who: msg.envelope.user.id
    if result?
      msg.reply new share.Useful, result
      return msg.finish()
    if msg.envelope.room isnt "general/0" and \
       msg.envelope.room isnt "#{target.type}/#{target.object._id}"
      msg.reply new share.Useful, "Call for help cancelled"
    msg.finish()

  robot.commands.push 'bot announce <message>'
  robot.respond /announce (.*)$/i, (msg) ->
    share.model.oplog msg.match[1], "", "", msg.envelope.user.id, \
        "announcements"
    msg.finish()
