// CpuGraph.qml
//
// GPL-3.0 license
//
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    // ==================================================================
    // 1. User Tweakable Configurations & Variables
    // ==================================================================
    required property real containerWidth
    required property string sensorChipName
    required property string sensorKeyName

    height: mainColumn.height + 8
    radius: rootWindow.widgetRadius
    color: rootWindow.widgetBGcolor
    border.color: rootWindow.widgetBorderColor
    border.width: 2
    property int barSpacing: 1 
    property color barColor: "white"

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
    property var coreUsages: []
    property var lastCoreTotal: []
    property var lastCoreIdle: []


    // ==================================================================
    // 2. Display Data on UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: root.containerWidth
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        // ------------------------------
        // --- 1. Header: Temp & Clock ---
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
        // --- 2. CPU Usage Graph ---
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
                fontPixelSize: 14
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

        // Spacer
        Item {
            width: 1
            height: 3
        }
        // -----------------------------------------------
        // Core Usage Container Vertical Bars
        // -----------------------------------------------
        Rectangle {
            width: parent.width
            height: 40
            color: "transparent"

            // Standardized Row Positioner handles bar grid spacing with 0% layout overhead
            Row {
                id: coreRow
                anchors.centerIn: parent
                height: parent.height
                spacing: root.barSpacing

                // Computes pixel-perfect uniform bar widths on the fly
                readonly property real optimalBarWidth: {
                    let totalCores = root.coreUsages ? root.coreUsages.length : 1;
                    if (totalCores === 0) return 1;
                    let totalSpacing = root.barSpacing * (totalCores - 1);
                    return Math.max(1, Math.floor((root.containerWidth - totalSpacing) / totalCores));
                }

                Repeater {
                    model: root.coreUsages
                    delegate: Item {
                        width: coreRow.optimalBarWidth
                        height: coreRow.height

                        // 1. Static Background Track
                        Rectangle {
                            anchors.fill: parent
                            color: "#66000000" // Black 50% transparent background
                        }

                        // 2. Dynamic Usage Bar (Grows Upward from Bottom Boundary)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(0, Math.min(parent.height, parent.height * (modelData / 100.0)))
                            color: root.barColor
                        }
                    }
                }
            }
        }

    }

    // ==================================================================
    // Data Gathering Section
    // ==================================================================

    // -----------------------------------------
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

    // -----------------------------------------
    // Core CPU Load Statistics Reader
    FileView {
        id: statReaderAvg
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

    FileView {
        id: statReader
        path: "/proc/stat"

        onLoaded: {
            let content = (typeof text === "function") ? text() : text;
            if (!content) return;

            let lines = content.split("\n");
            let newCoreTotal = [];
            let newCoreIdle = [];
            let newCoreUsage = [];

            // 1. First pass: Determine max core index safely
            let maxIndex = -1;
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                let parts = line.split(/\s+/);
                if (parts[0].startsWith("cpu") && parts[0].length > 3) {
                    let coreNumStr = parts[0].substring(3);
                    let idx = parseInt(coreNumStr);
                    if (!isNaN(idx)) {
                        maxIndex = Math.max(maxIndex, idx);
                    }
                }
            }

            if (maxIndex === -1) return; // No per-core metrics parsed

            // Initialize data vectors
            for (let i = 0; i <= maxIndex; i++) {
                newCoreUsage.push(0);
                newCoreTotal.push(0);
                newCoreIdle.push(0);
            }

            // 2. Second pass: Calculate differential core delta loads
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                let parts = line.split(/\s+/);

                // Matches individual lines (cpu0, cpu1, cpu12, etc.) but skips aggregate total "cpu " line
                if (parts[0].startsWith("cpu") && parts[0].length > 3 && !isNaN(parseInt(parts[0].charAt(3)))) {
                    let coreIndex = parseInt(parts[0].substring(3));
                    let idle = parseInt(parts[4]) || 0; // Index 4 matches core idle state cycles

                    let total = 0;
                    for (let j = 1; j < parts.length; j++) {
                        total += parseInt(parts[j]) || 0;
                    }

                    if (root.lastCoreTotal[coreIndex] !== undefined) {
                        let dTotal = total - root.lastCoreTotal[coreIndex];
                        let dIdle = idle - root.lastCoreIdle[coreIndex];

                        let usage = 0;
                        if (dTotal > 0) {
                            //usage = 100 * (1 - (dIdle / dTotal));
                            usage = 100 * (1 - (dIdle / dTotal));
                        }
                        newCoreUsage[coreIndex] = usage;
                    }

                    newCoreTotal[coreIndex] = total;
                    newCoreIdle[coreIndex] = idle;
                }
            }

            // Atomically update data properties to avoid layout micro-stuttering
            root.coreUsages = newCoreUsage;
            root.lastCoreTotal = newCoreTotal;
            root.lastCoreIdle = newCoreIdle;
        }
    }

    // -----------------------------------------
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



    // Compressed scanning states
    property int _hIdx: 0
    property int _lIdx: 1
    property string _baseDir: ""
    property bool pathVarIsReady: false

    // -----------------------------------------
    // SECTION 1: One-Shot Discovery for CPU temp path/file
    // -----------------------------------------
    FileView {
        id: discoveryReader
        printErrors: false
        onLoaded: {
            let txt = (typeof text === "function" ? text() : text).trim();
            if (!txt) return;

            if (_baseDir === "" && txt === root.sensorChipName) {
                _baseDir = "/sys/class/hwmon/hwmon" + (_hIdx - 1);
            } else if (_baseDir !== "" && txt === root.sensorKeyName) {
                resolvedTempPath = _baseDir + "/temp" + (_lIdx - 1) + "_input";
                pathVarIsReady = true;      // 🏁 MASTER SWITCH: Stops scan, starts polling
            }
        }
    }

    // -----------------------------------------
    // SECTION 2: Pure Runtime Reader (Timer polling every 2 Seconds)
    // -----------------------------------------
    FileView {
        id: sysfsReader
        path: root.resolvedTempPath
        printErrors: false
        onLoaded: {
            let txt = (typeof text === "function" ? text() : text).trim();
            if (!isNaN(txt)) root.cpuTemp = Math.round(Number(txt) / 1000) + "°C";
        }
    }


    // ==================================================================
    // Runtime Control Timer Loops
    // ==================================================================
    Timer {
        interval: 25
        running: !root.pathVarIsReady     // Runs only while cpu temp path is NOT ready
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (_baseDir === "") {
                if (_hIdx < 16) {
                    discoveryReader.path = "/sys/class/hwmon/hwmon" + _hIdx++ + "/name";
                } else {
                    resolvedTempPath = "/dev/null";   // could not find a cpu temp path
                    pathVarIsReady = true;
                }
            } else {
                if (_lIdx <= 8) {
                    discoveryReader.path = _baseDir + "/temp" + _lIdx++ + "_label";
                } else {
                    resolvedTempPath = _baseDir + "/temp1_input";
                    pathVarIsReady = true;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.pathVarIsReady // Wakes up the exact moment the master switch flips
        repeat: true
        triggeredOnStart: true 
        onTriggered: sysfsReader.reload()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statReaderAvg.reload();
            freqReader.reload();

        }
    }

    Timer {
        interval: 600
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statReader.reload();
        }
    }

}

