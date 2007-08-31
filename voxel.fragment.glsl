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

vec4
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
        vec3 pt = p0scaled + rayscaled*t;
        float index = texture3D(voxmap, pt).r;
        if(index != 0.0)
            return vec4(pt * voxmap_size, index);
        
        tv += absrayinv * step(-t, -tv);
        t = minelt(tv);
    } while(t < maxt);
    
    discard;
}

void
main()
{
    vec4 pt = cast_ray();
    gl_FragData[0] = texture1D(palette, pt.w);

#ifdef TRIXEL_SAVE_COORDINATES
    gl_FragData[1] = vec4(floor(pt.xyz), 1);
#endif
}
