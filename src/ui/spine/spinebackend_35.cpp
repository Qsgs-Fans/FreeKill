// Spine 3.5 后端。
#include <spine/spine.h>
#include "spinebackend.h"
#include "texture.h"
#include <QFile>
#include <cfloat>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#define SPINE_PREFIX sp35
#define SPINE_COLOR_STRUCT 0
#define SPINE_REGION_COMPUTE 0
#define SPINE_VERTEX_COMPUTE 0
#define SPINE_LISTENER_V4 1
#define SPINE_HAS_SKELETON_UPDATE 1
#define SPINE_UPDATE_WORLD_PHYSICS 0
#include "spinebackend_hooks.inc"
#include "spinebackend_modern.inc"

SpineBackend *createBackend35() { return new SpineBackendModern(); }
