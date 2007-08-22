varying vec3 ray, p0, rayscaled, p0scaled;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size;

const float tbias = 0.00001;

float
minelt(vec3 v)
{
    return min(v.x, min(v.y, v.z));
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
    gl_FragColor = texture1D(palette, cast_ray());
    //gl_FragColor = vec4(p.xyz, 1);
    //gl_FragColor = vec4(equal(vec4(0.5, 0.6, 0.7, 1.0), vec4(0.5, 0.0, 0.0, 1.0)));
    //gl_FragColor = vec4(all(bvec3(true, true, true)));
        
    //vec4 ptrans = gl_ModelViewProjectionMatrix * vec4(p.xyz - p0, 1);
    //gl_FragDepth = gl_FragCoord.z*gl_FragCoord.w + ptrans.z/ptrans.w;
}
