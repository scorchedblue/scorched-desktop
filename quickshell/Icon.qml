// Vector icons, drawn rather than typed.
//
// The image ships no Nerd Font, and depending on one installed in a user's home
// would give a fresh account a bar full of tofu. These are drawn on a 24x24
// grid and scale to any size, take the theme colour directly, and depend on
// nothing.
//
// Usage: Icon { name: "wifi"; size: 16; color: Theme.text; level: 3 }

import QtQuick

Canvas {
    id: root

    property string name: ""
    property int size: 16
    property color color: "#cdd6f4"
    // 0-3, used by wifi and volume to show strength without a second icon.
    property int level: 3
    property bool slash: false

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onLevelChanged: requestPaint()
    onSlashChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        // Everything below is authored on a 24x24 grid, then scaled once.
        const s = width / 24;
        ctx.scale(s, s);
        ctx.strokeStyle = root.color;
        ctx.fillStyle = root.color;
        ctx.lineWidth = 2;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (name === "ethernet") {
            // An RJ45 jack: body plus the latch tab. The earlier drawing was a
            // box with three thin stems, which at 16px collapsed into a smudge.
            // Two bold shapes survive the scale; five thin ones do not.
            ctx.strokeRect(5, 10, 14, 9);
            ctx.beginPath();
            ctx.moveTo(9.5, 10);
            ctx.lineTo(9.5, 6);
            ctx.lineTo(14.5, 6);
            ctx.lineTo(14.5, 10);
            ctx.stroke();
        } else if (name === "wifi") {
            // Three arcs plus a dot; dim the arcs above the current level so
            // strength reads at a glance without a number.
            const arcs = [[6, 0.9], [9.5, 1.0], [13, 1.1]];
            for (var i = 0; i < 3; i++) {
                ctx.globalAlpha = (i < level) ? 1.0 : 0.25;
                ctx.beginPath();
                ctx.arc(12, 18, arcs[i][0], Math.PI * 1.25, Math.PI * 1.75);
                ctx.stroke();
            }
            ctx.globalAlpha = 1.0;
            ctx.beginPath();
            ctx.arc(12, 18, 1.4, 0, Math.PI * 2);
            ctx.fill();
        } else if (name === "vpn") {
            ctx.beginPath();
            ctx.moveTo(12, 3);
            ctx.lineTo(20, 6.5);
            ctx.lineTo(20, 12);
            ctx.bezierCurveTo(20, 17, 16.5, 20, 12, 21.5);
            ctx.bezierCurveTo(7.5, 20, 4, 17, 4, 12);
            ctx.lineTo(4, 6.5);
            ctx.closePath();
            ctx.stroke();
        } else if (name === "bluetooth") {
            ctx.beginPath();
            ctx.moveTo(7, 7.5); ctx.lineTo(17, 16.5);
            ctx.lineTo(12, 21); ctx.lineTo(12, 3);
            ctx.lineTo(17, 7.5); ctx.lineTo(7, 16.5);
            ctx.stroke();
        } else if (name === "volume") {
            ctx.beginPath();
            ctx.moveTo(4, 9.5); ctx.lineTo(8, 9.5); ctx.lineTo(12.5, 5.5);
            ctx.lineTo(12.5, 18.5); ctx.lineTo(8, 14.5); ctx.lineTo(4, 14.5);
            ctx.closePath();
            ctx.stroke();
            for (var w = 0; w < 2; w++) {
                ctx.globalAlpha = (w < level) ? 1.0 : 0.25;
                ctx.beginPath();
                ctx.arc(13.5, 12, 3.5 + w * 3, -Math.PI / 3, Math.PI / 3);
                ctx.stroke();
            }
            ctx.globalAlpha = 1.0;
        } else if (name === "mic") {
            // Capsule, cradle, stem.
            ctx.beginPath();
            ctx.moveTo(12, 3);
            ctx.lineTo(12, 3);
            ctx.arc(12, 7, 3.2, Math.PI, 0);
            ctx.lineTo(15.2, 11);
            ctx.arc(12, 11, 3.2, 0, Math.PI);
            ctx.closePath();
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 12, 6.5, 0, Math.PI);
            ctx.moveTo(12, 18.5);
            ctx.lineTo(12, 21.5);
            ctx.stroke();
        } else if (name === "cpu") {
            // Two legs a side, not three. At 16px the third leg lands on the
            // same pixel as its neighbours and the whole icon fills in solid.
            ctx.strokeRect(7.5, 7.5, 9, 9);
            ctx.beginPath();
            for (var p = 0; p < 2; p++) {
                const o = 10.5 + p * 3;
                ctx.moveTo(o, 7.5); ctx.lineTo(o, 3.5);
                ctx.moveTo(o, 16.5); ctx.lineTo(o, 20.5);
                ctx.moveTo(7.5, o); ctx.lineTo(3.5, o);
                ctx.moveTo(16.5, o); ctx.lineTo(20.5, o);
            }
            ctx.stroke();
        } else if (name === "memory") {
            ctx.strokeRect(3, 8, 18, 9);
            ctx.beginPath();
            for (var c = 0; c < 4; c++) {
                const o2 = 6 + c * 4;
                ctx.moveTo(o2, 17); ctx.lineTo(o2, 20);
            }
            ctx.stroke();
        } else if (name === "disk") {
            ctx.beginPath();
            ctx.ellipse(3, 4, 18, 5);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(3, 6.5); ctx.lineTo(3, 17.5);
            ctx.moveTo(21, 6.5); ctx.lineTo(21, 17.5);
            ctx.stroke();
            ctx.beginPath();
            ctx.ellipse(3, 15, 18, 5);
            ctx.stroke();
        } else if (name === "search") {
            ctx.beginPath();
            ctx.arc(10.5, 10.5, 6.5, 0, Math.PI * 2);
            ctx.moveTo(15.5, 15.5);
            ctx.lineTo(20.5, 20.5);
            ctx.stroke();
        } else if (name === "bell") {
            ctx.beginPath();
            // Body: shoulders, flare, and the rim across the bottom.
            ctx.moveTo(6, 16.5);
            ctx.lineTo(6, 11);
            ctx.bezierCurveTo(6, 7.5, 8.7, 5, 12, 5);
            ctx.bezierCurveTo(15.3, 5, 18, 7.5, 18, 11);
            ctx.lineTo(18, 16.5);
            ctx.lineTo(6, 16.5);
            ctx.closePath();
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(10.5, 19.5);
            ctx.lineTo(13.5, 19.5);
            ctx.stroke();
        } else if (name === "calendar") {
            ctx.strokeRect(3.5, 5.5, 17, 15);
            ctx.beginPath();
            ctx.moveTo(3.5, 10.5); ctx.lineTo(20.5, 10.5);
            ctx.moveTo(8, 3); ctx.lineTo(8, 7);
            ctx.moveTo(16, 3); ctx.lineTo(16, 7);
            ctx.stroke();
        } else if (name === "display") {
            ctx.strokeRect(3, 5, 18, 12);
            ctx.beginPath();
            ctx.moveTo(9, 21); ctx.lineTo(15, 21);
            ctx.moveTo(12, 17); ctx.lineTo(12, 21);
            ctx.stroke();
        } else if (name === "chevron") {
            ctx.beginPath();
            ctx.moveTo(7, 10); ctx.lineTo(12, 15); ctx.lineTo(17, 10);
            ctx.stroke();
        } else if (name === "check") {
            ctx.beginPath();
            ctx.moveTo(5, 12.5); ctx.lineTo(10, 17.5); ctx.lineTo(19, 7);
            ctx.stroke();
        } else if (name === "power") {
            ctx.beginPath();
            ctx.arc(12, 13, 7.5, -Math.PI * 0.35, Math.PI * 1.35);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12, 3); ctx.lineTo(12, 11);
            ctx.stroke();
        } else if (name === "dot") {
            ctx.beginPath();
            ctx.arc(12, 12, 5, 0, Math.PI * 2);
            ctx.fill();
        }

        // A single diagonal is how every state in this shell says "off".
        if (slash) {
            ctx.beginPath();
            ctx.moveTo(4, 4); ctx.lineTo(20, 20);
            ctx.stroke();
        }
    }
}
