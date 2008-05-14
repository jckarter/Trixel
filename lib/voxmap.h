#ifndef _VOXMAP_H_
#define _VOXMAP_H_

#include "trixel.h"

voxmap * voxmap_make(struct int3 dim);
void voxmap_free(voxmap * v);
voxmap * voxmap_dup(voxmap const * v, struct int3 low, struct int3 high);
voxmap * voxmap_dup_all(voxmap const * v);

void voxmap_copy(voxmap * to, struct int3 to_low, voxmap const * from);
void voxmap_fill(voxmap * v, struct int3 low, struct int3 high, uint8_t fill);
void voxmap_fill_all(voxmap * v, uint8_t fill);

voxmap * voxmap_maskify(voxmap * v, uint8_t mask_fill);
voxmap * voxmap_normify(voxmap * v, uint8_t mask_fill[4]);
void voxmap_add(voxmap * to, voxmap const * from);
void voxmap_sub(voxmap * to, voxmap const * from);

int voxmap_count(voxmap * v);

static inline uint8_t * voxmap_voxel(voxmap * v, int x, int y, int z)
    { return &v->data[x + y * v->dimensions.x + z * v->dimensions.x * v->dimensions.y]; }
static inline size_t voxmap_size(voxmap const * v)
    { return (size_t)v->dimensions.x * (size_t)v->dimensions.y * (size_t)v->dimensions.z; }

#endif
