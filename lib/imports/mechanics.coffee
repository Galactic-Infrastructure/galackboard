'use strict'

import canonical from './canonical.coffee'

export mechanics = {}

export class Mechanic
  constructor: (@name) ->
    @canon = canonical @name
    mechanics[@canon] = @
    Object.freeze @

new Mechanic 'meta squad'
new Mechanic 'backsolvers'
new Mechanic 'extraction'
new Mechanic 'grunt work'
new Mechanic 'ID tasks'
new Mechanic 'code monkey'
new Mechanic 'Flour Bakery and Cafe'
new Mechanic 'crossword clues'
new Mechanic 'cryptics'
new Mechanic 'logic puzzle'
new Mechanic 'duck conundrum'
new Mechanic 'location-based'
new Mechanic 'physical'
new Mechanic 'runaround'
new Mechanic 'audio manipulation'
new Mechanic 'biology'
new Mechanic 'board games'
new Mechanic 'chemistry'
new Mechanic 'chinese'
new Mechanic 'ciphers'
new Mechanic 'classics'
new Mechanic 'food/cooking'
new Mechanic 'geography'
new Mechanic 'history/law/politics'
new Mechanic 'IPA (phonetics)'
new Mechanic 'knitting'
new Mechanic 'lgbt'
new Mechanic 'literature'
new Mechanic 'math'
new Mechanic 'medicine'
new Mechanic 'memes'
new Mechanic 'MIT knowledge'
new Mechanic 'musicals/theater'
new Mechanic 'music ID'
new Mechanic 'music theory'
new Mechanic 'niche topics'
new Mechanic 'NPL flats'
new Mechanic 'origami'
new Mechanic 'poetry'
new Mechanic 'pop culture'
new Mechanic 'potent potables'
new Mechanic 'puns'
new Mechanic 'spanish'
new Mechanic 'sports'
new Mechanic 'steganosaurus'
new Mechanic 'TV and movies'
new Mechanic 'video games'
new Mechanic 'weeb'

Object.freeze mechanics

export IsMechanic = Match.Where (x) -> mechanics[x]?
