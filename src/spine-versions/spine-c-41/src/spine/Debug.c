/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

static const char *_sp41TimelineTypeNames[] = {
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

void sp41Debug_printSkeletonData(sp41SkeletonData *skeletonData) {
	int i, n;
	sp41Debug_printBoneDatas(skeletonData->bones, skeletonData->bonesCount);

	for (i = 0, n = skeletonData->animationsCount; i < n; i++) {
		sp41Debug_printAnimation(skeletonData->animations[i]);
	}
}

void _sp41Debug_printTimelineBase(sp41Timeline *timeline) {
	printf("   Timeline %s:\n", _sp41TimelineTypeNames[timeline->type]);
	printf("      frame count: %i\n", timeline->frameCount);
	printf("      frame entries: %i\n", timeline->frameEntries);
	printf("      frames: ");
	sp41Debug_printFloats(timeline->frames->items, timeline->frames->size);
	printf("\n");
}

void _sp41Debug_printCurveTimeline(sp41CurveTimeline *timeline) {
	_sp41Debug_printTimelineBase(&timeline->super);
	printf("      curves: ");
	sp41Debug_printFloats(timeline->curves->items, timeline->curves->size);
	printf("\n");
}

void sp41Debug_printTimeline(sp41Timeline *timeline) {
	switch (timeline->type) {
		case SP_TIMELINE_ATTACHMENT: {
			sp41AttachmentTimeline *t = (sp41AttachmentTimeline *) timeline;
			_sp41Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_ALPHA: {
			sp41AlphaTimeline *t = (sp41AlphaTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTPOSITION: {
			sp41PathConstraintPositionTimeline *t = (sp41PathConstraintPositionTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTSPACING: {
			sp41PathConstraintMixTimeline *t = (sp41PathConstraintMixTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_ROTATE: {
			sp41RotateTimeline *t = (sp41RotateTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEX: {
			sp41ScaleXTimeline *t = (sp41ScaleXTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALEY: {
			sp41ScaleYTimeline *t = (sp41ScaleYTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARX: {
			sp41ShearXTimeline *t = (sp41ShearXTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEARY: {
			sp41ShearYTimeline *t = (sp41ShearYTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEX: {
			sp41TranslateXTimeline *t = (sp41TranslateXTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATEY: {
			sp41TranslateYTimeline *t = (sp41TranslateYTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SCALE: {
			sp41ScaleTimeline *t = (sp41ScaleTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_SHEAR: {
			sp41ShearTimeline *t = (sp41ShearTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSLATE: {
			sp41TranslateTimeline *t = (sp41TranslateTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DEFORM: {
			sp41DeformTimeline *t = (sp41DeformTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_IKCONSTRAINT: {
			sp41IkConstraintTimeline *t = (sp41IkConstraintTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_PATHCONSTRAINTMIX: {
			sp41PathConstraintMixTimeline *t = (sp41PathConstraintMixTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB2: {
			sp41RGB2Timeline *t = (sp41RGB2Timeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA2: {
			sp41RGBA2Timeline *t = (sp41RGBA2Timeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGBA: {
			sp41RGBATimeline *t = (sp41RGBATimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_RGB: {
			sp41RGBTimeline *t = (sp41RGBTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_TRANSFORMCONSTRAINT: {
			sp41TransformConstraintTimeline *t = (sp41TransformConstraintTimeline *) timeline;
			_sp41Debug_printCurveTimeline(&t->super);
			break;
		}
		case SP_TIMELINE_DRAWORDER: {
			sp41DrawOrderTimeline *t = (sp41DrawOrderTimeline *) timeline;
			_sp41Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_EVENT: {
			sp41EventTimeline *t = (sp41EventTimeline *) timeline;
			_sp41Debug_printTimelineBase(&t->super);
			break;
		}
		case SP_TIMELINE_SEQUENCE: {
			sp41SequenceTimeline *t = (sp41SequenceTimeline *) timeline;
			_sp41Debug_printTimelineBase(&t->super);
		}
	}
}

void sp41Debug_printAnimation(sp41Animation *animation) {
	int i, n;
	printf("Animation %s: %i timelines\n", animation->name, animation->timelines->size);

	for (i = 0, n = animation->timelines->size; i < n; i++) {
		sp41Debug_printTimeline(animation->timelines->items[i]);
	}
}

void sp41Debug_printBoneDatas(sp41BoneData **boneDatas, int numBoneDatas) {
	int i;
	for (i = 0; i < numBoneDatas; i++) {
		sp41Debug_printBoneData(boneDatas[i]);
	}
}

void sp41Debug_printBoneData(sp41BoneData *boneData) {
	printf("Bone data %s: %f, %f, %f, %f, %f, %f %f\n", boneData->name, boneData->rotation, boneData->scaleX,
		   boneData->scaleY, boneData->x, boneData->y, boneData->shearX, boneData->shearY);
}

void sp41Debug_printSkeleton(sp41Skeleton *skeleton) {
	sp41Debug_printBones(skeleton->bones, skeleton->bonesCount);
}

void sp41Debug_printBones(sp41Bone **bones, int numBones) {
	int i;
	for (i = 0; i < numBones; i++) {
		sp41Debug_printBone(bones[i]);
	}
}

void sp41Debug_printBone(sp41Bone *bone) {
	printf("Bone %s: %f, %f, %f, %f, %f, %f\n", bone->data->name, bone->a, bone->b, bone->c, bone->d, bone->worldX,
		   bone->worldY);
}

void sp41Debug_printFloats(float *values, int numFloats) {
	int i;
	printf("(%i) [", numFloats);
	for (i = 0; i < numFloats; i++) {
		printf("%f, ", values[i]);
	}
	printf("]");
}
