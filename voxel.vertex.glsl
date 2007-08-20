uniform vec4 eye;
varying vec3 ray, p0;

void
main()
{    
    gl_Position = ftransform();
    p0 = gl_Vertex.xyz;
    ray = p0 - (gl_ModelViewMatrixInverse * eye).xyz;
}
