/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software
 * or otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THE SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Animation.h>
#include <spine/Debug.h>

#include <stdio.h>

static const char *_sp40TimelineTypeNames[] = {
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

void sp40Debug_printSkeletonData(sp40SkeletonData *skeletonData) {
	int i, n;
	sp40Debug_printBoneDatas(skeletonData->bones, skeletonData->bonesCount);

	for (i = 0, n = skeletonData->animationsCount; i < n; i++) {
		sp40Debug_printAnimation(skeletonData->animations[i]);
	}
}

void _sp40Debug_printTimelineBase(sp40Timeline *timeline) {
	printf("   Timeline %s:\n", _sp40TimelineTypeNames[timeline->type]);
	printf("      frame count: %i\n", timeline->frameCount);
	printf("      frame entries: %i\n", timeline->frameEntries);
	printf("      frames: ");
	sp40Debug_printFloats(timeline->frames->items, timeline->frames->size);
	printf("\n");
}

void _sp40Debug_printCurveTimeline(sp40CurveTimeline *timeline) {
	_sp40Debug_printTimelineBase(&timeline->super);
	printf("      curves: ");
	sp40Debug_printFloats(timeline->curves->items, timeline->curves->size);
	printf("\n");
}

void sp40Debug_printTimeline(sp40Timeline *timeline) {
	switch (timeline->type) {
		case SP_TIMELINE_ATTACHMENT: {
			sp40AttachmentTimeline *t = (sp40AttachmentTimeline *) timeline;
			_sp40Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_ALPHA: {
			sp40AlphaTimeline *t = (sp40AlphaTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTPOSITION: {
			sp40PathConstraintPositionTimeline *t = (sp40PathConstraintPositionTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTSPACING: {
			sp40PathConstraintMixTimeline *t = (sp40PathConstraintMixTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_ROTATE: {
			sp40RotateTimeline *t = (sp40RotateTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEX: {
			sp40ScaleXTimeline *t = (sp40ScaleXTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEY: {
			sp40ScaleYTimeline *t = (sp40ScaleYTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARX: {
			sp40ShearXTimeline *t = (sp40ShearXTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARY: {
			sp40ShearYTimeline *t = (sp40ShearYTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEX: {
			sp40TranslateXTimeline *t = (sp40TranslateXTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEY: {
			sp40TranslateYTimeline *t = (sp40TranslateYTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALE: {
			sp40ScaleTimeline *t = (sp40ScaleTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEAR: {
			sp40ShearTimeline *t = (sp40ShearTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATE: {
			sp40TranslateTimeline *t = (sp40TranslateTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DEFORM: {
			sp40DeformTimeline *t = (sp40DeformTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_IKCONSTRAINT: {
			sp40IkConstraintTimeline *t = (sp40IkConstraintTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTMIX: {
			sp40PathConstraintMixTimeline *t = (sp40PathConstraintMixTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB2: {
			sp40RGB2Timeline *t = (sp40RGB2Timeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA2: {
			sp40RGBA2Timeline *t = (sp40RGBA2Timeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA: {
			sp40RGBATimeline *t = (sp40RGBATimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB: {
			sp40RGBTimeline *t = (sp40RGBTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSFORMCONSTRAINT: {
			sp40TransformConstraintTimeline *t = (sp40TransformConstraintTimeline *) timeline;
			_sp40Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DRAWORDER: {
			sp40DrawOrderTimeline *t = (sp40DrawOrderTimeline *) timeline;
			_sp40Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_EVENT: {
			sp40EventTimeline *t = (sp40EventTimeline *) timeline;
			_sp40Debug_printTimelineBase(&t->super);
			break;
		}
	}
}

void sp40Debug_printAnimation(sp40Animation *animation) {
	int i, n;
	printf("Animation %s: %i timelines\n", animation->name, animation->timelines->size);

	for (i = 0, n = animation->timelines->size; i < n; i++) {
		sp40Debug_printTimeline(animation->timelines->items[i]);
	}
}

void sp40Debug_printBoneDatas(sp40BoneData **boneDatas, int numBoneDatas) {
	int i;
	for (i = 0; i < numBoneDatas; i++) {
		sp40Debug_printBoneData(boneDatas[i]);
	}
}

void sp40Debug_printBoneData(sp40BoneData *boneData) {
	printf("Bone data %s: %f, %f, %f, %f, %f, %f %f\n", boneData->name, boneData->rotation, boneData->scaleX,
		   boneData->scaleY, boneData->x, boneData->y, boneData->shearX, boneData->shearY);
}

void sp40Debug_printSkeleton(sp40Skeleton *skeleton) {
	sp40Debug_printBones(skeleton->bones, skeleton->bonesCount);
}

void sp40Debug_printBones(sp40Bone **bones, int numBones) {
	int i;
	for (i = 0; i < numBones; i++) {
		sp40Debug_printBone(bones[i]);
	}
}

void sp40Debug_printBone(sp40Bone *bone) {
	printf("Bone %s: %f, %f, %f, %f, %f, %f\n", bone->data->name, bone->a, bone->b, bone->c, bone->d, bone->worldX,
		   bone->worldY);
}

void sp40Debug_printFloats(float *values, int numFloats) {
	int i;
	printf("(%i) [", numFloats);
	for (i = 0; i < numFloats; i++) {
		printf("%f, ", values[i]);
	}
	printf("]");
}
