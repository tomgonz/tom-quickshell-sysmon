// Clock.qml
//
// GPL-3.0 license
//
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

Rectangle {
    id: root

    required property real containerWidth

    height: Math.floor(0.500 * rootWindow.mywidth + 15)
    //height: mainColumn.height + 8
    radius: rootWindow.widgetRadius
    color: rootWindow.widgetBGcolor
    border.color: rootWindow.widgetBorderColor
    border.width: 2

    // --- Dynamic Time & Performance States ---
    property var currentTime: new Date()
    property int currentSecond: currentTime.getSeconds()
    property string uptimeText: "Uptime: ..."

    // ==================================================================
    //  UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: root.containerWidth
        spacing: 2
        anchors.horizontalCenter: parent.horizontalCenter

        // -----------------------------------------------
        // --- 1. Time Display Block ---
        // -----------------------------------------------
        Rectangle {
            id: targetText
            width: timeText.implicitWidth
            height: timeText.implicitHeight - 6 // Preserved your padding layout preferences
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: timeText
                // Declarative binding updates automatically when currentTime changes
                text: Qt.formatTime(root.currentTime, "hh:mm AP")
                font.pixelSize: (root.width / 10) * 2
                color: "white"
                anchors.centerIn: parent
            }

            HoverHandler {
                id: textHover
            }

            Tooltip {
                id: clockTooltip
                target: targetText
                show: textHover.hovered
                // Dynamically calculates UTC tooltip text representation reactively
                text: {
                    let d = root.currentTime;
                    let hh = String(d.getUTCHours()).padStart(2, '0');
                    let mm = String(d.getUTCMinutes()).padStart(2, '0');
                    let ss = String(d.getUTCSeconds()).padStart(2, '0');
                    return `UTC: ${hh}:${mm}:${ss}`;
                }
                fontPixelSize: 18
            }
        }

        // ------------------------------------------------------
        // --- 2. Seconds Progress Bar Track ---
        // ------------------------------------------------------
        Rectangle {
            id: container
            width: rootWindow.mywidth - 40
            height: 2
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // Maps 0-59 smooth width transitions cleanly
                width: parent.width * (root.currentSecond / 59)
                color: "white"
            }
        }

        // -----------------------------------------------
        // --- 3. Date Text Array (ddd + dd-MMM-yyyy) ---
        // -----------------------------------------------
        Row {
            id: clockDate
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0 

            Text {
                text: Qt.formatDate(root.currentTime, "ddd ")
                font.pixelSize: (root.width / 10)
                color: "#FF3333"
                style: Text.Outline
                styleColor: "#22000000"
            }
            Text {
                text: Qt.formatDate(root.currentTime, "  dd-MMM-yyyy")
                font.pixelSize: (root.width / 10)
                color: "#00BBFF"
                style: Text.Outline
                styleColor: "#22000000"
            }
        }

        // -------------------------------------------------
        // --- 4. Accent Separation Rule Bar ---
        // -------------------------------------------------
        Rectangle {
            id: dateBar
            width: rootWindow.mywidth - 60
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#00FF77"
        }

        // -------------------------------------------------
        // --- 5. System Uptime Label Display ---
        // -------------------------------------------------
        Text {
            id: clockUptime
            text: root.uptimeText
            font.pixelSize: 16
            color: "yellow"
            style: Text.Outline
            styleColor: "#22000000"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ==================================================================
    //  Data Gathering & File System Processing Channels
    // ==================================================================
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }

    // Single unified master clock loop engine updates once per second
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // 1. Kick the core clock pulse binding chain
            root.currentTime = new Date();
            root.currentSecond = root.currentTime.getSeconds();

            // 2. High-performance, zero-fork Uptime Parsing Pass
            uptimeFile.reload();
            let rawData = (typeof uptimeFile.text === "function") ? uptimeFile.text() : uptimeFile.text;
            if (rawData) {
                let uptimeSeconds = parseInt(rawData.trim().split(' ')[0]);
                if (!isNaN(uptimeSeconds)) {
                    let days = Math.floor(uptimeSeconds / 86400);
                    let hours = Math.floor((uptimeSeconds % 86400) / 3600);
                    let minutes = Math.floor((uptimeSeconds % 3600) / 60);

                    let uptimeStr = "";
                    if (days > 0) uptimeStr += `${days}d `;
                    uptimeStr += `${hours}h ${minutes}m`;

                    root.uptimeText = "Uptime: " + uptimeStr;
                }
            }
        }
    }
}

