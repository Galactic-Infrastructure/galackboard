'use strict'
# Watch twitter and announce new tweets to general/0 chat.
#_
# The account login details are given in settings.json, like so:
# {
#   "twitter": {
#     "consumer_key": "xxxxxxxxx",
#     "consumer_secret": "yyyyyyyyyyyy",
#     "access_token_key": "zzzzzzzzzzzzzzzzzzzzzz",
#     "access_token_secret": "wwwwwwwwwwwwwwwwwwwwww"
#   }
# }

import Twitter from 'twit'
import tweetToMessage from './imports/twitter.coffee'

return unless share.DO_BATCH_PROCESSING
settings = Meteor.settings?.twitter ? {}
settings.consumer_key ?= process.env.TWITTER_CONSUMER_KEY
settings.consumer_secret ?= process.env.TWITTER_CONSUMER_SECRET
settings.access_token_key ?= process.env.TWITTER_ACCESS_TOKEN_KEY
settings.access_token_secret ?= process.env.TWITTER_ACCESS_TOKEN_SECRET
HASHTAGS = settings.hashtags?.join() ? process.env.TWITTER_HASHTAGS ? 'mysteryhunt,mitmysteryhunt'
return unless settings.consumer_key and settings.consumer_secret
return unless settings.access_token_key and settings.access_token_secret
twit = new Twitter
  consumer_key: settings.consumer_key
  consumer_secret: settings.consumer_secret
  access_token: settings.access_token_key
  access_token_secret: settings.access_token_secret

# See https://dev.twitter.com/streaming/overview/request-parameters#track
stream = twit.stream 'statuses/filter', {track: HASHTAGS}
console.log "Listening to #{HASHTAGS} on twitter"
stream.on 'tweet', Meteor.bindEnvironment tweetToMessage

stream.on 'error', Meteor.bindEnvironment (error) ->
  console.warn 'Twitter error:', error
