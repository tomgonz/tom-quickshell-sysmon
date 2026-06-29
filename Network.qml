// Network.qml
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

    height: mainColumn.height + 6
    radius: rootWindow.widgetRadius
    color: rootWindow.widgetBGcolor
    border.color: rootWindow.widgetBorderColor
    border.width: 2

    // --- Configuration Inputs ---
    property string interfaceName: rootWindow.netDev
    property int historyLimit: Math.floor(containerWidth) - 2
    property string netIP: "0.0.0.0"

    // --- Output Metrics for Graphs ---
    readonly property real netUpBitsSec: _netUpBitsSec
    readonly property real netDownBitsSec: _netDownBitsSec
    readonly property real netUpMax: _netUpMax
    readonly property real netDownMax: _netDownMax

    // --- Internal State Properties ---
    property real _netUpBitsSec: 0
    property real _netDownBitsSec: 0
    property real _netUpMax: 1
    property real _netDownMax: 1

    property var historyUp: []
    property var historyDown: []

    property int lastRxBytes: 0
    property int lastTxBytes: 0
    property bool isInitialized: false

    // Helper formatting function to convert bits/sec to readable metrics (Kbps, Mbps)
    function formatSpeed(bits) { 
        if (bits >= 1024 * 1024 * 1024) return (bits / (1024 * 1024 * 1024)).toFixed(0) + " Gbps"
        if (bits >= 1024 * 1024) return (bits / (1024 * 1024)).toFixed(0) + " Mbps"
        if (bits >= 1024) return (bits / 1024).toFixed(0) + " Kbps"
        return bits.toFixed(0) + " bps"
    }    

    // ==================================================================
    // 2. Display Data on UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: root.containerWidth
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        // Spacer
        Item {
            width: 1
            height: 2
        }

        // ---------------------------
        // --- 1. Network dev & IP Header (Standard Left/Right Positioner) ---
        // ---------------------------
        Item {
            id: netHeaderItem
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Net: " + root.interfaceName
                color: "white"
                font.pixelSize: 14
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: " (" + root.netIP + ")"
                color: "white"
                font.pixelSize: 10
            }
        }

        // Spacer
        Item {
            width: 1
            height: 3
        }

        // ---------------------------
        // --- 2. Net Upload Speed Labels ---
        // ---------------------------
        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: -2 // Closes structural text gap rows cleanly
                color: "#00BBFF"
                font.pixelSize: 12
                text: "Up: " + root.formatSpeed(root.netUpBitsSec)
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -2
                color: "#00BBFF"
                font.pixelSize: 12
                text: "Max: " + root.formatSpeed(root.netUpMax)
            }
        }

        // ---------------------------
        // --- 3. Net Upload Graph (Normal Upward) ---
        // ---------------------------
        Rectangle {
            id: uploadGraphContainer
            width: parent.width // Aligned width matches grid frames
            height: 35
            color: "#66000000"
            border.color: "#AA000000"
            border.width: 1

            Canvas {
                id: upCanvas
                anchors.fill: parent
                anchors.margins: 1

                Connections {
                    target: root
                    function onHistoryUpChanged() { upCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()

                    // PERFORMANCE: Cache properties locally to prevent C++/JS engine overhead
                    let data = root.historyUp
                    let len = data.length
                    let maxVal = root.netUpMax
                    let limit = root.historyLimit

                    // ROBUSTNESS: Prevent crashes, NaN layout bugs, and division-by-zero
                    if (len < 2 || maxVal <= 0 || limit <= 1) return

                    ctx.fillStyle = "#00BBFF"
                    ctx.strokeStyle = "#00BBFF"
                    ctx.lineWidth = 1
                    ctx.beginPath()

                    // Baseline for Normal Upward graph is Y = height (bottom)
                    ctx.moveTo(width, height)

                    let step = width / (limit - 1)

                    for (let i = 0; i < len; i++) {
                        let idx = len - 1 - i
                        let x = width - (i * step)

                        // Normal Upward Math: 
                        // 0 value results in y = height (physical bottom)
                        // max value results in y = 0 (physical top)
                        let y = height - ((data[idx] / maxVal) * height)

                        ctx.lineTo(x, y)
                    }

                    // Close the path clean along the bottom baseline (Y = height)
                    let lastX = width - ((len - 1) * step)
                    ctx.lineTo(lastX, height)
                    ctx.closePath()

                    ctx.fill()
                    ctx.stroke()
                }
            }
        }

        // ---------------------------
        // --- 4. Middle Section Divider Rule ---
        // ---------------------------
        Rectangle {
            id: sepBar
            width: parent.width
            height: 1
            color: "#777777"
        }

        // ---------------------------
        // --- 5. Download Graph (Flipped Vertically - Tinted Red) ---
        // ---------------------------
        Rectangle {
            id: downloadGraphContainer
            width: parent.width // Standardized to match master panel tracking lines
            height: 35
            color: "#66000000"
            border.color: "#AA000000"
            border.width: 1

            // Flushes the top edge of this container directly under your sepBar line
            anchors.topMargin: -1 

            Canvas {
                id: downCanvas
                anchors.fill: parent
                anchors.margins: 1

                // Removed the old QML transform block. 
                // Handling the inversion in pure math runs significantly faster.

                Connections {
                    target: root
                    function onHistoryDownChanged() { downCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()

                    // PERFORMANCE: Cache properties locally to prevent engine cross-boundary lag
                    let data = root.historyDown
                    let len = data.length
                    let maxVal = root.netDownMax
                    let limit = root.historyLimit

                    // ROBUSTNESS: Safeguard against empty data, negative values, or zero division
                    if (len < 2 || maxVal <= 0 || limit <= 1) return

                    ctx.fillStyle = "#ff3333"
                    ctx.strokeStyle = "#ff3333"
                    ctx.lineWidth = 1
                    ctx.beginPath()

                    // 0 is at the top in flipped mode, so our fill baseline is Y = 0
                    ctx.moveTo(width, 0)

                    let step = width / (limit - 1)

                    for (let i = 0; i < len; i++) {
                        let idx = len - 1 - i
                        let x = width - (i * step)

                        // EFFICIENT MATH FLIP: 
                        // 0 value results in y = 0 (physical top)
                        // max value results in y = height (physical bottom)
                        let y = (data[idx] / maxVal) * height

                        ctx.lineTo(x, y)
                    }

                    // Close the path clean along the top baseline (Y = 0)
                    let lastX = width - ((len - 1) * step)
                    ctx.lineTo(lastX, 0)
                    ctx.closePath()

                    ctx.fill()
                    ctx.stroke()
                }
            }
        }

        // ---------------------------
        // --- 6. Download Text Readout Label ---
        // ---------------------------
        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: -2 // Pulls layout upward to tightly hug the graph border above it
                color: "#FF3333"
                font.pixelSize: 12
                text: "Down: " + root.formatSpeed(root.netDownBitsSec)
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -2
                color: "#FF3333"
                font.pixelSize: 12
                text: "Max: " + root.formatSpeed(root.netDownMax)
            }
        }
    } // End of master mainColumn positioner tree

    // ==================================================================
    //  3. Data Gathering & Sysfs Kernel Processing Channels
    // ==================================================================

    // Dynamic IP address node evaluation channel
    Process {
        id: ipLookup
        // Natively invoke ip route targets directly without wrapping extra sh or awk interpreters
        command: root.interfaceName ? ["ip", "-o", "-4", "addr", "show", "dev", root.interfaceName] : []
        running: root.interfaceName !== ""

        stdout: StdioCollector {
            onStreamFinished: {
                let rawText = text ? text.trim() : "";
                if (!rawText) return;

                // Robust JS Parsing: Match standard IPv4 token string structures
                let match = rawText.match(/inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/);
                if (match && match[1]) {
                    root.netIP = match[1];
                    ipLookup.running = false; // Terminate tool pass instantly to release memory
                }
            }
        }
    }

    // High performance sysfs statistics memory pipes
    FileView {
        id: rxFile
        path: "/sys/class/net/" + root.interfaceName + "/statistics/rx_bytes"
    }

    FileView {
        id: txFile
        path: "/sys/class/net/" + root.interfaceName + "/statistics/tx_bytes"
    }

    // ==================================================================
    // Iteration Timing loops
    // ==================================================================
    property var _trackerState: ({ lastRx: 0, lastTx: 0, initialized: false })

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: false

        onTriggered: {
            rxFile.reload()
            txFile.reload()

            // 1. PERFORMANCE: Directly grab and trim text via standard functional lookups
            let rxRaw = rxFile.text().trim()
            let txRaw = txFile.text().trim()

            // 2. RADIX SAFETY: Always parse numeric values with a clear radix 10 baseline
            let currentRx = parseInt(rxRaw || "0", 10) || 0
            let currentTx = parseInt(txRaw || "0", 10) || 0
            let state = root._trackerState

            if (currentRx === 0 || currentTx === 0) return

            if (!state.initialized) {
                state.lastRx = currentRx
                state.lastTx = currentTx
                state.initialized = true
                root._trackerState = state
                return
            }

            let deltaRx = currentRx - state.lastRx
            let deltaTx = currentTx - state.lastTx

            if (deltaRx < 0) deltaRx = 0
            if (deltaTx < 0) deltaTx = 0

            // Translate hardware byte changes -> Bits per second
            root._netDownBitsSec = deltaRx * 8
            root._netUpBitsSec = deltaTx * 8

            // 3. OPTIMIZATION: Use high-efficiency slice copies instead of array spreads
            let upHist = root.historyUp.slice()
            let downHist = root.historyDown.slice()

            upHist.push(root._netUpBitsSec)
            downHist.push(root._netDownBitsSec)

            let limit = root.historyLimit
            if (upHist.length > limit) upHist.shift()
            if (downHist.length > limit) downHist.shift()

            root.historyUp = upHist
            root.historyDown = downHist

            // 4. STABILITY FIX: Fast, crash-proof manual loops protect against stack overflows
            let maxUp = 1
            for (let u = 0; u < upHist.length; u++) {
                if (upHist[u] > maxUp) maxUp = upHist[u]
            }
            root._netUpMax = maxUp

            let maxDown = 1
            for (let d = 0; d < downHist.length; d++) {
                if (downHist[d] > maxDown) maxDown = downHist[d]
            }
            root._netDownMax = maxDown

            state.lastRx = currentRx
            state.lastTx = currentTx
            root._trackerState = state
        }
    }
}

