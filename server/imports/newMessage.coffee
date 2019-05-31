'use strict'
import canonical from '/lib/imports/canonical.coffee'
import { NonEmptyString } from '/lib/imports/match.coffee'
import emojify from './emoji.coffee'
import sanitize from 'sanitize-html'

params = {...sanitize.defaults}
params.allowedAttributes = {
  ...params.allowedAttributes, 
  '*': ['class'],
}

export ensureDawnOfTime = (room_name) ->
  share.model.Messages.upsert room_name,
    $min: timestamp: Date.now() - 1
    $setOnInsert:
      system: true
      dawn_of_time: true
      room_name: room_name
      bot_ignore: true
Meteor.startup ->
  ['general/0', 'callins/0', 'oplog/0'].forEach ensureDawnOfTime

export newMessage = (newMsg) ->
  check newMsg,
    body: String
    nick: NonEmptyString
    bodyIsHtml: Match.Optional Boolean
    action: Match.Optional Boolean
    to: Match.Optional NonEmptyString
    poll: Match.Optional NonEmptyString
    room_name: NonEmptyString
    useful: Match.Optional Boolean
    bot_ignore: Match.Optional Boolean
  # translate emojis!
  if newMsg.bodyIsHtml
    newMsg.body = sanitize newMsg.body, params
  else
    newMsg.body = emojify newMsg.body
  newMsg.to = canonical newMsg.to if newMsg.to?
  newMsg.timestamp = Date.now()
  ensureDawnOfTime newMsg.room_name
  newMsg._id = share.model.Messages.insert newMsg
  return newMsg
