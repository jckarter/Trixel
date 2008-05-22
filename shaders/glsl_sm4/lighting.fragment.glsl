vec3 world_cast_pt;

struct light_struct {
    vec4 diffuse, ambient;
    vec4 position;
};

const int num_lights = 1;
uniform light_struct lights[num_lights];

vec3 normal();

vec4
light(vec4 color)
{
    vec4 lit_color = vec4(0.0);
    for(int light = 0; light < num_lights; ++light) {
        vec3 light_direction = normalize((gl_ModelViewMatrixInverse * lights[light].position).xyz - world_cast_pt);
        lit_color += (
            lights[light].ambient
            + lights[light].diffuse * clamp(dot(light_direction, normal()), 0.0, 1.0)
        ) * color;
    }
    return lit_color;
}
