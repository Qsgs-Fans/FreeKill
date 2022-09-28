#ifndef _SHELL_H
#define _SHELL_H

class Shell: public QThread {
  Q_OBJECT
public:
  Shell();
  
  enum Color {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
  };
  enum TextType {
    NoType,
    Bold,
    UnderLine
  };
  static const char *ColoredText(const char *input, Color color, TextType type = NoType);

protected:
  virtual void run();

private:
  QHash<QString, void (Shell::*)(QStringList &)> handler_map;
  void helpCommand(QStringList &);
  void quitCommand(QStringList &);
  void lspCommand(QStringList &);
  void lsrCommand(QStringList &);
};

#endif
