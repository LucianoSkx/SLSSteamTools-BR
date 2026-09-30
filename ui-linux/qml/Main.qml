import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"

ApplicationWindow {
    id: root
    width: 720
    height: 620
    minimumWidth: 600
    minimumHeight: 500
    title: "CloudRedirect"
    visible: true

    // Navigate to Setup tab after deploy/undeploy actions if needed
    Connections {
        target: deployer
        function onCheckCompleted() {
            if (deployer && (!deployer.alreadyDeployed || deployer.updateAvailable)) {
                tabBar.currentIndex = 4  // Setup tab
            }
        }
    }

    // Auto-update prompt on first launch + initial setup navigation
    Component.onCompleted: {
        if (deployer && (!deployer.alreadyDeployed || deployer.updateAvailable)) {
            tabBar.currentIndex = 4
        }
        if (backend && backend.shouldOfferAutoUpdates()) {
            autoUpdateDialog.open()
        } else if (backend) {
            backend.checkForFlatpakUpdate()
        }
    }

    Connections {
        target: backend
        function onFlatpakUpdateAvailable() {
            updateAvailableDialog.open()
        }
        function onFlatpakUpdateCompleted(success) {
            if (success) {
                restartDialog.open()
            }
        }
    }

    Dialog {
        id: updateAvailableDialog
        title: "Atualização disponível"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 440)

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
                text: "Uma nova versão do CloudRedirect está disponível."
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: "Atualize agora para obter as novidades e as correções mais recentes."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: "Mais tarde"
                    onClicked: updateAvailableDialog.close()
                }

                Button {
                    text: "Atualizar agora"
                    highlighted: true
                    onClicked: {
                        if (backend) backend.applyFlatpakUpdate()
                        updateAvailableDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: restartDialog
        title: "Reinício necessário"
        modal: true
        standardButtons: Dialog.Ok
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 440)

        Label {
            text: "O CloudRedirect foi atualizado. Reinicie o aplicativo para usar a nova versão."
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Dialog {
        id: autoUpdateDialog
        title: "Ativar atualizações automáticas"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 440)

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
                text: "Deseja receber atualizações automáticas?"
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: "O CloudRedirect pode adicionar o repositório de atualizações para que novas versões sejam instaladas automaticamente via Flatpak. Você pode removê-lo depois nas Configurações."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: "Agora não"
                    onClicked: {
                        if (backend) backend.dismissAutoUpdatePrompt()
                        autoUpdateDialog.close()
                    }
                }

                Button {
                    text: "Ativar atualizações"
                    highlighted: true
                    onClicked: {
                        if (backend) backend.enableAutoUpdates()
                        autoUpdateDialog.close()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            // Size each tab to its label so wider labels aren't truncated.
            TabButton { text: "Painel";        width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Aplicativos";   width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Backups";        width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Provedor";      width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Instalação";    width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Estatísticas";  width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
            TabButton { text: "Migração";      width: Math.max(implicitWidth, contentItem.implicitWidth + 24) }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            DashboardPage {}
            AppsPage {}
            BackupsPage {}
            CloudProviderPage {}
            SetupPage {}
            StatsPage {}
            MigrationPage {}
        }
    }
}
