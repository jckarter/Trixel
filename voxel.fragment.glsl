varying vec3 ray, p0, rayscaled, p0scaled, surface_normal;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

const float tbias = 0.00001;
const int num_lights = 1;

float
minelt(vec3 v)
{
    return min(v.x, min(v.y, v.z));
}

float
maxelt(vec3 v)
{
    return max(v.x, max(v.y, v.z));
}

vec3
round(vec3 v)
{
    return floor(v + vec3(0.5));
}

vec3 cast_pt, world_cast_pt, normal;
float cast_index;

vec3 unbias(vec3 v) { return v * vec3(2) - vec3(1); }
vec3 bias(vec3 v) { return (v + vec3(1)) * vec3(0.5); }

void
cast_ray()
{
#ifdef TRIXEL_SURFACE_ONLY
    cast_pt = p0scaled;
    world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
    cast_index = texture3D(voxmap, cast_pt).r;
    normal = surface_normal;
#else
    vec3 rayinv = vec3(1.0)/ray;
    vec3 raysign = step(0.0, ray);
    vec3 bound = raysign * voxmap_size,
         tv  = (raysign - fract(p0)) * rayinv + vec3(tbias);
    float t = tbias,
          maxt = minelt((bound - p0) * rayinv);
        
    vec3 absrayinv = abs(rayinv);
        
    do {
        cast_pt = p0scaled + rayscaled*t;
        world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
        cast_index = texture3D(voxmap, cast_pt).r;
        if(cast_index != 0.0) {
            normal = t == tbias
                ? surface_normal
                : -step(-t, -tv) * unbias(raysign);
            return;
        }
        
        tv += absrayinv * step(-t, -tv);
        t = minelt(tv);
    } while(t < maxt);
    
    discard;
#endif
}

#ifdef TRIXEL_LIGHTING

vec4
light(vec4 color)
{
    vec4 lit_color = vec4(0.0);
    for(int light = 0; light < num_lights; ++light) {
        vec3 light_direction = normalize(gl_LightSource[light].position.xyz - world_cast_pt);
        return gl_LightSource[light].position / vec4(128);
        lit_color += gl_LightSource[light].ambient + gl_LightSource[light].diffuse * color * dot(light_direction, normal);
    }
    return lit_color;
}

#else

vec4
light(vec4 diffuse)
{
    return diffuse;
}

#endif

void
main()
{
    cast_ray();
    gl_FragData[0] = light(texture1D(palette, cast_index));
        
#ifdef TRIXEL_SAVE_COORDINATES
    gl_FragData[1] = vec4(floor(cast_pt * voxmap_size), 1);
    gl_FragData[2] = vec4(normal, 1);
#endif

    vec4 transformed_cast = gl_ModelViewProjectionMatrix * vec4(world_cast_pt, 1);
    gl_FragDepth = (transformed_cast.z/transformed_cast.w + 1.0) * 0.5;
}
