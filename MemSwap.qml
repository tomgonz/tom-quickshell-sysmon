// MemSwap.qml
//
// GPL-3.0 license
//
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ==================================================================
    // 1. User Tweakable Configurations & Variables
    // ==================================================================
    required property real containerWidth
    
    // Core Sizing Rule: Let height dynamically bound itself to follow child footprints exactly
    width: containerWidth 
    height: mainColumn.height

    property real memTotal: 0
    property real memUsed: 0
    property real memPerUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real swapPerUsed: 0
    
    property var memHistory: []
    property int maxHistoryPoints: Math.floor(containerWidth) - 2

    // ==================================================================
    // 2. Display Data on UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        // ---------------------------
        // --- 1. Title Header Bar ---
        // ---------------------------
        Row {
            width: parent.width
            height: 18 // Tightened height bounds to sit safely inside your 116px container limit
            spacing: 4
            
            Text {
                text: "Mem: " + root.memTotal.toFixed(1) + "G / "
                color: "white"
                font.pixelSize: 13
            }
            Text {
                text: "Swap: " + root.swapTotal.toFixed(1) + "G"
                color: "white"
                font.pixelSize: 13
            }
        }

        // ---------------------------
        // --- 2. Memory Graph (Normal Upward) ---
        // ---------------------------
        Rectangle {
            id: memGraphRect
            width: parent.width
            height: 40 // Standardized graph frame heights
            color: "#66000000"
            border.color: "#AA000000"
            border.width: 1

            Canvas {
                id: memGraphCanvas
                anchors.fill: parent
                anchors.margins: 1

                Connections {
                    target: root
                    function onMemHistoryChanged() { memGraphCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    if (root.memHistory.length < 2) return;

                    ctx.fillStyle = "#00FF00";
                    ctx.strokeStyle = "#00FF00"; 
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(width, height);

                    let step = width / (root.maxHistoryPoints - 1);
                    for (let i = 0; i < root.memHistory.length; i++) {
                        let idx = root.memHistory.length - 1 - i;
                        let x = width - (i * step);
                        let percent = (root.memTotal > 0) ? (root.memHistory[idx] / root.memTotal) * 100 : 0;
                        let y = height - (percent / 100) * height;
                        ctx.lineTo(x, y);
                    }
                    let lastX = width - ((root.memHistory.length - 1) * step);
                    ctx.lineTo(lastX, height);
                    ctx.closePath();
                    
                    ctx.fill();
                    ctx.stroke();
                }
            }   
        }
        
        // ---------------------------
        // --- 3. Memory Text Readout ---
        // ---------------------------
        Item {
            width: parent.width
            height: 14
            
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: -2 // Shuts padding gap gaps tightly
                text: "Mem used:  " + root.memUsed.toFixed(1) + "G   (" + root.memPerUsed.toFixed(1) + "%)"
                color: "#00FF00"
                font.pixelSize: 12
            }
        }

        // ---------------------------
        // --- 4. Swap Status Bar Track ---
        // ---------------------------
        Item {
            width: parent.width
            height: 12

            Rectangle {
                width: parent.width
                height: 8
                anchors.centerIn: parent
                color: "#66000000"
                border.color: "#FF3333"
                border.width: 1

                Rectangle {
                    id: swapBarFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: (root.swapTotal > 0) ? Math.max(0, (parent.width - 2) * (root.swapUsed / root.swapTotal)) : 0
                    color: "#FF3333"
                    
                    Behavior on width { NumberAnimation { duration: 250 } }
                }
            }
        }

        // ---------------------------
        // --- 5. Swap Text Readout ---
        // ---------------------------
        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: -2
                text: "Swap used:  " + root.swapUsed.toFixed(1) + "G   (" + root.swapPerUsed.toFixed(1) + "%)"
                color: "#FF3333"
                font.pixelSize: 12
            }
        }
    }

    // ==================================================================
    //  Data Gathering Subsystems
    // ==================================================================
    FileView {
        id: memInfoReader
        path: "/proc/meminfo"
        
        onLoaded: {
            let content = (typeof text === "function") ? text() : text;
            if (!content) return;
            let lines = content.split("\n");
            let data = { memTotal: 0, memAvailable: 0, swapTotal: 0, swapFree: 0 };

            function parseGB(line) {
                let parts = line.split(":");
                if (parts.length < 2) return 0;
                let valStr = parts[1].trim().split(/\s+/)[0];
                let kb = parseInt(valStr);
                return isNaN(kb) ? 0 : kb / (1024 * 1024); 
            }

            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line.startsWith("MemTotal:")) data.memTotal = parseGB(line);
                else if (line.startsWith("MemAvailable:")) data.memAvailable = parseGB(line);
                else if (line.startsWith("SwapTotal:")) data.swapTotal = parseGB(line);
                else if (line.startsWith("SwapFree:")) data.swapFree = parseGB(line);
            }

            root.memTotal = data.memTotal;
            root.memUsed = data.memTotal - data.memAvailable;
            root.memPerUsed = data.memTotal > 0 ? (root.memUsed / data.memTotal * 100) : 0;
            root.swapTotal = data.swapTotal;
            root.swapUsed = data.swapTotal - data.swapFree;
            root.swapPerUsed = data.swapTotal > 0 ? (root.swapUsed / data.swapTotal * 100) : 0;

            let hist = [...root.memHistory];
            hist.push(root.memUsed);
            if (hist.length > root.maxHistoryPoints) hist.shift();
            root.memHistory = hist;
        }
    }

    // High performance tracking loop execution cycle
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memInfoReader.reload()
    }
}

