#include "qtquick2controlsapplicationviewer.h"
#include "sortfilterproxymodel.h"

#include <QtQml/qqml.h>

int main(int argc, char *argv[])
{
    Application app(argc, argv);

    qmlRegisterType<SortFilterProxyModel>("SortFilterProxyModel", 0, 1, "SortFilterProxyModel");
    QtQuick2ControlsApplicationViewer viewer;
    viewer.setMainQmlFile(QStringLiteral("qml/reminder/main.qml"));
    viewer.show();

    return app.exec();
}
