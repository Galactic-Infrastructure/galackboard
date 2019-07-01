'use strict'
return unless share.DO_BATCH_PROCESSING

import canonical from '../lib/imports/canonical.coffee'
import { canonicalTags, getTag } from '../lib/imports/tags.coffee'
import watchPresence from './imports/presence.coffee'

model = share.model

# Does various fixups of the collections.
# Was in lib/model.coffee, but that meant it was loaded on the client even
# though it could never run there.

# helper function: like _.throttle, but always ensures `wait` of idle time
# between invocations.  This ensures that we stay chill even if a single
# execution of the function starts to exceed `wait`.
throttle = (func, wait = 0) ->
  [context, args, running, pending] = [null, null, false, false]
  later = ->
    if pending
      run()
    else
      running = false
  run = ->
    [running, pending] = [true, false]
    try
      func.apply(context, args)
    # Note that the timeout doesn't start until the function has completed.
    Meteor.setTimeout(later, wait)
  (a...) ->
    return if pending
    [context, args] = [this, a]
    if running
      pending = true
    else
      running = true
      Meteor.setTimeout(run, 0)

# Nicks: synchronize priv_located* with located* at a throttled rate.
# order by priv_located_order, which we'll clear when we apply the update
# this ensures nobody gets starved for updates
do ->
  # limit to 10 location updates/minute
  LOCATION_BATCH_SIZE = 10
  LOCATION_THROTTLE = 60*1000
  runBatch = ->
    Meteor.users.find({
      priv_located_order: { $exists: true, $ne: null }
    }, {
      sort: [['priv_located_order','asc']]
      limit: LOCATION_BATCH_SIZE
    }).forEach (n, i) ->
      console.log "Updating location for #{n._id} (#{i})"
      Meteor.users.update n._id,
        $set:
          located: n.priv_located
          located_at: n.priv_located_at
        $unset: priv_located_order: ''
  maybeRunBatch = throttle(runBatch, LOCATION_THROTTLE)
  Meteor.users.find({
    priv_located_order: { $exists: true, $ne: null }
  }, {
    fields: priv_located_order: 1
  }).observeChanges
    added: (id, fields) -> maybeRunBatch()
    # also run batch on removed: batch size might not have been big enough
    removed: (id) -> maybeRunBatch()

# Migrate messages out of OldMessages and create dawns of time.
# (i.e. ensure any chat room with messages has a sentinel message predating any
# other message so you know when you have all of them.)
# TODO by 2020 hunt: remove, as we won't need backward compatibility.
Meteor.startup ->
  old = new Mongo.Collection 'oldmessages'
  count = 0
  old.find().forEach (doc) ->
    model.Messages.insert doc
    old.remove _id: doc._id
    count++
  console.log "Migrated #{count} old messages" if count > 0
  # TODO: if pages exist, create dawns of time
  pages = new Mongo.Collection 'pages'
  if pages.findOne()?
    rawColl = model.Messages.rawCollection()
    agg = Meteor.wrapAsync rawColl.aggregate, rawColl
    count = 0
    aggcsr = agg([$group: {_id: '$room_name', timestamp: $min: '$timestamp'}])
    toArray = Meteor.wrapAsync aggcsr.toArray, aggcsr
    toArray().forEach (room) ->
      dawn = model.Messages.findOne(_id: room._id)
      return if dawn? and dawn.timestamp <= room.timestamp
      model.Messages.upsert room._id,
        timestamp: room.timestamp - 1
        dawn_of_time: true
        system: true
        bot_ignore: true
        room_name: room._id
      count++
    console.log "Created dawn of time for #{count} rooms" if count > 0
    deleted = pages.remove({})
    console.log "Deleted #{deleted} pages" if deleted > 0

presence = watchPresence()
