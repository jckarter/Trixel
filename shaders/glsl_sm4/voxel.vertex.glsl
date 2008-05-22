uniform vec3 voxmap_size, voxmap_size_inv;
varying vec3 ray, p0, rayscaled, p0scaled, surface_normal;

struct light_struct {
    vec4 diffuse, ambient;
    vec4 position;
};

const int num_lights = 1;
uniform light_struct lights[num_lights];

varying vec3 world_light_positions[num_lights];

void
main()
{    
    gl_Position = ftransform();
    
    p0 = gl_Vertex.xyz + voxmap_size*vec3(0.5);
    p0scaled = p0 * voxmap_size_inv;
    
    ray = gl_Vertex.xyz - gl_ModelViewMatrixInverse[3].xyz;
    rayscaled = ray * voxmap_size_inv;
    
    surface_normal = gl_Normal.xyz;
    
    for(int i = 0; i < num_lights; ++i)
        world_light_positions[i] = (gl_ModelViewMatrixInverse * lights[i].position).xyz;
}
