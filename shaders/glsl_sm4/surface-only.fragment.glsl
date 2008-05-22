vec3 cast_pt, world_cast_pt, cast_normal;
float cast_index;

float voxel(vec3 pt);

void
cast_ray()
{
    cast_pt = p0scaled;
    world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
    cast_index = voxel(cast_pt);
    cast_normal = surface_normal;
}

