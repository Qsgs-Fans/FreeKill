// 按版本创建后端。
#include "spinebackend.h"
#include "spineversion.h"

SpineBackend *createBackend21();
SpineBackend *createBackend34();
SpineBackend *createBackend35();
SpineBackend *createBackend36();
SpineBackend *createBackend37();
SpineBackend *createBackend38();
SpineBackend *createBackend40();
SpineBackend *createBackend41();
SpineBackend *createBackend42();

SpineBackend *createSpineBackend(SpineVersion::Type version) {
    switch (version) {
    case SpineVersion::V21: return createBackend21();
    case SpineVersion::V34: return createBackend34();
    case SpineVersion::V35: return createBackend35();
    case SpineVersion::V36: return createBackend36();
    case SpineVersion::V37: return createBackend37();
    case SpineVersion::V38: return createBackend38();
    case SpineVersion::V40: return createBackend40();
    case SpineVersion::V41: return createBackend41();
    case SpineVersion::V42: return createBackend42();
    default: return nullptr;
    }
}
