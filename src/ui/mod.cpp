#include "mod.h"
#include "git2.h"
#include "util.h"
#include <openssl/rsa.h>
#include <openssl/bn.h>
#include <openssl/pem.h>
#include <qfiledevice.h>

ModMaker::ModMaker(QObject *parent) : QObject(parent) {
  git_libgit2_init();
#ifdef Q_OS_ANDROID
  git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif

  if (!QDir("mymod").exists()) {
    QDir(".").mkdir("mymod");
  }

  db = OpenDatabase("mymod/packages.db", "packages/mymod.sql");
}

ModMaker::~ModMaker() {
  // git_libgit2_shutdown();
  sqlite3_close(db);
}

// copied from https://stackoverflow.com/questions/1011572/convert-pem-key-to-ssh-rsa-format
static unsigned char pSshHeader[11] = { 0x00, 0x00, 0x00, 0x07, 0x73, 0x73, 0x68, 0x2D, 0x72, 0x73, 0x61};

static int SshEncodeBuffer(unsigned char *pEncoding, int bufferLen, unsigned char* pBuffer) {
  int adjustedLen = bufferLen, index;
  if (*pBuffer & 0x80) {
    adjustedLen++;
    pEncoding[4] = 0;
    index = 5;
  } else {
    index = 4;
  }

  pEncoding[0] = (unsigned char) (adjustedLen >> 24);
  pEncoding[1] = (unsigned char) (adjustedLen >> 16);
  pEncoding[2] = (unsigned char) (adjustedLen >>  8);
  pEncoding[3] = (unsigned char) (adjustedLen      );
  memcpy(&pEncoding[index], pBuffer, bufferLen);
  return index + bufferLen;
}

static void initSSHKeyPair() {
  if (!QFile::exists("mymod/id_rsa.pub")) {
    RSA *rsa = RSA_new();
    BIGNUM *bne = BN_new();
    BN_set_word(bne, RSA_F4);
    RSA_generate_key_ex(rsa, 3072, bne, NULL);

    BIO *bp_pri = BIO_new_file("mymod/id_rsa", "w");
    PEM_write_bio_RSAPrivateKey(bp_pri, rsa, NULL, NULL, 0, NULL, NULL);
    BIO_free_all(bp_pri);
    QFile("mymod/id_rsa").setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);

    auto n = RSA_get0_n(rsa);
    auto e = RSA_get0_e(rsa);
    auto nLen = BN_num_bytes(n);
    auto eLen = BN_num_bytes(e);
    auto nBytes = (unsigned char *)malloc(nLen);
    auto eBytes = (unsigned char *)malloc(eLen);
    BN_bn2bin(n, nBytes);
    BN_bn2bin(e, eBytes);

    auto encodingLength = 11 + 4 + eLen + 4 + nLen;
    // correct depending on the MSB of e and N
    if (eBytes[0] & 0x80)
      encodingLength++;
    if (nBytes[0] & 0x80)
      encodingLength++;

    auto pEncoding = (unsigned char *)malloc(encodingLength);
    memcpy(pEncoding, pSshHeader, 11);
    int index = 0;
    index = SshEncodeBuffer(&pEncoding[11], eLen, eBytes);
    index = SshEncodeBuffer(&pEncoding[11 + index], nLen, nBytes);

    auto b64 = BIO_new(BIO_f_base64());
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    auto bio = BIO_new_file("mymod/id_rsa.pub", "w");
    BIO_printf(bio, "ssh-rsa ");
    bio = BIO_push(b64, bio);
    BIO_write(bio, pEncoding, encodingLength);
    BIO_flush(bio);
    bio = BIO_pop(b64);
    BIO_printf(bio, " FreeKill\n");
    BIO_flush(bio);

    BIO_free_all(bio);
    BIO_free_all(b64);
    BN_free(bne);
    RSA_free(rsa);
  }
}

void ModMaker::initKey() { initSSHKeyPair(); }

QString ModMaker::readFile(const QString &fileName) {
  QFile conf(fileName);
  if (!conf.exists()) {
    conf.open(QIODevice::WriteOnly);
    static const char *init_conf = "{}";
    conf.write(init_conf);
    conf.close();
    return init_conf;
  }
  conf.open(QIODevice::ReadOnly);
  QString ret = conf.readAll();
  conf.close();
  return ret;
}

