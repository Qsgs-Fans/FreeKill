#include <QTest>

class TestQString: public QObject {
  Q_OBJECT
private slots:
  void toUpper();
};

void TestQString::toUpper() {
  QString str = "Hello";
  QCOMPARE(str.toUpper(), QString("HELLO,"));
}

QTEST_MAIN(TestQString)
#include "test.moc"
