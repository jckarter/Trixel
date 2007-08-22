varying vec3 ray, p0;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

const float tbias = 0.00001;

vec3
select(vec3 sel, vec3 zerovals, vec3 onevals)
{
    return zerovals * (vec3(1)-sel) + onevals * sel;
}

float
minelt(vec3 v)
{
    return min(v.x, min(v.y, v.z));
}

float
sample_voxmap(vec3 p)
{
    return texture3D(voxmap, p * voxmap_size_inv).r;
}

vec4
lookup_palette(float idx)
{
    return texture1D(palette, idx);
}

vec4
cast_ray_naive()
{
    vec3 rayinv = vec3(1.0)/ray;
    vec3 raysign = step(0.0, ray);
    vec3 bound = raysign * voxmap_size;
    vec3 p = p0;
    
    do {
        float index = sample_voxmap(p);
        if(index != 0.0)
            return vec4(p, index);
        
        //vec3 pf = ceil(p)  - vec3(1.0);
        //vec3 pc = floor(p) + vec3(1.0);
        //vec3 pn = select(raysign, pf, pc);
        vec3 pn = raysign + floor(p);
        float t = minelt((pn - p) * rayinv);
        p += (t + tbias) * ray;
    } while(all(bvec4(equal(step(p, bound), raysign), true)));
    //} while(step(p, bound) == raysign); // doesn't work!?!
    
    discard;
}

float
cast_ray()
{
    vec3 rayinv = vec3(1.0)/ray;
    vec3 raysign = step(0.0, ray);
    vec3 bound = raysign * voxmap_size,
         tv  = (raysign - fract(p0)) * rayinv + vec3(tbias);
    float t = tbias,
          maxt = minelt((bound - p0) * rayinv);
        
    vec3 absrayinv = abs(rayinv);
    vec3 p0scaled = p0 * voxmap_size_inv,
         rayscaled = ray * voxmap_size_inv;
        
    do {
        vec3 pt = p0scaled + rayscaled*t;
        float index = texture3D(voxmap, pt).r;
        if(index != 0.0)
            return index;
        
        tv += absrayinv * step(-t, -tv);
        t = minelt(tv);
    } while(t < maxt);
    
    discard;
}

void
main()
{
    gl_FragColor = lookup_palette(cast_ray());
    //gl_FragColor = vec4(p.xyz, 1);
    //gl_FragColor = vec4(equal(vec4(0.5, 0.6, 0.7, 1.0), vec4(0.5, 0.0, 0.0, 1.0)));
    //gl_FragColor = vec4(all(bvec3(true, true, true)));
        
    //vec4 ptrans = gl_ModelViewProjectionMatrix * vec4(p.xyz - p0, 1);
    //gl_FragDepth = gl_FragCoord.z*gl_FragCoord.w + ptrans.z/ptrans.w;
}
