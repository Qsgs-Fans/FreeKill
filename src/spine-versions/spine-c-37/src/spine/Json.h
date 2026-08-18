/*
 Copyright (c) 2009 Dave Gamble
 
 Permission is hereby granted, dispose of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

/* Esoteric Software: Removed everything except parsing, shorter method names, more get methods, double to float, formatted. */

#ifndef SPINE_JSON_H_
#define SPINE_JSON_H_

#ifdef __cplusplus
extern "C" {
#endif

/* Json37 Types: */
#define Json37_False 0
#define Json37_True 1
#define Json37_NULL 2
#define Json37_Number 3
#define Json37_String 4
#define Json37_Array 5
#define Json37_Object 6

#ifndef SPINE_JSON_HAVE_PREV
/* Spine doesn't use the "prev" link in the Json37 sibling lists. */
#define SPINE_JSON_HAVE_PREV 0
#endif

/* The Json37 structure: */
typedef struct Json37 {
	struct Json37* next;
#if SPINE_JSON_HAVE_PREV
	struct Json37* prev; /* next/prev allow you to walk array/object chains. Alternatively, use getSize/getItem */
#endif
	struct Json37* child; /* An array or object item will have a child pointer pointing to a chain of the items in the array/object. */

	int type; /* The type of the item, as above. */
	int size; /* The number of children. */

	const char* valueString; /* The item's string, if type==Json37_String */
	int valueInt; /* The item's number, if type==Json37_Number */
	float valueFloat; /* The item's number, if type==Json37_Number */

	const char* name; /* The item's name string, if this item is the child of, or is in the list of subitems of an object. */
} Json37;

/* Supply a block of JSON, and this returns a Json37 object you can interrogate. Call Json37_dispose when finished. */
Json37* Json37_create (const char* value);

/* Delete a Json37 entity and all subentities. */
void Json37_dispose (Json37* json);

/* Get item "string" from object. Case insensitive. */
Json37* Json37_getItem (Json37* json, const char* string);
const char* Json37_getString (Json37* json, const char* name, const char* defaultValue);
float Json37_getFloat (Json37* json, const char* name, float defaultValue);
int Json37_getInt (Json37* json, const char* name, int defaultValue);

/* For analysing failed parses. This returns a pointer to the parse error. You'll probably need to look a few chars back to make sense of it. Defined when Json37_create() returns 0. 0 when Json37_create() succeeds. */
const char* Json37_getError (void);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_JSON_H_ */
