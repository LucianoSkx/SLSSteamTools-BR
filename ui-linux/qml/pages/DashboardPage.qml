import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    title: "Painel"
    
    // Track auth state locally so bindings update
    property bool providerAuth: backend ? backend.providerAuthenticated : false

    function formatProviderName(name) {
        if (backend) return backend.providerLabel(name)
        return name
    }
    
    function refreshState() {
        providerAuth = backend ? backend.providerAuthenticated : false
    }

    Component.onCompleted: {
        console.log("DashboardPage.onCompleted - calling fetchRemoteApps")
        // Fetch remote apps when dashboard loads
        if (backend) backend.fetchRemoteApps()
    }
    
    Connections {
        target: backend
        function onSettingsChanged() {
            refreshState()
        }
        function onStatusChanged() {
            refreshState()
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 12

            Item { height: 8 }

            Label {
                text: "Painel"
                font.pointSize: 16
                font.bold: true
                Layout.leftMargin: 20
            }

            Label {
                text: "CloudRedirect v" + (backend ? backend.version : "")
                Layout.leftMargin: 20
                opacity: 0.7
            }

            Label {
                text: "Bem-vindo!"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: 0.7
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Label {
                        text: "Provedor de nuvem"
                        font.bold: true
                    }
                    Label {
                        text: {
                            if (!backend || !backend.providerName || backend.providerName === "local")
                                return "Não configurado"
                            if (providerAuth)
                                return formatProviderName(backend.providerName) + " — Autenticado"
                            return formatProviderName(backend.providerName) + " — Não autenticado"
                        }
                        opacity: 0.7
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Label {
                        text: "Aplicativos sincronizados"
                        font.bold: true
                    }
                    Label {
                        text: {
                            var local = backend ? backend.managedAppCount : 0
                            var remoteOnly = backend ? backend.remoteOnlyAppCount : 0
                            if (remoteOnly > 0)
                                return local + " local, " + remoteOnly + " apenas na nuvem"
                            return local + " app(s) com dados na nuvem"
                        }
                        opacity: 0.7
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Label {
                        text: "CloudRedirect"
                        font.bold: true
                    }
                    Label {
                        text: (backend && backend.deployed) ? "Instalado" : "Não instalado"
                        opacity: 0.7
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: "Notificações ao iniciar"
                            font.bold: true
                        }
                        Label {
                            text: "Mostrar uma notificação na área de trabalho quando o CloudRedirect carregar"
                            opacity: 0.7
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Switch {
                        checked: backend ? backend.notificationsEnabled : true
                        onToggled: { if (backend) backend.notificationsEnabled = checked }
                    }
                }
            }

            RowLayout {
                Layout.leftMargin: 20
                spacing: 8

                Button {
                    text: "Abrir arquivo de log"
                    onClicked: { if (backend) backend.openLogFile() }
                }

                Button {
                    text: "Abrir pasta de configuração"
                    onClicked: { if (backend) backend.openConfigFolder() }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
