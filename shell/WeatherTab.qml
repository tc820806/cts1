// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): layout from modules/dashboard/WeatherTab.qml.
import QtQuick
import QtQuick.Layouts

// Weather popup, mirroring Caelestia's WeatherTab.qml.
Item {
    id: root

    implicitWidth: 840
    implicitHeight: layout.implicitHeight

    component DetailCard: Rectangle {
        id: detail
        property string icon
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: 6
        color: Theme.m3surfaceContainer

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacing.medium

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: detail.icon
                font.pixelSize: 28
                color: detail.colour
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    text: detail.label
                    font.pixelSize: Theme.fontSize.small
                    opacity: 0.7
                }
                StyledText {
                    text: detail.value
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    component WeatherStat: Row {
        id: stat
        property string icon
        property string label
        property string value
        property color colour

        spacing: Theme.spacing.small

        MaterialIcon {
            text: stat.icon
            font.pixelSize: 32
            color: stat.colour
        }
        Column {
            StyledText {
                text: stat.label
                font.pixelSize: Theme.fontSize.small
                color: Theme.m3onSurfaceVariant
            }
            StyledText {
                text: stat.value
                font.pixelSize: Theme.fontSize.small
                font.weight: Font.DemiBold
            }
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacing.small

        RowLayout {
            Layout.leftMargin: Theme.padding.large
            Layout.rightMargin: Theme.padding.large
            Layout.fillWidth: true

            Column {
                spacing: Theme.spacing.extraSmall

                StyledText {
                    text: Weather.city || Weather.description
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font.pixelSize: Theme.fontSize.small
                    color: Theme.m3onSurfaceVariant
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: Theme.spacing.largeIncreased

                WeatherStat { icon: "wb_twilight"; label: "Sunrise"; value: Weather.sunrise; colour: Theme.m3tertiary }
                WeatherStat { icon: "bedtime"; label: "Sunset"; value: Weather.sunset; colour: Theme.m3tertiary }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bigInfo.implicitHeight + Theme.padding.small
            radius: 6
            color: Theme.m3surfaceContainer

            RowLayout {
                id: bigInfo
                anchors.centerIn: parent
                spacing: Theme.spacing.largeIncreased

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.icon
                    font.pixelSize: 64
                    color: Theme.m3secondary
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Theme.spacing.small

                    StyledText {
                        text: Weather.temp
                        font.pixelSize: 44
                        font.weight: Font.Medium
                        color: Theme.m3primary
                    }
                    StyledText {
                        Layout.leftMargin: Theme.padding.extraSmall
                        text: Weather.description
                        font.pixelSize: Theme.fontSize.larger
                        color: Theme.m3onSurfaceVariant
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            DetailCard { icon: "water_drop"; label: "Humidity"; value: Weather.humidity + "%"; colour: Theme.m3secondary }
            DetailCard { icon: "thermostat"; label: "Feels like"; value: Weather.feelsLike; colour: Theme.m3primary }
            DetailCard { icon: "air"; label: "Wind"; value: Weather.windSpeed ? Weather.windSpeed + " km/h" : "--"; colour: Theme.m3tertiary }
        }

        StyledText {
            Layout.leftMargin: Theme.padding.medium
            visible: Weather.forecast.length > 0
            text: "7-day forecast"
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing.medium

            Repeater {
                model: Weather.forecast

                Rectangle {
                    id: day
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: dayCol.implicitHeight + Theme.padding.small * 2
                    radius: 6
                    color: Theme.m3surfaceContainer

                    ColumnLayout {
                        id: dayCol
                        anchors.centerIn: parent
                        spacing: Theme.spacing.extraSmall

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.index === 0 ? "Today" : new Date(day.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                            font.weight: Font.DemiBold
                            color: Theme.m3primary
                        }
                        StyledText {
                            Layout.topMargin: -Theme.spacing.extraSmall
                            Layout.alignment: Qt.AlignHCenter
                            text: new Date(day.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                            font.pixelSize: Theme.fontSize.small
                            opacity: 0.7
                            color: Theme.m3onSurfaceVariant
                        }
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.modelData.icon
                            font.pixelSize: 26
                            color: Theme.m3secondary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round(Weather.toUnit(day.modelData.minTempC)) + "° / " + Math.round(Weather.toUnit(day.modelData.maxTempC)) + "°"
                            font.pixelSize: Theme.fontSize.small
                            font.weight: Font.DemiBold
                            color: Theme.m3tertiary
                        }
                    }
                }
            }
        }
    }
}
