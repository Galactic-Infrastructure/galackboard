'use strict'

import canonical from '../../lib/imports/canonical.coffee'
import { getTag } from '../../lib/imports/tags.coffee'

export emailFromNickObject = (nick) -> getTag(nick, 'Gravatar') or "#{nick.canon}@#{share.settings.DEFAULT_HOST}"  

export nickEmail = (nick) ->
  cn = canonical nick
  n = share.model.Nicks.findOne canon: cn
  return emailFromNickObject n