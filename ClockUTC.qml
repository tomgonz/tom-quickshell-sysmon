// ClockUTC.qml
//
// GPL-3.0 license
//
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

Rectangle {
    id: utcRoot

    required property real containerWidth

    height: Math.floor(0.400 * rootWindow.mywidth + 7)
    //height: mainColumn.height + 8
    radius: rootWindow.widgetRadius
    color: rootWindow.widgetBGcolor
    border.color: rootWindow.widgetBorderColor
    border.width: 2

    // width: parent ? parent.width : 220

    // --- Dynamic Time Tracking States ---
    property var currentTime: new Date()
    property int currentSecond: currentTime.getUTCSeconds()

    // ==================================================================
    //  UI Layout (Standardized Positioner)
    // ==================================================================
    Column {
        id: mainColumn
        width: parent.width
        spacing: 2
        anchors.horizontalCenter: parent.horizontalCenter

        // -----------------------------------------------
        // --- 1. UTC Time Display Block ---
        // -----------------------------------------------
        Rectangle {
            id: targetText
            width: timeText.implicitWidth
            height: timeText.implicitHeight - 6 // Matches padding configurations exactly
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: timeText
                // Evaluates and renders real UTC values directly
                text: {
                    let h = String(utcRoot.currentTime.getUTCHours()).padStart(2, '0');
                    let m = String(utcRoot.currentTime.getUTCMinutes()).padStart(2, '0');
                    let s = String(utcRoot.currentTime.getUTCSeconds()).padStart(2, '0');
                    return `${h}:${m}:${s}`;
                }
                font.pixelSize: (utcRoot.width / 10) * 2
                color: "white"
                anchors.centerIn: parent
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
                width: parent.width * (utcRoot.currentSecond / 59)
                color: "white"
            }
        }

        // -----------------------------------------------
        // --- 3. UTC Date Text Array ---
        // -----------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0 

            Text {
                // Generates UTC adjusted calendar tokens natively
                text: {
                    // Extract days array shorthand matching "ddd " layout profile
                    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                    return days[utcRoot.currentTime.getUTCDay()] + " ";
                }
                font.pixelSize: (utcRoot.width / 10)
                color: "#FF3333"
                style: Text.Outline
                styleColor: "#22000000"
            }
            Text {
                text: {
                    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                    let day = String(utcRoot.currentTime.getUTCDate()).padStart(2, '0');
                    let mon = months[utcRoot.currentTime.getUTCMonth()];
                    let yr = utcRoot.currentTime.getUTCFullYear();
                    return `  ${day}-${mon}-${yr}`;
                }
                font.pixelSize: (utcRoot.width / 10)
                color: "#00BBFF"
                style: Text.Outline
                styleColor: "#22000000"
            }
        }
    }

    // ==================================================================
    //  Data Gathering Time Engine Loop
    // ==================================================================
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // Kick the layout loop to evaluate all UTC binding elements simultaneously
            utcRoot.currentTime = new Date();
            utcRoot.currentSecond = utcRoot.currentTime.getUTCSeconds();
        }
    }
}

