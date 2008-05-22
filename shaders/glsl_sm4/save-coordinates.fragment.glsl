uniform vec3 voxmap_size;
vec3 cast_pt, cast_normal;

vec4 light(vec4 color);

void
save_fragdata(vec4 color)
{
    gl_FragData[0] = light(color);
    gl_FragData[1] = vec4(floor(cast_pt * voxmap_size), 1);
    gl_FragData[2] = vec4(cast_normal, 1);
}
