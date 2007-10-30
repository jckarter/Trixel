varying vec3 ray, p0, rayscaled, p0scaled;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

const float tbias = 0.00001;
const float grid_line_thickness = 0.1;
const vec4 grid_color = vec4(0.0, 0.0, 0.0, 1.0);

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

vec3 cast_pt;
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
#ifdef TRIXEL_SURFACE_ONLY
    cast_pt = p0scaled;
    cast_index = texture3D(voxmap, cast_pt).r;
    if(cast_index == 0.0)
        discard;
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
        cast_index = texture3D(voxmap, cast_pt).r;
        if(cast_index != 0.0)
            return;
        
        tv += absrayinv * step(-t, -tv);
        t = minelt(tv);
    } while(t < maxt);
    
    discard;
#endif
}

void
main()
{
    cast_ray();
    gl_FragData[0] =
#ifdef TRIXEL_GRID
        maxelt(abs(cast_pt * voxmap_size - round(cast_pt * voxmap_size))) <= grid_line_thickness ? grid_color :
#endif
        texture1D(palette, cast_index);

#ifdef TRIXEL_SAVE_COORDINATES
    gl_FragData[1] = vec4(floor(cast_pt * voxmap_size), 1);
#endif
}
