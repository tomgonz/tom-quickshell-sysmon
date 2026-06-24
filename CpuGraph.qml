// CpuGraph.qml
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
    width: containerWidth
    height: mainColumn.height // Trace children footprint perfectly

    // for CPU temps
    required property string sensorChipName
    required property string sensorKeyName

    // This will hold the exact path discovered on startup (e.g. "/sys/class/hwmon/hwmon5/temp1_input")
    property string resolvedTempPath: ""


    // Dynamic Sizing Metrics
    property int maxHistoryPoints: Math.floor(containerWidth) - 2
    property var cpuHistory: []

    // --- Properties for Data ---
    property int lastTotal: 0
    property int lastIdle: 0
    property string cpuTemp: "--°C"
    property string cpuFreq: "-- GHz"
    property real currentCpuUsage: 0
    property string _buf: ""
    property string cpuModel: "Loading..."

    // ==================================================================
    // 2. Display Data on UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        // ------------------------------
        // --- 1. Header: Temp & Clock (Standard Left/Right Positioner) ---
        // ------------------------------
        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Clock: " + root.cpuFreq
                color: "white"
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Temp: " + root.cpuTemp
                color: "orange"
                font.pixelSize: 12
            }
        }

        // ------------------------------
        // --- 2. CPU Graph (Normal Upward - Tinted Cyan) ---
        // ------------------------------
        Rectangle {
            id: cpuGraphRect
            width: parent.width
            height: 50
            color: "#66000000"
            border.color: "#AA000000"
            border.width: 1

            Canvas {
                id: cpuGraphCanvas
                anchors.fill: parent
                anchors.margins: 1

                Connections {
                    target: root
                    function onCpuHistoryChanged() { cpuGraphCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    if (root.cpuHistory.length < 2) return;

                    ctx.fillStyle = "#00FFFF";
                    ctx.strokeStyle = "cyan";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(width, height);

                    let step = width / (root.maxHistoryPoints - 1);
                    for (let i = 0; i < root.cpuHistory.length; i++) {
                        let idx = root.cpuHistory.length - 1 - i;
                        let x = width - (i * step);
                        let y = height - (root.cpuHistory[idx] / 100) * height;
                        ctx.lineTo(x, y);
                    }
                    let lastX = width - ((root.cpuHistory.length - 1) * step);
                    ctx.lineTo(lastX, height);
                    ctx.closePath();

                    ctx.fill();
                    ctx.stroke();
                }
            }

            HoverHandler {
                id: textHover
            }
            
            Tooltip {
                id: cpuTooltip
                target: cpuGraphRect
                show: textHover.hovered
                text: root.cpuModel
                fontPixelSize: 18
            }
        }

        // ------------------------------
        // --- 3. Current Usage Text Readout ---
        // ------------------------------
        Item {
            width: parent.width
            height: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -1
                text: "CPU Usage: " + (root.currentCpuUsage < 10 ? root.currentCpuUsage.toFixed(1) : Math.round(root.currentCpuUsage)) + "%"
                color: "cyan"
                font.pixelSize: 14
            }
        }
    }

    // ==================================================================
    // Zero-Fork Data Gathering Subsystems
    // ==================================================================
    
    // One-shot CPU Model Reader
    FileView {
        id: cpuInfoReader
        path: "/proc/cpuinfo"
        onLoaded: {
            let content = (typeof text === "function") ? text() : text;
            if (!content) return;
            let lines = content.split("\n");
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("model name")) {
                    let parts = lines[i].split(":");
                    if (parts.length >= 2) {
                        root.cpuModel = parts[1].trim();
                    }
                    break;
                }
            }
        }
    }

    // Corei CPU Load Statistics Reader
    FileView {
        id: statReader
        path: "/proc/stat"
        onLoaded: {
            let content = (typeof text === "function") ? text() : text;
            if (!content) return;
            let lines = content.split("\n");
            
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line.startsWith("cpu ")) {
                    let parts = line.split(/\s+/);
                    let aggIdle = parseInt(parts[4]) + parseInt(parts[5]);
                    
                    // Sum up user, nice, system, idle, iowait, irq, softirq tokens
                    let aggTotal = 0;
                    for (let j = 1; j < 8; j++) {
                        aggTotal += parseInt(parts[j]) || 0;
                    }

                    if (root.lastTotal > 0) {
                        let dTotal = aggTotal - root.lastTotal;
                        let dIdle = aggIdle - root.lastIdle;
                        let aggUsage = dTotal > 0 ? 100 * (1 - dIdle / dTotal) : 0;
                        
                        let hist = [...root.cpuHistory];
                        hist.push(aggUsage);
                        if (hist.length > root.maxHistoryPoints) hist.shift();
                        root.cpuHistory = hist;
                        root.currentCpuUsage = aggUsage;
                    }
                    root.lastTotal = aggTotal;
                    root.lastIdle = aggIdle;
                    break;
                }
            }
        }
    }

    // Dynamic Clock Speed Frequency Reader
    FileView {
        id: freqReader
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        onLoaded: {
            let content = (typeof text === "function") ? text() : text;
            if (!content) return;
            let khz = parseInt(content.trim());
            if (!isNaN(khz)) {
                root.cpuFreq = (khz / 1000000).toFixed(2) + " GHz";
            }
        }
    }


    //----------------------------------------------
    // CPU Temp data processing (Hybrid Timer/Event State Machine)
    //----------------------------------------------
    
    // Internal state tracking properties
    property int _scanHwmonIdx: 0
    property int _scanLabelIdx: 1
    property string _foundHwmonPath: ""
    property bool _isInitialized: false

    // 1. Single reusable file reader
    FileView {
        id: sysfsReader
        printErrors: false // Prevents flooding logs when probing non-existent paths
        
        onLoaded: {
            // Securely evaluate the text string matching your working blocks
            let content = (typeof text === "function") ? text() : text;
            let cleaned = content ? content.trim() : "";
            if (!cleaned) return;

            // PHASE 1: Probing for driver match (e.g., "k10temp")
            if (root._foundHwmonPath === "" && !root._isInitialized) {
                if (cleaned === root.sensorChipName) {
                    // Match found! Lock directory path and shift state
                    root._foundHwmonPath = "/sys/class/hwmon/hwmon" + (root._scanHwmonIdx - 1);
                }
            } 
            
            // PHASE 2: Probing for sensor key match (e.g., "Tctl")
            else if (root._foundHwmonPath !== "" && !root._isInitialized) {
                if (cleaned === root.sensorKeyName) {
                    root.resolvedTempPath = root._foundHwmonPath + "/temp" + (root._scanLabelIdx - 1) + "_input";
                    root._isInitialized = true;
                }
            } 
            
            // PHASE 3: Standard Runtime Polling
            else if (root._isInitialized) {
                let milliDegrees = Number(cleaned);
                if (!isNaN(milliDegrees)) {
                    root.cpuTemp = Math.round(milliDegrees / 1000) + "°C";
                }
            }
        }
    }

    // 2. State Machine Driver: Drives indexing quickly at start, then switches to monitoring
    // This part only runs once at startup.
    // Finds the temp file needed from supplied vars in the /sys filesystem.
    Timer {
        id: tempUpdateTimer
        interval: root._isInitialized ? 2000 : 30 // 30ms ticks for fast discovery, 2s for runtime tracking
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // STEP A: Scan through hwmon0 to hwmon12 directories
            if (root._foundHwmonPath === "" && !root._isInitialized) {
                if (root._scanHwmonIdx < 13) {
                    sysfsReader.path = "/sys/class/hwmon/hwmon" + root._scanHwmonIdx + "/name";
                    root._scanHwmonIdx++;
                } else {
                    // Total search failure set to null so no temp shows
                    root.resolvedTempPath = "/dev/null";
                    root._isInitialized = true;
                }
                return;
            }

            // STEP B: Driver folder found, now scan label numbers 1 through 8
            if (root._foundHwmonPath !== "" && !root._isInitialized) {
                if (root._scanLabelIdx <= 8) {
                    sysfsReader.path = root._foundHwmonPath + "/temp" + root._scanLabelIdx + "_label";
                    root._scanLabelIdx++;
                } else {
                    // Fallback to default temp1_input if precise key label string is missing
                    root.resolvedTempPath = root._foundHwmonPath + "/temp1_input";
                    root._isInitialized = true;
                }
                return;
            }

            // STEP C: Active Monitoring Routine
            if (root._isInitialized) {
                sysfsReader.path = root.resolvedTempPath;
                sysfsReader.reload();
            }
        }
    }

    // ==================================================================
    // Unified Control Loops
    // ==================================================================
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statReader.reload();
            freqReader.reload();
        }
    }
}

