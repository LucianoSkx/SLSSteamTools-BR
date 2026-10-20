import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    title: "Sincronização de estatísticas"

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 12

            Item { height: 8 }

            Label {
                text: "Sincronização de estatísticas"
                font.pointSize: 16
                font.bold: true
                Layout.leftMargin: 20
            }

            Label {
                text: "Recursos experimentais! Podem causar perda de dados e problemas estranhos! Você foi avisado!"
                opacity: 0.7
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        text: "Ativar sincronização de estatísticas"
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Switch {
                        checked: backend ? backend.statsSyncEnabled : true
                        onToggled: { if (backend) backend.statsSyncEnabled = checked }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: (backend && backend.statsSyncEnabled) ? 1.0 : 0.5

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        text: "Sincronizar conquistas"
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Switch {
                        checked: backend ? backend.syncAchievements : false
                        enabled: backend ? backend.statsSyncEnabled : false
                        onToggled: { if (backend) backend.syncAchievements = checked }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: (backend && backend.statsSyncEnabled) ? 1.0 : 0.5

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        text: "Sincronizar tempo de jogo"
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Switch {
                        checked: backend ? backend.syncPlaytime : false
                        enabled: backend ? backend.statsSyncEnabled : false
                        onToggled: { if (backend) backend.syncPlaytime = checked }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
