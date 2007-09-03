#extension GL_ARB_draw_buffers : enable

varying vec3 ray, p0, rayscaled, p0scaled;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

const float tbias = 0.00001;

float
minelt(vec3 v)
{
    return min(v.x, min(v.y, v.z));
}

vec3 cast_pt;
#ifdef TRIXEL_SAVE_COORDINATES
vec3 cast_normal;
#endif
float cast_index;

vec3
unbias(vec3 v)
{
    return v * vec3(2) - vec3(1);
}

vec3
bias(vec3 v)
{
    return (v + vec3(1)) / vec3(2);
}

void
cast_ray()
{
    vec3 rayinv = vec3(1.0)/ray;
    vec3 raysign = step(0.0, ray);
    vec3 bound = raysign * voxmap_size,
         tv  = (raysign - fract(p0)) * rayinv + vec3(tbias);
    float t = tbias,
          maxt = minelt((bound - p0) * rayinv);
        
    vec3 absrayinv = abs(rayinv);
        
    do {
        cast_pt = p0scaled + rayscaled*t;
        cast_index = texture3D(voxmap, cast_pt).r;
        if(cast_index != 0.0) {
#ifdef TRIXEL_SAVE_COORDINATES
            cast_normal = -step(-t, -tv) * unbias(raysign);
#endif
            return;
        }
        
        tv += absrayinv * step(-t, -tv);
        t = minelt(tv);
    } while(t < maxt);
    
    discard;
}

void
main()
{
    cast_ray();
    gl_FragData[0] = texture1D(palette, cast_index);

#ifdef TRIXEL_SAVE_COORDINATES
    gl_FragData[1] = vec4(cast_pt * voxmap_size, 1);
    gl_FragData[2] = vec4(cast_normal, 1);
#endif
}
