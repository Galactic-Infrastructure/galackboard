import { PRESENCE_KEEPALIVE_MINUTES } from "/lib/imports/constants.js";
import { Presence, Puzzles } from "/lib/imports/collections.js";

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
    }, 60 * 1000);
    this.noclients = await Presence.find({ clients: [] }).observeAsync({
      async added(presence) {
        await Presence.removeAsync(presence._id);
      },
    });
    return this;
  }

  stop() {
    this.noclients.stop();
    this.joinpart.stop();
    Meteor.clearInterval(this.interval);
  }
}

export default () => new PresenceManager().start();
