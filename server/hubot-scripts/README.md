These are stock hubot scripts, with one exception:
Instead of:

```coffee
  modules.export = (robot) ->
    # stuff
```

Use:

```coffee
  share.hubot.ping = (robot) ->
    robot.commands.push 'cmd1 arg - desc'
    robot.commands.push 'cmd2 arg - desc'
    # stuff
```

Note that the name of the script is given as the field name, and you
must manually add help entries for your commands.

This directory is intended for scripts which are tightly integrated with Meteor
and the codex blackboard.  For packaged hubot scripts, either:

* install the script locally with `meteor npm install --save ${script}`.
* install the script globally with `npm install -g ${script}`, then ensure the
  `NODE_PATH` environment variable is set to the value of `npm root -g` when
  you run the app.

Then either:

* Set the `external_scripts` field in the settings JSON file to a list of the
  names of the packages to load
* set the `EXTERNAL_SCRIPTS` environment variable to a comma-separated list of
  the package names.
* Import it in `server/hubot.coffee` and run it on the robot. If you want
  the script's replies to be private even to public messages, pass it to
  `robot.privately`. Unlike the above two options, it will not be possible
  to disable this script without rebuilding.
  
Note that `hubot-help` is always installed, so you don't need to add it.

To skip loading one of the files in this directory, set the `skip_scripts`
field in the settings JSON file to a list of the scripts to skip, or set the
`SKIP_SCRIPTS` environment variable to a comma-separated list of the script
names.
