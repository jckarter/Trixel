uniform vec3 voxmap_size, voxmap_size_inv;
varying vec3 ray, p0, rayscaled, p0scaled;

void
main()
{    
    gl_Position = ftransform();
    
    p0 = gl_Vertex.xyz + voxmap_size*vec3(0.5);
    p0scaled = p0 * voxmap_size_inv;
    
    ray = gl_Vertex.xyz - gl_ModelViewMatrixInverse[3].xyz;
    rayscaled = ray * voxmap_size_inv;
}
