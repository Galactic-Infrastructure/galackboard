'use strict'

import { Readable } from 'stream'
import delay from 'delay'

# Drive folder settings
DEFAULT_ROOT_FOLDER_NAME = "MIT Mystery Hunt #{new Date().getFullYear()}"
ROOT_FOLDER_NAME = -> Meteor.settings.folder or process.env.DRIVE_ROOT_FOLDER or DEFAULT_ROOT_FOLDER_NAME
CODEX_ACCOUNT = -> Meteor.settings.driveowner or process.env.DRIVE_OWNER_ADDRESS
WORKSHEET_NAME = (name) -> "Worksheet: #{name}"
DOC_NAME = (name) -> "Notes: #{name}"

# Constants
GDRIVE_FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'
GDRIVE_SPREADSHEET_MIME_TYPE = 'application/vnd.google-apps.spreadsheet'
GDRIVE_DOC_MIME_TYPE = 'application/vnd.google-apps.document'
XLSX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
MAX_RESULTS = 200
SPREADSHEET_TEMPLATE = Assets.getBinary 'spreadsheet-template.xlsx'

quote = (str) -> "'#{str.replace(/([\'\\])/g, '\\$1')}'"

samePerm = (p, pp) ->
  (p.withLink or false) is (pp.withLink or false) and \
  p.role is pp.role and \
  p.type is pp.type and \
  if p.type is 'anyone'
    true
  else if ('value' of p) and ('value' of pp)
    (p.value is pp.value)
  else  # returned permissions have emailAddress, not value.
    (p.type is 'user' and p.value is CODEX_ACCOUNT() and pp.emailAddress is CODEX_ACCOUNT())

userRateExceeded = (error) ->
  return false unless error.code == 403
  for subError in error.errors
    if subError.domain is 'usageLimits' and subError.reason is 'userRateLimitExceeded'
      return true
  return false

delays = [100, 250, 500, 1000, 2000, 5000, 10000]

apiThrottle = (base, name, params) ->
  ix = 0
  Promise.await do ->
    loop
      try
        return (await base[name] params).data
      catch error
        if ix >= delays.length or not userRateExceeded(error)
          throw error
        console.warn "Rate limited for #{name}; Will return after #{delays[ix]}ms"
        await delay delays[ix]
        ix++

ensurePermissions = (drive, id) ->
  # give permissions to both anyone with link and to the primary
  # service acount.  the service account must remain the owner in
  # order to be able to rename the folder
  perms = [
    # edit permissions for anyone with link
    withLink: true
    role: 'writer'
    type: 'anyone'
  ]
  if CODEX_ACCOUNT()?
    perms.push
      # edit permissions to codex account
      withLink: false
      role: 'writer'
      type: 'user'
      value: CODEX_ACCOUNT()
  resp = apiThrottle drive.permissions, 'list', fileId: id
  perms.forEach (p) ->
    # does this permission already exist?
    exists = resp.items.some (pp) -> samePerm p, pp
    unless exists
      apiThrottle drive.permissions, 'insert',
        fileId: id
        resource: p
  'ok'

ensureNamedPermissions = (drive, id, email) =>
  # same as above, but grants specific permission to the given email,
  # thus allowing them to appear named instead of anonymous in the spreadsheets.
  console.log("drive.coffee")
  console.log(email)
  resp = apiThrottle drive.permissions, 'getIdForEmail', email: email
  apiThrottle drive.permissions, 'insert',
    fileId: id
    sendNotificationEmails: false
    resource:
      type: 'user'
      role: 'writer'
      id: resp.id
  'ok'

spreadsheetSettings =
  titleFunc: WORKSHEET_NAME
  driveMimeType: GDRIVE_SPREADSHEET_MIME_TYPE
  uploadMimeType: XLSX_MIME_TYPE
  uploadTemplate: ->
    # The file is small enough to fit in ram, so don't recreate a file read
    # stream every time.
    # Apparently there's a module called streamifier that does this.
    r = new Readable
    r._read = ->
    r.push SPREADSHEET_TEMPLATE
    r.push null
    r

docSettings =
  titleFunc: DOC_NAME
  driveMimeType: GDRIVE_DOC_MIME_TYPE
  uploadMimeType: 'text/plain'
  uploadTemplate: -> 'Put notes here.'
  
ensure = (drive, name, folder, settings) ->
  doc = apiThrottle drive.children, 'list',
    folderId: folder.id
    q: "title=#{quote settings.titleFunc name} and mimeType=#{quote settings.driveMimeType}"
    maxResults: 1
  .items[0]
  unless doc?
    doc =
      title: settings.titleFunc name
      mimeType: settings.uploadMimeType
      parents: [id: folder.id]
    doc = apiThrottle drive.files, 'insert',
      convert: true
      body: doc
      resource: doc
      media:
        mimeType: settings.uploadMimeType
        body: settings.uploadTemplate()
  ensurePermissions drive, doc.id
  doc