void ModMaker::saveToFile(const QString &fName, const QString &content) {
  QFile c(fName);
  c.open(QIODevice::WriteOnly);
  c.write(content.toUtf8());
  c.close();
}

void ModMaker::mkdir(const QString &path) {
  QDir(".").mkdir(path);
}

void ModMaker::rmrf(const QString &path) {
  QDir(path).removeRecursively();
}

void ModMaker::createMod(const QString &name) {
  init(name);
}

void ModMaker::removeMod(const QString &name) {
  QDir("mymod/" + name).removeRecursively();
}

void ModMaker::commitChanges(const QString &name, const QString &msg,
    const QString &user, const QString &email)
{
  auto userBytes = user.toUtf8();
  auto emailBytes = email.toUtf8();
  commit(name, msg, userBytes, emailBytes);
}

#define GIT_FAIL                                                               \
  const git_error *e = git_error_last();                                       \
  qCritical("Error %d/%d: %s\n", error, e->klass, e->message)

#define GIT_CHK(s) do { \
  error = (s); \
  if (error < 0) { \
    GIT_FAIL; \
    goto clean; \
  }} while (0)

static int fk_cred_cb(git_cred **out, const char *url, const char *name,
    unsigned int allowed_types, void *payload)
{
  initSSHKeyPair();
  return git_cred_ssh_key_new(out, "git", "mymod/id_rsa.pub", "mymod/id_rsa", "");
}

int ModMaker::init(const QString &pkg) {
  QString path = "mymod/" + pkg;
  int error;
  git_repository *repo = NULL;
  git_repository_init_options opts = GIT_REPOSITORY_INIT_OPTIONS_INIT;
  opts.flags |= GIT_REPOSITORY_INIT_MKPATH; /* mkdir as needed to create repo */
  error = git_repository_init_ext(&repo, path.toLatin1().constData(), &opts);
  if (error < 0) {
    GIT_FAIL;
  }
  git_repository_free(repo);
  return error;
}

int ModMaker::add(const QString &pkg) {
  QString path = "mymod/" + pkg;
  int error;
  git_repository *repo = NULL;
  git_index *index = NULL;

  GIT_CHK(git_repository_open(&repo, path.toLatin1()));
  GIT_CHK(git_repository_index(&index, repo));
  GIT_CHK(git_index_add_all(index, NULL, GIT_INDEX_ADD_DEFAULT, NULL, NULL));
  GIT_CHK(git_index_write(index));

clean:
  git_repository_free(repo);
  git_index_free(index);
  return error;
}

int ModMaker::commit(const QString &pkg, const QString &msg, const char *user, const char *email) {
  QString path = "mymod/" + pkg;
  int error;
  git_repository *repo = NULL;
  git_oid commit_oid,tree_oid;
  git_tree *tree;
  git_index *index;
  git_object *parent = NULL;
  git_reference *ref = NULL;
  git_signature *signature;

  GIT_CHK(git_repository_open(&repo, path.toLatin1()));
  error = git_revparse_ext(&parent, &ref, repo, "HEAD");
  if (error == GIT_ENOTFOUND) {
    // printf("HEAD not found. Creating first commit\n");
    error = 0;
  } else if (error != 0) {
    GIT_FAIL;
    goto clean;
  }

  GIT_CHK(git_repository_index(&index, repo));
  GIT_CHK(git_index_write_tree(&tree_oid, index));
  GIT_CHK(git_index_write(index));
  GIT_CHK(git_tree_lookup(&tree, repo, &tree_oid));
  GIT_CHK(git_signature_now(&signature, user, email));
  GIT_CHK(git_commit_create_v(
        &commit_oid,
        repo,
        "HEAD",
        signature,
        signature,
        NULL,
        msg.toUtf8(),
        tree,
        parent ? 1 : 0, parent));

clean:
  git_repository_free(repo);
  git_index_free(index);
  git_signature_free(signature);
  git_tree_free(tree);
  git_object_free(parent);
  git_reference_free(ref);
  return error;
}
