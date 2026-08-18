/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
 * "Products"), provided that each user of the Products must obtain their own
 * Spine Editor license and redistribution of the Products in any form must
 * include this license and copyright notice.
 *
 * THE SPINE RUNTIMES ARE PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES,
 * BUSINESS INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Animation.h>
#include <spine/Debug.h>

#include <stdio.h>

static const char *_sp42TimelineTypeNames[] = {
		"Attachment",
		"Alpha",
		"PathConstraintPosition",
		"PathConstraintSpace",
		"Rotate",
		"ScaleX",
		"ScaleY",
		"ShearX",
		"ShearY",
		"TranslateX",
		"TranslateY",
		"Scale",
		"Shear",
		"Translate",
		"Deform",
		"IkConstraint",
		"PathConstraintMix",
		"Rgb2",
		"Rgba2",
		"Rgba",
		"Rgb",
		"TransformConstraint",
		"DrawOrder",
		"Event"};

void sp42Debug_printSkeletonData(sp42SkeletonData *skeletonData) {
	int i, n;
	sp42Debug_printBoneDatas(skeletonData->bones, skeletonData->bonesCount);

	for (i = 0, n = skeletonData->animationsCount; i < n; i++) {
		sp42Debug_printAnimation(skeletonData->animations[i]);
	}
}

void _sp42Debug_printTimelineBase(sp42Timeline *timeline) {
	printf("   Timeline %s:\n", _sp42TimelineTypeNames[timeline->type]);
	printf("      frame count: %i\n", timeline->frameCount);
	printf("      frame entries: %i\n", timeline->frameEntries);
	printf("      frames: ");
	sp42Debug_printFloats(timeline->frames->items, timeline->frames->size);
	printf("\n");
}

void _sp42Debug_printCurveTimeline(sp42CurveTimeline *timeline) {
	_sp42Debug_printTimelineBase(&timeline->super);
	printf("      curves: ");
	sp42Debug_printFloats(timeline->curves->items, timeline->curves->size);
	printf("\n");
}

void sp42Debug_printTimeline(sp42Timeline *timeline) {
	switch (timeline->type) {
		case SP_TIMELINE_ATTACHMENT: {
			sp42AttachmentTimeline *t = (sp42AttachmentTimeline *) timeline;
			_sp42Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_ALPHA: {
			sp42AlphaTimeline *t = (sp42AlphaTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTPOSITION: {
			sp42PathConstraintPositionTimeline *t = (sp42PathConstraintPositionTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTSPACING: {
			sp42PathConstraintMixTimeline *t = (sp42PathConstraintMixTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_ROTATE: {
			sp42RotateTimeline *t = (sp42RotateTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEX: {
			sp42ScaleXTimeline *t = (sp42ScaleXTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEY: {
			sp42ScaleYTimeline *t = (sp42ScaleYTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARX: {
			sp42ShearXTimeline *t = (sp42ShearXTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARY: {
			sp42ShearYTimeline *t = (sp42ShearYTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEX: {
			sp42TranslateXTimeline *t = (sp42TranslateXTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEY: {
			sp42TranslateYTimeline *t = (sp42TranslateYTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALE: {
			sp42ScaleTimeline *t = (sp42ScaleTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEAR: {
			sp42ShearTimeline *t = (sp42ShearTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATE: {
			sp42TranslateTimeline *t = (sp42TranslateTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DEFORM: {
			sp42DeformTimeline *t = (sp42DeformTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_IKCONSTRAINT: {
			sp42IkConstraintTimeline *t = (sp42IkConstraintTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTMIX: {
			sp42PathConstraintMixTimeline *t = (sp42PathConstraintMixTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB2: {
			sp42RGB2Timeline *t = (sp42RGB2Timeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA2: {
			sp42RGBA2Timeline *t = (sp42RGBA2Timeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA: {
			sp42RGBATimeline *t = (sp42RGBATimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB: {
			sp42RGBTimeline *t = (sp42RGBTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSFORMCONSTRAINT: {
			sp42TransformConstraintTimeline *t = (sp42TransformConstraintTimeline *) timeline;
			_sp42Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DRAWORDER: {
			sp42DrawOrderTimeline *t = (sp42DrawOrderTimeline *) timeline;
			_sp42Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_EVENT: {
			sp42EventTimeline *t = (sp42EventTimeline *) timeline;
			_sp42Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_SEQUENCE: {
			sp42SequenceTimeline *t = (sp42SequenceTimeline *) timeline;
			_sp42Debug_printTimelineBase(&t->super);
		}
		case SP_TIMELINE_INHERIT: {
			sp42InheritTimeline *t = (sp42InheritTimeline *) timeline;
			_sp42Debug_printTimelineBase(&t->super);
		}
		default: {
			_sp42Debug_printTimelineBase(timeline);
		}
	}
}

void sp42Debug_printAnimation(sp42Animation *animation) {
	int i, n;
	printf("Animation %s: %i timelines\n", animation->name, animation->timelines->size);

	for (i = 0, n = animation->timelines->size; i < n; i++) {
		sp42Debug_printTimeline(animation->timelines->items[i]);
	}
}

void sp42Debug_printBoneDatas(sp42BoneData **boneDatas, int numBoneDatas) {
	int i;
	for (i = 0; i < numBoneDatas; i++) {
		sp42Debug_printBoneData(boneDatas[i]);
	}
}

void sp42Debug_printBoneData(sp42BoneData *boneData) {
	printf("Bone data %s: %f, %f, %f, %f, %f, %f %f\n", boneData->name, boneData->rotation, boneData->scaleX,
		   boneData->scaleY, boneData->x, boneData->y, boneData->shearX, boneData->shearY);
}

void sp42Debug_printSkeleton(sp42Skeleton *skeleton) {
	sp42Debug_printBones(skeleton->bones, skeleton->bonesCount);
}

void sp42Debug_printBones(sp42Bone **bones, int numBones) {
	int i;
	for (i = 0; i < numBones; i++) {
		sp42Debug_printBone(bones[i]);
	}
}

void sp42Debug_printBone(sp42Bone *bone) {
	printf("Bone %s: %f, %f, %f, %f, %f, %f\n", bone->data->name, bone->a, bone->b, bone->c, bone->d, bone->worldX,
		   bone->worldY);
}

void sp42Debug_printFloats(float *values, int numFloats) {
	int i;
	printf("(%i) [", numFloats);
	for (i = 0; i < numFloats; i++) {
		printf("%f, ", values[i]);
	}
	printf("]");
}
