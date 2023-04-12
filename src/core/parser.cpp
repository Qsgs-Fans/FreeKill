// SPDX-License-Identifier: GPL-3.0-or-later

#include "parser.h"

static Parser *p = nullptr;

Parser::Parser() { parser = fkp_new_parser(); }

Parser::~Parser() { fkp_close(parser); }

int Parser::parse(const QString &fileName) {
  if (!QFile::exists(fileName)) {
    return 1;
  }
  QString cwd = QDir::currentPath();

  QStringList strlist = fileName.split('/');
  QString shortFileName = strlist.last();
  strlist.removeLast();
  QString path = strlist.join('/');
  QDir::setCurrent(path);

  auto fnamebytes = shortFileName.toUtf8();

  bool error = fkp_parse(parser, fnamebytes.constData(), FKP_FK_LUA);

  if (error) {
    QStringList tmplist = shortFileName.split('.');
    tmplist.removeLast();
    QString fName = tmplist.join('.') + "-error.txt";
    if (!QFile::exists(fName)) {
      qCritical("FKP parse error: Unknown error.");
    } else {
      QFile f(fName);
      f.open(QIODevice::ReadOnly);
      qCritical() << "FKP parse error:\n" << f.readAll().constData();
      f.remove();
    }
  }

  QDir::setCurrent(cwd);
  return error;
}

static QStringList findFile(const QString &path, const QString &filename) {
  QStringList ret;
  if (path.isEmpty() || filename.isEmpty()) {
    return ret;
  }

  QDir dir;
  QStringList filters;

  filters << filename;
  dir.setPath(path);
  dir.setNameFilters(filters);
  QDirIterator iter(dir, QDirIterator::Subdirectories);

  while (iter.hasNext()) {
    iter.next();
    auto info = iter.fileInfo();
    if (info.isFile()) {
      ret.append(info.absoluteFilePath());
    } else if (info.isDir()) {
      ret.append(findFile(path, filename));
    }
  }

  return ret;
}

void Parser::parseFkp() {
  if (!p) {
    p = new Parser;
  }

  foreach (QString s, findFile("./packages", "*.fkp")) {
    p->parse(s);
  }
}

#ifndef Q_OS_WASM
static void copyFkpHash2QHash(QHash<QString, QString> &dst, fkp_hash *from) {
  dst.clear();
  for (size_t i = 0; i < from->capacity; i++) {
    if (from->entries[i].key != NULL) {
      dst[from->entries[i].key] = QString((const char *)from->entries[i].value);
    }
  }
}

void Parser::readHashFromParser() {
  copyFkpHash2QHash(generals, parser->generals);
  copyFkpHash2QHash(skills, parser->skills);
  copyFkpHash2QHash(marks, parser->marks);
}
#endif
