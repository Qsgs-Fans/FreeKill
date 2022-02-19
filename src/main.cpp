#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "qmlbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine(QUrl(QStringLiteral("qml/main.qml")));
    QmlBackend backend;
    engine.rootContext()->setContextProperty("Backend", &backend);

    return app.exec();
}
