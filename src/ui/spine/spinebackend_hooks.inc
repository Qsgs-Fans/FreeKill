// 扩展钩子实现（由各版本 .cpp 在定义 SPINE_PREFIX 后包含）。
// 为每个版本提供 _spXXAtlasPage_createTexture / _spXXAtlasPage_disposeTexture / _spXXUtil_readFile。
#ifndef SPINE_CONCAT2
#define SPINE_CONCAT2_INNER(a, b) a##b
#define SPINE_CONCAT2(a, b) SPINE_CONCAT2_INNER(a, b)
#endif

extern "C" {

void SPINE_CONCAT2(SPINE_CONCAT2(_, SPINE_PREFIX), AtlasPage_createTexture)(
        SPINE_CONCAT2(SPINE_PREFIX, AtlasPage) *self, const char *path) {
    Texture *texture = new Texture(QString::fromUtf8(path));
    self->rendererObject = texture;
    self->width = texture->size().width();
    self->height = texture->size().height();
}

void SPINE_CONCAT2(SPINE_CONCAT2(_, SPINE_PREFIX), AtlasPage_disposeTexture)(
        SPINE_CONCAT2(SPINE_PREFIX, AtlasPage) *self) {
    if (self->rendererObject) {
        Texture *texture = (Texture *)self->rendererObject;
        self->rendererObject = nullptr;
        delete texture;
    }
}

char *SPINE_CONCAT2(SPINE_CONCAT2(_, SPINE_PREFIX), Util_readFile)(const char *path, int *length) {
    if (!path || !length)
        return nullptr;
    QFile file(QString::fromUtf8(path));
    if (!file.open(QIODevice::ReadOnly))
        return nullptr;
    const QByteArray data = file.readAll();
    *length = data.size();
    char *bytes = (char *)malloc((size_t)*length);
    if (bytes)
        memcpy(bytes, data.constData(), (size_t)*length);
    return bytes;
}

} // extern "C"
