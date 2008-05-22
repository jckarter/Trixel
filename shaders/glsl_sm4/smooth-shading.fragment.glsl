uniform sampler3D normals;
uniform vec3 normal_translate, normal_scale;

vec3 cast_pt;

vec3
normal()
{
    return normalize(texture3D(normals, cast_pt * normal_scale + normal_translate).xyz);
}
