vec4 light(vec4 color);

void
save_fragdata(vec4 color)
{
    gl_FragData[0] = light(color);
}
