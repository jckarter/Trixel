#include "voxmap.h"
#include <stdlib.h>
#include <string.h>

voxmap *
voxmap_make(struct int3 dim)
{
    voxmap * v = malloc(sizeof(voxmap) + dim.x*dim.y*dim.z);
    v->dimensions = dim;
    return v;
}

void
voxmap_free(voxmap * v)
{
    free(v);
}

voxmap *
voxmap_dup(voxmap const * v, struct int3 low, struct int3 high)
{
    struct int3 dim = sub_int3(high, low);
    voxmap * new = voxmap_make(dim);

    for(int z = low.z; z < high.z; ++z)
        for(int y = low.y; y < high.y; ++y)
            for(int x = low.x; x < high.x; ++x)
                *voxmap_voxel(new, x - low.x, y - low.y, z - low.z) = *voxmap_voxel((voxmap*)v, x, y, z);
    return new;
}

voxmap *
voxmap_dup_all(voxmap const * v)
{
    voxmap * new = voxmap_make(v->dimensions);
    memcpy(new->data, v->data, voxmap_size(v));
    return new;
}

void
voxmap_copy(voxmap * to, struct int3 to_low, voxmap const * from)
{
    struct int3 to_high = min_int3(to->dimensions, add_int3(to_low, from->dimensions));

    for(int z = to_low.z; z < to_high.z; ++z)
        for(int y = to_low.y; y < to_high.y; ++y)
            for(int x = to_low.x; x < to_high.x; ++x)
                 *voxmap_voxel(to, x, y, z) = *voxmap_voxel((voxmap*)from, x - to_low.x, y - to_low.y, z - to_low.z);
}


void
voxmap_fill(voxmap * v, struct int3 low, struct int3 high, unsigned char fill)
{
    for(int z = low.z; z < high.z; ++z)
        for(int y = low.y; y < high.y; ++y)
            for(int x = low.x; x < high.x; ++x)
                 *voxmap_voxel(v, x, y, z) = fill;
}

void
voxmap_fill_all(voxmap * v, unsigned char fill)
{
    memset(v->data, fill, voxmap_size(v));
}

voxmap *
voxmap_maskify(voxmap * v, unsigned char mask_fill)
{
    voxmap * new = voxmap_make(v->dimensions);   

    unsigned char *np = new->data, *vp = v->data, *vend = vp + voxmap_size(v);
    for(; vp < vend; ++vp, ++np)
        *np = *vp == 0 ? 0 : mask_fill;
    return new;
}

voxmap *
voxmap_normify(voxmap * v, unsigned char mask_fill[4])
{
    voxmap * new = voxmap_make(INT3(v->dimensions.x * 4, v->dimensions.y, v->dimensions.z));   

    uint32_t fill = *(uint32_t*)mask_fill;
    uint32_t *np = (uint32_t *)new->data;
    unsigned char *vp = v->data, *vend = vp + voxmap_size(v);
    for(; vp < vend; ++vp, ++np)
        *np = *vp == 0 ? 0 : fill;
    return new;
}

void
voxmap_add(voxmap * to, voxmap const * from)
{
    unsigned char *tp = to->data, *fp = from->data, *fend = fp + voxmap_size(from);
    for(; fp < fend; ++fp, ++tp)
        *tp += *fp;
}

void
voxmap_sub(voxmap * to, voxmap const * from)
{
    unsigned char *tp = to->data, *fp = from->data, *fend = fp + voxmap_size(from);
    for(; fp < fend; ++fp, ++tp)
        *tp -= *fp;
}

int
voxmap_count(voxmap * v)
{
    int n = 0;
    unsigned char *vp = v->data, *vend = vp + voxmap_size(v);
    for(; vp < vend; ++vp)
        if(*vp != 0) ++n;
    return n;
}

void
voxmap_spans(voxmap const * v, struct int3 * out_min, struct int3 * out_max)
{
    struct int3 i;
    *out_min = v->dimensions;
    *out_max = INT3(-1, -1, -1);
    for(i.z = 0; i.z < v->dimensions.z; ++i.z)
        for(i.y = 0; i.y < v->dimensions.y; ++i.y)
            for(i.x = 0; i.x < v->dimensions.x; ++i.x)
                if(*voxmap_voxel((voxmap*)v, i.x, i.y, i.z) != 0) {
                    *out_min = min_int3(*out_min, i);
                    *out_max = max_int3(*out_max, i);
                }
    add_to_int3(out_max, INT3(1,1,1));
}
