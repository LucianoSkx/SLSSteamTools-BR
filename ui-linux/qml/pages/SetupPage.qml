import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    title: "Instalação"

    Dialog {
        id: purgeDialog
        title: "Remover todos os dados"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 480)

        property int countdown: 5
        property bool canPurge: false

        Timer {
            id: purgeCountdownTimer
            interval: 1000
            repeat: true
            onTriggered: {
                purgeDialog.countdown--
                if (purgeDialog.countdown <= 0) {
                    purgeCountdownTimer.stop()
                    purgeDialog.canPurge = true
                }
            }
        }

        onOpened: {
            countdown = 5
            canPurge = false
            purgeCountdownTimer.start()
        }

        onClosed: {
            purgeCountdownTimer.stop()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
                text: "Isto removerá permanentemente:"
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 2
                Layout.leftMargin: 12

                Label { text: "• CloudRedirect da Steam (hook LD_AUDIT)"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Label { text: "• cloud_redirect.so e o binário da CLI"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Label { text: "• Toda a configuração e todos os ajustes"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Label { text: "• OAuth tokens (Google Drive / OneDrive)"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Label { text: "• Todos os saves em cache e os dados da nuvem"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Label { text: "• Logs e backups"; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }

            Label {
                text: "Isto não pode ser desfeito. Você precisará se autenticar e instalar o CloudRedirect de novo para continuar usando."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancelar"
                    onClicked: purgeDialog.close()
                }

                Button {
                    text: purgeDialog.canPurge ? "Remove All Data" : "Remove (" + purgeDialog.countdown + ")"
                    enabled: purgeDialog.canPurge
                    onClicked: {
                        if (deployer) deployer.purgeAll()
                        purgeDialog.close()
                    }
                }
            }
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
                text: "Instalação"
                font.pointSize: 16
                font.bold: true
                Layout.leftMargin: 20
            }

            Label {
                text: "v" + (backend ? backend.version : "")
                Layout.leftMargin: 20
                opacity: 0.7
            }

            Label {
                text: "Instale ou remova o CloudRedirect."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: 0.7
            }

            // SLSsteam status
            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    width: parent.width
                    spacing: 4

                    Label {
                        text: "SLSsteam"
                        font.bold: true
                    }
                    Label {
                        text: deployer && deployer.slssteamInstalled ? "Instalado" : "Não encontrado"
                        opacity: 0.7
                    }
                    Label {
                        visible: deployer && deployer.slssteamInstalled && deployer.slsCloudBlocked
                        text: "O salvamento na nuvem está desativado na sua configuração do SLSsteam!"
                        color: "#e74c3c"
                    }
                    Label {
                        visible: deployer && deployer.slssteamInstalled && deployer.slsCloudBlocked
                        text: "Set DisableCloud: no in ~/.config/SLSsteam/config.yaml"
                        font.family: "monospace"
                        opacity: 0.6
                    }
                }
            }

            // CloudRedirect status
            Frame {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    width: parent.width
                    spacing: 4

                    Label {
                        text: "CloudRedirect"
                        font.bold: true
                    }
                    Label {
                        text: {
                            if (!deployer) return "Desconhecido"
                            if (!deployer.alreadyDeployed) return "Não instalado"
                            if (deployer.updateAvailable) return "Atualização disponível"
                            return "Instalado e atualizado"
                        }
                        opacity: 0.7
                    }
                    Label {
                        visible: deployer && deployer.updateAvailable && deployer.deployedVersion && deployer.bundledVersion
                        text: deployer ? (deployer.deployedVersion + " → " + deployer.bundledVersion) : ""
                        font.family: "monospace"
                        opacity: 0.6
                    }
                }
            }

            // Status message
            Label {
                text: deployer ? deployer.statusMessage : ""
                visible: deployer && deployer.statusMessage !== ""
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: 0.7
            }

            // Action buttons
            RowLayout {
                Layout.leftMargin: 20
                spacing: 8

                Button {
                    text: "Instalar"
                    enabled: deployer && deployer.slssteamInstalled && !deployer.alreadyDeployed
                    highlighted: deployer && deployer.slssteamInstalled && !deployer.alreadyDeployed
                    onClicked: { if (deployer) deployer.deploy() }
                }

                Button {
                    text: "Atualizar"
                    visible: deployer && deployer.updateAvailable
                    highlighted: true
                    onClicked: { if (deployer) deployer.update() }
                }

                Button {
                    text: "Remover"
                    enabled: deployer && deployer.alreadyDeployed
                    onClicked: { if (deployer) deployer.undeploy() }
                }

                Button {
                    text: "Remover todos os dados"
                    onClicked: purgeDialog.open()
                }

                Button {
                    text: "Atualizar"
                    onClicked: { if (deployer) deployer.checkPrerequisites() }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
