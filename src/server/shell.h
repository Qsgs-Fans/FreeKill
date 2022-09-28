#ifndef _SHELL_H
#define _SHELL_H

class Shell: public QThread {
  Q_OBJECT
public:
  Shell();

protected:
  virtual void run();

private:
};

#endif
