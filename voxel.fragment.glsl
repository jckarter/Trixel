varying vec3 ray, p0;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

const float tbias = 0.000001;

vec3
select(bvec3 sel, vec3 truevals, vec3 falsevals)
{
    return vec3((sel.x ? truevals.x : falsevals.x),
                (sel.y ? truevals.y : falsevals.y),
                (sel.z ? truevals.z : falsevals.z));
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
cast_ray()
{
    vec3 rayinv = vec3(1.0)/ray;
    bvec3 raysign = bvec3(lessThan(ray, vec3(0.0)));
    vec3 bound = select(raysign, vec3(0.0), voxmap_size);
    vec3 p = p0;
    
    do {
        float index = sample_voxmap(p);
        if(index != 0.0)
            return vec4(p, index);
        
        vec3 pf = ceil(p)  - vec3(1.0);
        vec3 pc = floor(p) + vec3(1.0);
        vec3 pn = select(raysign, pf, pc);
        float t = minelt((pn - p) * rayinv);
        p += (t + tbias) * ray;
    } while(all(bvec4(equal(greaterThan(p, bound), raysign), true)));
    
    discard;
}

vec3
highlight_out_of_bounds(vec3 p)
{
    return any(lessThan(p, vec3(0))) || any(greaterThan(p, voxmap_size))
        ? vec3(0)
        : p;
}

void
main()
{
    vec4 p = cast_ray();
    
    //gl_FragColor = vec4(highlight_out_of_bounds(p.xyz) * voxmap_size_inv, 1);
    gl_FragColor = lookup_palette(p.w);
    //gl_FragColor = vec4(all(bvec3(true, true, true)));
        
    //vec4 ptrans = gl_ModelViewProjectionMatrix * vec4(p.xyz - p0, 1);
    //gl_FragDepth = gl_FragCoord.z*gl_FragCoord.w + ptrans.z/ptrans.w;
}
