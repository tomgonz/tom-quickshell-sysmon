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

    // ==================================================================
    // User Tweakable Configurations & Variables
    // ==================================================================
    required property real containerWidth
    required property int widgetRadius
    required property string widgetBGcolor
    required property string widgetBorderColor
    required property int widgetBorderWidth
    required property bool isToolbox

    // CONFIGURATION TOGGLE SWITCH: Set to true for 24hr format (with seconds) 
    // or false for 12hr format AM/PM (no seconds).
    property bool use24Hour: false

    // SCALABLE LAYOUT FEATURE: Dynamically calculates card bounding height 
    // based on your global panel width setting.
    height: Math.floor(0.420 * width + 42)
    radius: root.widgetRadius
    color: widgetBGcolor
    border.color: widgetBorderColor
    border.width: widgetBorderWidth

    // --- Dynamic Time & Performance States ---
    property var currentTime: new Date()
    property int currentSecond: currentTime.getSeconds()
    property string uptimeText: "Uptime: ..."
    property string timezoneText: "..."

    // ==================================================================
    // Display Data on UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: root.containerWidth - 16
        spacing: 4

        // Visual Adjustment: Anchored directly relative to the top border frame
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter

        // -----------------------------------------------
        // --- 1. Time Display Block ---
        // -----------------------------------------------
        Rectangle {
            id: targetText
            width: timeText.implicitWidth
            height: Math.max(1, timeText.implicitHeight - 6) // Preserved padding layout preference safely
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: timeText
                text: root.use24Hour ? Qt.formatTime(root.currentTime, "hh:mm:ss") : Qt.formatTime(root.currentTime, "hh:mm AP")
                font.pixelSize: (root.width / 10) * 2
                color: "white"
                anchors.centerIn: parent

                // INTERACTIVE TOGGLE LAYER: Adds click detection directly to the time numbers
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor // Changes cursor to a hand icon on hover

                    // Flips your configuration boolean back and forth instantly when clicked
                    onClicked: {
                        root.use24Hour = !root.use24Hour;
                    }
                }
            }

            HoverHandler {
                id: textHover
            }

            Tooltip {
                id: clockTooltip
                target: targetText
                show: textHover.hovered
                text: root.timezoneText
                fontPixelSize: 18
            }
        }

        // ------------------------------------------------------
        // --- 2. Seconds Progress Bar Track ---
        // ------------------------------------------------------
        Rectangle {
            id: container
            width: parent.width
            height: 2
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter

            // DYNAMIC LAYOUT MANAGEMENT: When 24-hour mode shows text seconds, 
            // the graphic bar is safely hidden to reduce workspace layout redundancy.
            //   visible: !root.use24Hour

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (Math.max(0, Math.min(59, root.currentSecond)) / 59)
                color: "white"
            }
        }

        // -----------------------------------------------
        // --- 3. Date Text Array (ddd + dd-MMM-yyyy) ---
        // -----------------------------------------------
        // THE LAYOUT FIX: Wrapping the layout inside a dedicated Item container 
        // gives the MouseArea explicit dimensional boundaries without collapsing the Row.
        Item {
            id: dateWrapper
            width: clockDate.implicitWidth
            height: clockDate.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                id: clockDate
                spacing: 0 
                anchors.centerIn: parent

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

            // INTERACTIVE CALENDAR LAUNCHER: Maps mouse detection across the dynamic boundary area safely
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor 

                // Double click interaction safeguards against accidental link execution loops
                onDoubleClicked: {

                    let targetUrl = "https://www.timeanddate.com/calendar/monthly.html";

                    // SYSTEM PASS-THROUGH: Explicitly feed the URL to xdg-open via our background Process item
                    if (root.isToolbox) {
                        urlLauncher.command = ["host-spawn", "xdg-open", targetUrl ];
                    } else {
                        urlLauncher.command = ["xdg-open", targetUrl ];
                    }
                    urlLauncher.running = true;
                }
            }
        }

        // -------------------------------------------------
        // --- 4. Accent Separation Rule Bar ---
        // -------------------------------------------------
        Rectangle {
            id: dateBar
            width: parent.width - 20
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
    // 3. Data Gathering & File System Processing Channels
    // ==================================================================
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }

    // High performance background execution channel for launching external system URL targets
    Process {
        id: urlLauncher
    }

    // One-Shot Timezone Path Reader (Fires exactly once at startup)
    Process {
        id: tzLinkReader
        // Natively reads the symlink destination with zero shell forks or awk pipes
        command: ["readlink", "/etc/localtime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let rawText = text ? text.trim() : "";

                if (rawText.length > 0) {
                    // remove first part and leave the timezone
                    let cityString = rawText.replace(/.*zoneinfo\//, "");

                    // Cleans up underscores natively and saves it as "New York"
                    root.timezoneText = cityString.replace(/_/g, " ");
                } else {
                    // Bulletproof Fallback: Uses our verified JS offset math if readlink fails
                    let dateStr = new Date().toString();
                    let match = dateStr.match(/GMT[-+]\d{4}/);
                    root.timezoneText = match ? match : "Local Time";
                }
            }
        }
    }

    // ==================================================================
    // 4. Automation & Driving Loops
    // ==================================================================
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // Kick the core clock pulse binding chain
            let d = new Date();
            root.currentTime = d;
            root.currentSecond = d.getSeconds();

            // High-performance, zero-fork Uptime Parsing Pass
            uptimeFile.reload();
            let rawData = uptimeFile.text().trim();
            if (rawData) {
                let uptimeSeconds = parseInt(rawData.split(/\s+/)[0], 10);
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

