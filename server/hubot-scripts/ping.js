// Description:
//   Hubot is very attentive (ping hubot)
//
// Dependencies:
//   None
//
// Configuration:
//   None
//
// Commands:
//   hubot ping - Reply with pong
//   hubot echo <text> - Reply back with <text>
//   hubot time - Reply with current time
//
// Author:
//   tapichu/cscott

import { scripts } from "/server/imports/botutil.js";

scripts.ping = function (robot) {
  robot.commands.push("bot ping - Reply with pong");
  robot.respond(/PING$/i, async function (msg) {
    await msg.reply("PONG");
    msg.finish();
  });
};
