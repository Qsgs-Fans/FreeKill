#include "diy.h"
#include "git2.h"
#include "util.h"
#include <openssl/rsa.h>
#include <openssl/bn.h>
#include <openssl/pem.h>
#include <qfiledevice.h>

DIYMaker::DIYMaker(QObject *parent) : QObject(parent) {
  git_libgit2_init();
#ifdef Q_OS_ANDROID
  git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif

  if (!QDir("mymod").exists()) {
    QDir(".").mkdir("mymod");
  }

  db = OpenDatabase("mymod/packages.db", "packages/mymod.sql");
}

DIYMaker::~DIYMaker() {
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

void DIYMaker::initSSHKeyPair() {
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

static int fk_cred_cb(git_cred **out, const char *url, const char *name,
    unsigned int allowed_types, void *payload)
{
  DIYMaker::initSSHKeyPair();
  return git_cred_ssh_key_new(out, "git", "mymod/id_rsa.pub", "mymod/id_rsa", "");
}
