// Spine 4.2 冒烟测试：直接驱动 V42 后端加载指定 .skel，复现崩溃。
#include "spinebackend.h"
#include "spineversion.h"

#include <cstdio>
#include <QVector>
#include <QRectF>

int main(int argc, char **argv)
{
    const char *skelPath = argc > 1 ? argv[1]
                                    : "assets/lunarltk/skel/1Rqaec/hero_zhaoji_lantangchunyan_ren.skel";
    QString skel = QString::fromUtf8(skelPath);
    QString atlas = skel;
    atlas.replace(QStringLiteral(".skel"), QStringLiteral(".atlas"), Qt::CaseInsensitive);

    printf("skel: %s\n", qPrintable(skel));
    printf("atlas: %s\n", qPrintable(atlas));

    SpineBackend *backend = createSpineBackend(SpineVersion::V42);
    if (!backend) {
        printf("FAIL: no V42 backend\n");
        return 1;
    }

    bool ok = backend->load(skel, atlas, 1.0f, QString());
    printf("load=%d\n", (int)ok);
    if (!ok)
        return 2;

    for (int f = 0; f < 10; ++f) {
        backend->update(0.016f);
        QVector<SpineDrawCommand> cmds;
        backend->collectDrawCommands(cmds);
        const QRectF r = backend->bounds();
        printf("frame=%d cmds=%d bounds=(%.1f,%.1f %.1fx%.1f)\n", f, (int)cmds.size(),
               r.x(), r.y(), r.width(), r.height());
        fflush(stdout);
    }

    delete backend;
    printf("OK\n");
    return 0;
}
