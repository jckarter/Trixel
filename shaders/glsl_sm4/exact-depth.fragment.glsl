vec3 world_cast_pt;

void
save_fragdepth()
{
    vec4 transformed_cast = gl_ModelViewProjectionMatrix * vec4(world_cast_pt, 1);
    gl_FragDepth = (transformed_cast.z/transformed_cast.w + 1.0) * 0.5;
}
