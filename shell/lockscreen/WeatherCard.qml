// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): layout from modules/dashboard/WeatherTab.qml.
import QtQuick
import QtQuick.Layouts
import qs

// Lock screen weather: the top of WeatherTab.qml, no forecast ("Weather is off" when off).
Item {
    id: root

    implicitWidth: 320
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
            spacing: Theme.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: detail.icon
                font.pixelSize: 24
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

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacing.small

        Column {
            Layout.leftMargin: Theme.padding.small
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
            spacing: Theme.spacing.small

            DetailCard { icon: "water_drop"; label: "Humidity"; value: Weather.humidity + "%"; colour: Theme.m3secondary }
            DetailCard { icon: "thermostat"; label: "Feels like"; value: Weather.feelsLike; colour: Theme.m3primary }
            DetailCard { icon: "air"; label: "Wind"; value: Weather.windSpeed ? Weather.windSpeed + " km/h" : "--"; colour: Theme.m3tertiary }
        }
    }
}
