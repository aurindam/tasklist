import QtQuick 2.1
import QtQuick.Window 2.1
import QtQuick.Controls 1.1
import QtQuick.XmlListModel 2.0
import QtQuick.LocalStorage 2.0
import Enginio 1.0

Window {
    visible: true
    width: 900
    height: 360

    property var locale: Qt.locale()
    property string dbName: "Pipeline"

    ToolBar {
        id: toolbar
        width: parent.width

        Column {
            Row {
                spacing: 10
                Button {
                    text: "Save"
                    activeFocusOnPress: true
                    onClicked: saveData()
                }
                Button {
                    id: syncButton
                    enabled: false
                    text: "Sync"
                    activeFocusOnPress: true
                    onClicked: syncData()
                }
                Button {
                    text: "Add"
                    activeFocusOnPress: true
                    onClicked: {
                        var today = new Date();
                        var followup = new Date();
                        followup.setDate(followup.getDate() + 6);
                        dataModel.append({"company": "Name", "status": "E/M/Q", "revenue": 0, "lastdate": toDateString(today), "followupdate": toDateString(followup), "comments": ""});
                    }
                }
                Button {
                    text: "Delete"
                    onClicked: {
                        var company = dataModel.get(tableView.currentRow).company;
                        removeData(company);
                        dataModel.remove(tableView.currentRow)
                        saveData();
                    }
                }
                Text {
                    id: syncStatus
                    color: "lightblue"
                }
            }
            Row {
                spacing: 15
                Text {
                    id: revenueText
                    color: "red"
                }
                Text {
                    id: q1revenueText
                    color: "blue"
                }
                Text {
                    id: q2revenueText
                    color: "green"
                }
                Text {
                    id: q3revenueText
                    color: "brown"
                }
                Text {
                    id: q4revenueText
                    color: "purple"
                }
            }
        }
    }

    SystemPalette {id: syspal}
    color: syspal.window

    ListModel {
        id: dataModel
    }

    Component {
        id: editableDelegate
        Item {
            Text {
                width: parent.width
                anchors.margins: 4
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                elide: styleData.elideMode
                text: styleData.value !== undefined ? styleData.value : ""
                color: {
                    if (styleData.role === "followupdate" && isPending(styleData.value)) {
                        return "red"
                    } else {
                        return styleData.textColor
                    }
                }
                visible: !styleData.selected
            }
            Loader { // Initialize text editor lazily to improve performance
                id: loaderEditor
                anchors.fill: parent
                anchors.margins: 4
                Connections {
                    target: loaderEditor.item
                    onEditingFinished: {
                        if (typeof styleData.value === 'number') {
                            model.setProperty(styleData.row, styleData.role, Number(parseFloat(loaderEditor.item.text).toFixed(0)))
                            if (styleData.role === "revenue")
                                updateRevenue()
                        } else {
                            if (styleData.role === "lastdate" && (styleData.value !== '' || styleData.value !== undefined)) {
                                var fwd = fromDateString(loaderEditor.item.text)
                                fwd.setDate(fwd.getDate() + 6)
                                model.setProperty(styleData.row, "followupdate", toDateString(fwd))
                            }
                            model.setProperty(styleData.row, styleData.role, loaderEditor.item.text)
                        }
                    }
                }
                sourceComponent: styleData.selected ? editor : null
                Component {
                    id: editor
                    TextInput {
                        id: textinput
                        color: styleData.textColor
                        text: styleData.value
                        wrapMode: TextInput.WordWrap
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: textinput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }
    TableView {
        id: tableView
        model: dataModel
        anchors.margins: 12
        anchors.top:toolbar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        frameVisible: true
        headerVisible: true
        sortIndicatorVisible: true
        alternatingRowColors: true

        TableViewColumn {
            role: "company"
            title: "Company"
            width: 120
        }
        TableViewColumn {
            role: "revenue"
            title: "Revenue"
            width: 120
        }
        TableViewColumn {
            role: "lastdate"
            title: "Last Contact"
            width: 120
        }
        TableViewColumn {
            role: "followupdate"
            title: "Follow-up Date"
            width: 120
        }
        TableViewColumn {
            role: "comments"
            title: "Comments"
            width: 350
        }
        TableViewColumn {
            role: "status"
            title: "Status"
            width: 120
        }
        itemDelegate: editableDelegate

        //        onSortIndicatorColumnChanged: console.log(tableView.sortIndicatorColumn)
    }


    function updateRevenue() {
        var totRevenue = 0;
        var q1r = 0;
        var q2r = 0;
        var q3r = 0;
        var q4r = 0;
        var entries = dataModel.count
        for (var i = 0; i < entries; i++) {
            var revenue = dataModel.get(i).revenue;
            totRevenue += revenue;
            var fwd = fromDateString(dataModel.get(i).followupdate)
            var month = fwd.getMonth();
            if (month >=0 && month <=2)
                q1r += revenue;
            else if (month >=3 && month <=5)
                q2r += revenue;
            else if (month >=6 && month <=8)
                q3r += revenue;
            else
                q4r += revenue
        }
        revenueText.text = "Total: EUR " + totRevenue
        q1revenueText.text = "Q1: EUR " + q1r
        q2revenueText.text = "Q2: EUR " + q2r
        q3revenueText.text = "Q3: EUR " + q3r
        q4revenueText.text = "Q4: EUR " + q4r
    }

    function saveData() {
        var db = LocalStorage.openDatabaseSync(dbName, "1.0", "Prospects Follow-up DB!", 1000000);


        db.transaction(
                    function(tx) {
                        var entries = dataModel.count
                        for(var i = 0; i < entries; i++) {
                            var company = dataModel.get(i).company;
                            var status = dataModel.get(i).status;
                            var revenue = dataModel.get(i).revenue;
                            var lastdate = fromDateString(dataModel.get(i).lastdate).getTime();
                            var followupdate = fromDateString(dataModel.get(i).followupdate).getTime();
                            var comments = dataModel.get(i).comments;
                            var rs = tx.executeSql('SELECT status, revenue, lastdate, followupdate, comments FROM prospects WHERE company=\"' + company + '\"');
                            var now = new Date()
                            if (rs.rows.length !== 0 && (rs.rows.item(0).revenue !== revenue || rs.rows.item(0).status !== status || rs.rows.item(0).lastdate !== lastdate || rs.rows.item(0).followupdate !== followupdate || rs.rows.item(0).comments !== comments))
                                tx.executeSql('REPLACE INTO PROSPECTS (company, status, revenue, lastdate, followupdate, lastmodifieddate, comments) VALUES (\"' + company + '\", \"' + status + '\", \"' + revenue + '\", \"' + lastdate + '\", \"' + followupdate + '\", \"' + now.getTime() + '\", \"' + comments + '\")');
                            else if (rs.rows.length === 0)
                                tx.executeSql('REPLACE INTO PROSPECTS (company, status, revenue, lastdate, followupdate, lastmodifieddate, comments) VALUES (\"' + company + '\", \"' + status + '\", \"' + revenue + '\", \"' + lastdate + '\", \"' + followupdate + '\", \"' + now.getTime() + '\", \"' + comments + '\")');
                        }
                    }
                    )
        updateRevenue()
    }

    function loadData() {
        initDb();
        var db = LocalStorage.openDatabaseSync(dbName, "1.0", "Prospects Follow-up DB!", 1000000);

        db.transaction(
                    function(tx) {
                        var rs = tx.executeSql('SELECT company, status, revenue, lastdate, followupdate, comments FROM prospects');

                        for(var i = 0; i < rs.rows.length; i++) {
                            var ld = new Date(rs.rows.item(i).lastdate)
                            var fwd = new Date(rs.rows.item(i).followupdate)
                            dataModel.append({"company": rs.rows.item(i).company, "status": rs.rows.item(i).status, "revenue": rs.rows.item(i).revenue, "lastdate": toDateString(ld), "followupdate": toDateString(fwd), "comments": rs.rows.item(i).comments})
                        }
                    }
                    )
        updateRevenue()
    }

    function removeData(company) {
        initDb();
        var db = LocalStorage.openDatabaseSync(dbName, "1.0", "Prospects Follow-up DB!", 1000000);

        db.transaction(
                    function(tx) {
                        var rs = tx.executeSql('DELETE FROM prospects WHERE company=\"' + company + '\"');
                    }
                    )
    }

    function initDb() {
        var db = LocalStorage.openDatabaseSync(dbName, "1.0", "Prospects Follow-up DB!", 1000000);

        db.transaction(
                    function(tx) {
                        // Create the database if it doesn't already exist
                        tx.executeSql('CREATE TABLE IF NOT EXISTS PROSPECTS (company TEXT PRIMARY KEY, status TEXT, revenue INTEGER, lastdate REAL, followupdate REAL, lastmodifieddate REAL, comments TEXT)');
                    }
                    )
    }

    function syncData() {
//        var entries = enginioModel.count
//        for(var i = 0; i < entries; i++) {
//            var company = enginioModel.get(i).company;
//            var status = enginioModel.get(i).status;
//            var revenue = enginioModel.get(i).revenue;
//            var lastdate = fromDateString(enginioModel.get(i).lastdate).getTime();
//            var followupdate = fromDateString(enginioModel.get(i).followupdate).getTime();
//            var comments = enginioModel.get(i).comments;
//        }
    }

    function toDateString(date) {
        return date.toLocaleDateString(locale, "dd/MM/yyyy")
    }

    function fromDateString(dateString) {
        return Date.fromLocaleDateString(locale, dateString, "dd/MM/yyyy")
    }

    function isPending(dateString) {
        var date = fromDateString(dateString)
        var today = new Date()
        if (date <= today)
            return true;
        return false
    }

    Timer {
        id: timer
        interval: 5 * 50 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: saveData()
    }

//    EnginioClient {
//        id: client
//        backendId: {"53591c5c698b3c45a500048c"} // copy/paste your EDS instance backend id here
//        onFinished: syncStatus.text = ""
//        onError: syncStatus.text = JSON.stringify(reply.data)
//        Component.onCompleted: syncButton.enabled = true
//    }

//    EnginioModel {
//        id: enginioModel
//        client: client
//        query: {"objectType": "objects.pipeline"
//        }
//    }

    Component.onCompleted: loadData();
    Component.onDestruction: saveData();
}
