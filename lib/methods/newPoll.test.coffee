'use strict'

# Will access contents via share
import '../model.coffee'
# Test only works on server side; move to /server if you add client tests.
import '../../server/000servercall.coffee'
import chai from 'chai'
import sinon from 'sinon'
import { resetDatabase } from 'meteor/xolvio:cleaner'

model = share.model

describe 'newPoll', ->
  clock = null

  beforeEach ->
    clock = sinon.useFakeTimers(7)

  afterEach ->
    clock.restore()

  beforeEach ->
    resetDatabase()

  it 'fails without login', ->
    chai.assert.throws ->
      Meteor.call 'newPoll', 'general/0', 'What up?', ['Sky', 'Ceiling', 'Aliens']
    , Match.Error

  it 'fails with no options', ->
    chai.assert.throws ->
      Meteor.callAs 'newPoll', 'torgen', 'general/0', 'What up?', []
    , Match.Error

  it 'fails with one option', ->
    chai.assert.throws ->
      Meteor.callAs 'newPoll', 'torgen', 'general/0', 'What up?', ['everything']
    , Match.Error

  it 'fails with six options', ->
    chai.assert.throws ->
      Meteor.callAs 'newPoll', 'torgen', 'general/0', 'What up?', ['Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple']
    , Match.Error

  it 'fails with no room', ->
    chai.assert.throws ->
      Meteor.callAs 'newPoll', 'torgen', '', 'What up?', ['Sky', 'Ceiling', 'Aliens']
    , Match.Error

  it 'fails with no question', ->
    chai.assert.throws ->
      Meteor.callAs 'newPoll', 'torgen', 'general/0', '', ['Sky', 'Ceiling', 'Aliens']
    , Match.Error

  it 'canonicalizes options', ->
    Meteor.callAs 'newPoll', 'torgen', 'general/0', 'What up?', ['Red', 'Orange', 'Yellow', 'Green', 'red']
    chai.assert.deepInclude model.Polls.findOne(),
      created: 7
      created_by: 'torgen'
      question: 'What up?'
      options: [
        {canon: 'red', option: 'Red'}
        {canon: 'orange', option: 'Orange'}
        {canon: 'yellow', option: 'Yellow'}
        {canon: 'green', option: 'Green'}
      ]
      votes: {}

  it 'creates message', ->
    Meteor.callAs 'newPoll', 'torgen', 'general/0', 'What up?', ['Red', 'Orange', 'Yellow', 'Green', 'Blue']
    p = model.Polls.findOne()._id
    chai.assert.deepInclude model.Messages.findOne(),
      room_name: 'general/0'
      nick: 'torgen'
      body: 'What up?'
      timestamp: 7
      poll: p


