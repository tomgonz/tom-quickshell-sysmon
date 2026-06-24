// Network.qml
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
    height: mainColumn.height // Dynamic bounding follows footprint exactly

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
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

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
                    if (root.historyUp.length < 2) return

                    ctx.fillStyle = "#00BBFF"
                    ctx.strokeStyle = "#00BBFF"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(width, height)

                    let step = width / (root.historyLimit - 1)
                    for (let i = 0; i < root.historyUp.length; i++) {
                        let dataIndex = root.historyUp.length - 1 - i
                        let x = width - (i * step)
                        let ratio = root.historyUp[dataIndex] / root.netUpMax
                        let y = height - (ratio * height)
                        ctx.lineTo(x, y)
                    }

                    let lastX = width - ((root.historyUp.length - 1) * step)
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
                
                transform: [
                    Scale { yScale: -1 },
                    Translate { y: downCanvas.height }
                ]

                Connections {
                    target: root
                    function onHistoryDownChanged() { downCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()
                    if (root.historyDown.length < 2) return

                    ctx.fillStyle = "#ff3333"
                    ctx.strokeStyle = "#ff3333"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(width, height)

                    let step = width / (root.historyLimit - 1)
                    for (let i = 0; i < root.historyDown.length; i++) {
                        let dataIndex = root.historyDown.length - 1 - i
                        let x = width - (i * step)
                        let ratio = root.historyDown[dataIndex] / root.netDownMax
                        let y = height - (ratio * height)
                        ctx.lineTo(x, y)
                    }

                    let lastX = width - ((root.historyDown.length - 1) * step)
                    ctx.lineTo(lastX, height)
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
        command: ["sh", "-c", "ip -o -4 addr show '" + root.interfaceName + "' | awk '{print $4}' | cut -d/ -f1"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let outText = data ? data.trim() : ""
                if (outText.length > 0) {
                    root.netIP = outText
                    ipLookup.running = false // Terminate tool pass instantly to release memory
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

            let rxRaw = (typeof rxFile.text === "function") ? rxFile.text() : rxFile.text
            let txRaw = (typeof txFile.text === "function") ? txFile.text() : txFile.text

            let currentRx = parseInt(rxRaw ? rxRaw.trim() : "0") || 0
            let currentTx = parseInt(txRaw ? txRaw.trim() : "0") || 0
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

            let upHist = [...root.historyUp]
            let downHist = [...root.historyDown]

            upHist.push(root._netUpBitsSec)
            downHist.push(root._netDownBitsSec)

            if (upHist.length > root.historyLimit) upHist.shift()
            if (downHist.length > root.historyLimit) downHist.shift()

            root.historyUp = upHist
            root.historyDown = downHist

            root._netUpMax = Math.max(...upHist, 1)
            root._netDownMax = Math.max(...downHist, 1)

            state.lastRx = currentRx
            state.lastTx = currentTx
            root._trackerState = state
        }
    }
}

