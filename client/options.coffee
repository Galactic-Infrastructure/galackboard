import { reactiveLocalStorage } from './imports/storage.coffee'

doBoolean = (name, newVal) ->
  reactiveLocalStorage.setItem name, newVal

Template.options.events
  "change .bb-hide-solved input": (event, template) ->
    doBoolean 'hideSolved', event.target.checked
  "change .bb-hide-solved-meta input": (event, template) ->
    doBoolean 'hideSolvedMeta', event.target.checked
  "change .bb-compact-mode input": (event, template) ->
    doBoolean 'compactMode', event.target.checked
  "change .bb-boring-mode input": (event, template) ->
    doBoolean 'boringMode', event.target.checked

  'click li a': (event, template) -> event.stopPropagation()
