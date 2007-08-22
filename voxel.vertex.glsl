uniform vec4 eye;
uniform vec3 voxmap_size_inv;
varying vec3 ray, p0, rayscaled, p0scaled;

void
main()
{    
    gl_Position = ftransform();
    p0       = gl_Vertex.xyz;
    p0scaled = p0 * voxmap_size_inv;
    ray       = p0 - (gl_ModelViewMatrixInverse * eye).xyz;
    rayscaled = ray * voxmap_size_inv;
}
