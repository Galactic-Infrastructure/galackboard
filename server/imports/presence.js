import canonical from "/lib/imports/canonical.js";
import { PRESENCE_KEEPALIVE_MINUTES } from "/lib/imports/constants.js";
import { Messages, Presence, Puzzles } from "/lib/imports/collections.js";

// look up a real name, if there is one
async function maybe_real_name(nick) {
  const n = await Meteor.users.findOneAsync(canonical(nick));
  return n?.real_name || nick;
}

const common_presence_fields = {
  system: true,
  to: null,
  bodyIsHtml: false,
};

class PresenceManager {
  async start() {
    // Presence
    // ensure old entries are timed out after 2*PRESENCE_KEEPALIVE_MINUTES
    this.interval = Meteor.setInterval(async function () {
      const removeBefore =
        Date.now() - 2 * PRESENCE_KEEPALIVE_MINUTES * 60 * 1000;
      await Presence.updateAsync(
        { "clients.timestamp": { $lt: removeBefore } },
        { $pull: { clients: { timestamp: { $lt: removeBefore } } } }
      );
      await Presence.removeAsync({
        clients: { $size: 0 },
      });
    }, 60 * 1000);

    return this;
  }

  stop() {
    this.noclients.stop();
    this.joinpart.stop();
    Meteor.clearInterval(this.interval);
  }
}

export default () => new PresenceManager().start();
