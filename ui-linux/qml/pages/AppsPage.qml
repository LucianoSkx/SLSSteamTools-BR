import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    title: "Aplicativos"

    property var appsList: []
    property var filteredLocalApps: []
    property var filteredRemoteApps: []
    property string searchText: ""
    property string statusText: ""

    Component.onCompleted: {
        reloadApps()
        if (backend) backend.fetchRemoteApps()
    }

    function reloadApps() {
        appsList = backend ? backend.getAppDetails() : []
        updateFilteredLists()
    }

    function updateFilteredLists() {
        var localCount = 0
        var remoteCount = 0
        var localResult = []
        var remoteResult = []
        var needle = searchText.toLowerCase()

        for (var i = 0; i < appsList.length; i++) {
            var app = appsList[i]
            var matches = (needle === "") ||
                          String(app.appId).indexOf(needle) >= 0 ||
                          app.name.toLowerCase().indexOf(needle) >= 0

            if (app.isLocal) {
                localCount++
                if (matches) localResult.push(app)
            }
            if (app.isRemote && !app.isLocal) {
                remoteCount++
                if (matches) remoteResult.push(app)
            }
        }

        localResult.sort(function(a, b) { return a.appId - b.appId })
        remoteResult.sort(function(a, b) { return a.appId - b.appId })

        filteredLocalApps = localResult
        filteredRemoteApps = remoteResult
        statusText = localCount + " local, " + remoteCount + " na nuvem"
    }

    onSearchTextChanged: updateFilteredLists()

    function formatProviderName(name) {
        if (backend) return backend.providerLabel(name)
        return name
    }

    Connections {
        target: backend
        function onAppNamesResolved() {
            reloadApps()
        }
        function onAppsChanged() {
            reloadApps()
        }
        function onRemoteAppsFetched() {
            reloadApps()
        }
    }

    Dialog {
        id: deleteDialog
        title: "Excluir dados do aplicativo"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 480)

        property var targetApp: null
        property int countdown: 5
        property bool canDelete: false

        Timer {
            id: countdownTimer
            interval: 1000
            repeat: true
            onTriggered: {
                deleteDialog.countdown--
                if (deleteDialog.countdown <= 0) {
                    countdownTimer.stop()
                    deleteDialog.canDelete = true
                }
            }
        }

        onOpened: {
            countdown = 5
            canDelete = false
            countdownTimer.start()
        }

        onClosed: {
            countdownTimer.stop()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
                text: "Excluir todos os saves de '" + (deleteDialog.targetApp ? deleteDialog.targetApp.name : "") + "' (" + (deleteDialog.targetApp ? deleteDialog.targetApp.appId : "") + ")"
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: "Isto excluirá permanentemente:"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 2
                Layout.leftMargin: 12

                Label {
                    text: "• " + (deleteDialog.targetApp ? deleteDialog.targetApp.fileCount : "") + " arquivo(s) (" + (deleteDialog.targetApp ? deleteDialog.targetApp.sizeFormatted : "") + ") do armazenamento local do CloudRedirect"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: 0.8
                }

                Label {
                    text: "• Diretório userdata da Steam deste aplicativo"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: 0.8
                }
            }

            Label {
                text: {
                    var provider = backend ? backend.providerName : "local"
                    if (provider === "gdrive" || provider === "onedrive" || provider === "r2")
                        return "A cópia na nuvem em " + formatProviderName(provider) + " também será excluída."
                    return ""
                }
                visible: text !== ""
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.7
            }

            Label {
                text: "Os dados serão baixados novamente da nuvem no próximo início do jogo. Um backup será criado antes da exclusão."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.7
            }

            Label {
                text: "Isto não pode ser desfeito."
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancelar"
                    onClicked: deleteDialog.close()
                }

                Button {
                    text: deleteDialog.canDelete ? "Excluir todos os saves" : "Excluir (" + deleteDialog.countdown + ")"
                    enabled: deleteDialog.canDelete
                    onClicked: {
                        if (backend && deleteDialog.targetApp) {
                            backend.deleteAppData(deleteDialog.targetApp.appId)
                        }
                        deleteDialog.close()
                        reloadApps()
                    }
                }
            }
        }
    }

    // Orphan results dialog
    Dialog {
        id: orphanDialog
        title: "Resultado da varredura de órfãos"
        modal: true
        standardButtons: Dialog.Ok
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 480)

        property var results: []

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Label {
                text: orphanDialog.results.length === 0
                      ? "Nenhum blob órfão encontrado. O armazenamento está limpo."
                      : orphanDialog.results.length + " app(s) com blobs órfãos:"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: orphanDialog.results

                Frame {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 2

                        Label {
                            text: modelData.name + " (" + modelData.appId + ")"
                            font.bold: true
                        }
                        Label {
                            text: modelData.orphanCount + " arquivo(s) órfão(s), " + modelData.orphanSizeFormatted
                            opacity: 0.7
                        }
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
                text: "Aplicativos"
                font.pointSize: 16
                font.bold: true
                Layout.leftMargin: 20
            }

            Label {
                text: "Saves na nuvem gerenciados pelo CloudRedirect. Busque pelo nome ou pelo App ID."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 8

                TextField {
                    id: searchField
                    placeholderText: "Buscar pelo nome ou pelo App ID..."
                    Layout.fillWidth: true
                    onTextChanged: searchText = text
                }

                Button {
                    text: "Varrer órfãos"
                    onClicked: {
                        var results = backend ? backend.scanOrphans() : []
                        orphanDialog.results = results
                        orphanDialog.open()
                    }
                }

                Button {
                    text: "Atualizar"
                    onClicked: {
                        if (backend) {
                            backend.refreshStatus()
                            backend.fetchRemoteApps()
                        }
                        reloadApps()
                    }
                }
            }

            // Local Saves section
            Label {
                text: "Saves locais"
                font.pointSize: 13
                font.bold: true
                Layout.leftMargin: 20
                Layout.topMargin: 8
            }

            Repeater {
                model: filteredLocalApps

                Frame {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Image {
                            source: modelData.headerUrl
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 56
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                visible: parent.status !== Image.Ready
                                radius: 2

                                Label {
                                    anchors.centerIn: parent
                                    text: String(modelData.appId)
                                    opacity: 0.4
                                    font.pointSize: 9
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 450
                            spacing: 4
                            Label {
                                text: modelData.name
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: "ID: " + modelData.appId + "  •  " + modelData.fileCount + " arquivo(s)  •  " + modelData.sizeFormatted + (modelData.saveRoot ? "  •  " + modelData.saveRoot : "")
                                opacity: 0.7
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            icon.name: "edit-delete"
                            text: "Excluir"
                            display: AbstractButton.TextBesideIcon
                            onClicked: {
                                deleteDialog.targetApp = modelData
                                deleteDialog.open()
                            }
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: filteredLocalApps.length === 0 && searchText === ""
                text: "Nenhum save local encontrado."
                opacity: 0.5
            }

            Label {
                text: "Saves remotos"
                font.pointSize: 13
                font.bold: true
                Layout.leftMargin: 20
                Layout.topMargin: 8
                visible: filteredRemoteApps.length > 0
            }

            Label {
                text: "Apps com dados de save no armazenamento em nuvem que ainda não foram baixados localmente."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                opacity: 0.7
                visible: filteredRemoteApps.length > 0
            }

            Repeater {
                model: filteredRemoteApps

                Frame {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20

                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Image {
                            source: modelData.headerUrl
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 56
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                visible: parent.status !== Image.Ready
                                radius: 2

                                Label {
                                    anchors.centerIn: parent
                                    text: String(modelData.appId)
                                    opacity: 0.4
                                    font.pointSize: 9
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 450
                            spacing: 4
                            Label {
                                text: modelData.name
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: "ID: " + modelData.appId + "  •  Conta: " + (backend ? backend.accountName : "Desconhecido")
                                opacity: 0.7
                            }
                            Label {
                                text: "Não baixado localmente  •  Será baixado no próximo início do jogo"
                                opacity: 0.5
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: filteredRemoteApps.length === 0 && searchText === ""
                text: "Nenhum save apenas na nuvem encontrado."
                opacity: 0.5
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
                visible: appsList.length === 0
                text: "Nenhum app encontrado.\n\nInstale jogos pelo SLSsteam para vê-los aqui."
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.5
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
                visible: appsList.length > 0 && filteredLocalApps.length === 0 && filteredRemoteApps.length === 0 && searchText !== ""
                text: "Nenhum app corresponde a \"" + searchText + "\""
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.5
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                Label {
                    text: statusText
                    opacity: 0.6
                }
                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
