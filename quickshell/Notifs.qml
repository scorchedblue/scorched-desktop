pragma Singleton

// The notification server, and the history behind it.
//
// This replaces mako. Only one process can own the D-Bus name
// org.freedesktop.Notifications, so mako MUST be gone from autostart -- with
// both running, whichever wins the name takes every notification and the other
// silently receives nothing. That is the failure this file's existence creates,
// and it looks exactly like "notifications are broken".
//
// Capabilities below are declared honestly. Advertising one that is not
// implemented makes applications send markup, images or inline replies that are
// then quietly dropped, which is worse than telling them not to bother.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // Newest first. Everything the server is still tracking.
    readonly property var all: {
        const list = server.trackedNotifications.values.slice();
        list.reverse();
        return list;
    }

    // The subset currently shown as toasts. Separate from history: dismissing a
    // toast should not erase the notification, and clearing history should not
    // require waiting for toasts to expire.
    property var popups: []

    readonly property int count: all.length

    function dismiss(n) {
        removePopup(n);
        if (n)
            n.dismiss();
    }

    function removePopup(n) {
        const out = [];
        for (const p of root.popups) {
            if (p !== n)
                out.push(p);
        }
        root.popups = out;
    }

    function clearAll() {
        root.popups = [];
        // Copy first: dismissing mutates the model this is iterating.
        const list = server.trackedNotifications.values.slice();
        for (const n of list)
            n.dismiss();
    }

    // How long a toast stays up, in milliseconds.
    function timeoutFor(n) {
        // Critical notifications do not disappear on their own. Something that
        // declares itself urgent should not vanish while the user is looking
        // away.
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        // A sender may ask for a specific duration. -1 means "you decide", 0
        // means "never expire" -- but honouring 0 from an arbitrary application
        // would let any of them pin a toast on screen forever, so it is capped.
        if (n.expireTimeout > 0)
            return Math.min(n.expireTimeout, 30000);
        return n.urgency === NotificationUrgency.Low ? 3000 : 6000;
    }

    NotificationServer {
        id: server

        // Retain notifications after they are shown, so there is a history to
        // open rather than a message that is gone the moment it fades.
        keepOnReload: false
        persistenceSupported: true

        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        // Not implemented, so not claimed.
        actionIconsSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        inlineReplySupported: false

        onNotification: n => {
            // `transient` is the sender saying "show this, do not keep it" --
            // volume and progress popups set it. Such a notification still gets
            // a toast; it just does not join the history, because a history
            // full of volume steps is a history nobody reads.
            //
            // tracked is what decides that: without it the notification is
            // dropped the moment this handler returns.
            n.tracked = !n.transient;

            root.popups = [n].concat(root.popups);
        }
    }
}