awaitFolder = (drive, name, parent) ->
  triesLeft = 5
  loop
    resp = apiThrottle drive.children, 'list',
      folderId: parent
      q: "title=#{quote name}"
      maxResults: 1
    if resp.items.length > 0
      console.log "#{name} found"
      return resp.items[0]
    else if triesLeft < 1
      console.log "#{name} never existed"
      throw 'never existed'
    else
      console.log "Waiting #{attempts} more times for #{name}"
      Promise.await delay 1000
      triesLeft--

ensureFolder = (drive, name, parent) ->
  # check to see if the folder already exists
  resp = apiThrottle drive.children, 'list',
    folderId: parent or 'root'
    q: "title=#{quote name}"
    maxResults: 1
  if resp.items.length > 0
    resource = resp.items[0]
  else
    # create the folder
    resource =
      title: name
      mimeType: GDRIVE_FOLDER_MIME_TYPE
    resource.parents = [id: parent] if parent
    resource = apiThrottle drive.files, 'insert',
      resource: resource
  # give the new folder the right permissions
  ensurePermissions drive, resource.id
  resource

awaitOrEnsureFolder = (drive, name, parent) ->
  return ensureFolder drive, name, parent if share.DO_BATCH_PROCESSING
  try
    return awaitFolder drive, name, (parent or 'root')
  catch error
    return ensureFolder drive, name, parent if error is "never existed"
    throw error

rmrfFolder = (drive, id) ->
  resp = {}
  loop
    # delete subfolders
    resp = apiThrottle drive.children, 'list',
      folderId: id
      q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: MAX_RESULTS
      pageToken: resp.nextPageToken
    resp.items.forEach (item) ->
      rmrfFolder item.id
    break unless resp.nextPageToken?
  loop
    # delete non-folder stuff
    resp = apiThrottle drive.children, 'list',
      folderId: id
      q: "mimeType!=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: MAX_RESULTS
      pageToken: resp.nextPageToken
    resp.items.forEach (item) ->
      apiThrottle drive.files, 'delete', fileId: item.id
    break unless resp.nextPageToken?
  # folder empty; delete the folder and we're done
  apiThrottle drive.files, 'delete', fileId: id
  'ok'

export class Drive
  constructor: (@drive) ->
    @rootFolder = (awaitOrEnsureFolder @drive, ROOT_FOLDER_NAME()).id
    @ringhuntersFolder = (awaitOrEnsureFolder @drive, "#{Meteor.settings?.public?.chatName ? 'Ringhunters'} Uploads", @rootFolder).id
  
  createPuzzle: (name) ->
    folder = ensureFolder @drive, name, @rootFolder
    # is the spreadsheet already there?
    spreadsheet = ensure @drive, name, folder, spreadsheetSettings
    doc = ensure @drive, name, folder, docSettings
    return {
      id: folder.id
      spreadId: spreadsheet.id
      docId: doc.id
    }

  findPuzzle: (name) ->
    resp = apiThrottle @drive.children, 'list',
      folderId: @rootFolder
      q: "title=#{quote name} and mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: 1
    folder = resp.items[0]
    return null unless folder?
    # TODO: batch these requests together.
    # look for spreadsheet
    spread = apiThrottle @drive.children, 'list',
      folderId: folder.id
      q: "title=#{quote WORKSHEET_NAME name}"
      maxResults: 1
    doc = apiThrottle @drive.children, 'list',
      folderId: folder.id
      q: "title=#{quote DOC_NAME name}"
      maxResults: 1
    return {
      id: folder.id
      spreadId: spread.items[0]?.id
      docId: doc.items[0]?.id
    }

  listPuzzles: ->
    results = []
    resp = {}
    loop
      resp = apiThrottle @drive.children, 'list',
        folderId: @rootFolder
        q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
        maxResults: MAX_RESULTS
        pageToken: resp.nextPageToken
      results.push resp.items...
      break unless resp.nextPageToken?
    results

  renamePuzzle: (name, id, spreadId, docId) ->
    apiThrottle @drive.files, 'patch',
      fileId: id
      resource:
        title: name
    if spreadId?
      apiThrottle @drive.files, 'patch',
        fileId: spreadId
        resource:
          title: WORKSHEET_NAME name
    if docId?
      apiThrottle @drive.files, 'patch',
        fileId: docId
        resource:
          title: DOC_NAME name
    'ok'

  deletePuzzle: (id) -> rmrfFolder @drive, id

  shareFolder: (email) -> ensureNamedPermissions @drive, @rootFolder, email

  # purge `rootFolder` and everything in it
  purge: -> rmrfFolder @drive, rootFolder

# generate functions
skip = (type) -> -> console.warn "Skipping Google Drive operation:", type

export class FailDrive
  createPuzzle: skip 'createPuzzle'
  findPuzzle: skip 'findPuzzle'
  listPuzzles: skip 'listPuzzles'
  renamePuzzle: skip 'renamePuzzle'
  deletePuzzle: skip 'deletePuzzle'
  shareFolder: skip 'shareFolder'
  purge: skip 'purge'