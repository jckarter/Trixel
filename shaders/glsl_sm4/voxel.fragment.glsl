varying vec3 ray, p0, rayscaled, p0scaled, surface_normal;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

vec3 cast_pt, world_cast_pt, cast_normal;
float cast_index;

void cast_ray();
vec3 normal();
vec4 light();
void save_fragdata(vec4 color);
void save_fragdepth();

float
voxel(vec3 pt)
{
    return texture3D(voxmap, pt).r;
}

void
main()
{
    cast_ray();
    save_fragdata(texture1D(palette, cast_index));
    save_fragdepth();

}
