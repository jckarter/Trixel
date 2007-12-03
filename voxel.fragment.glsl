const float tbias = 0.000001;

varying vec3 ray, p0, rayscaled, p0scaled, surface_normal;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

struct light_struct {
    vec4 diffuse, ambient;
    vec4 position;
};

const int num_lights = 1;
uniform light_struct lights[num_lights];

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

float
voxel(vec3 pt)
{
    return texture3D(voxmap, pt).r;
}

bool
has_voxel(vec3 pt)
{
    return voxel(pt) > 0.0;
}

vec3 cast_pt, world_cast_pt, cast_normal;
float cast_index;

vec3 unbias(vec3 v) { return v * vec3(2) - vec3(1); }
vec3 bias(vec3 v) { return (v + vec3(1)) * vec3(0.5); }

#ifdef TRIXEL_SURFACE_ONLY

    void
    cast_ray()
    {
        cast_pt = p0scaled;
        world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
        cast_index = voxel(cast_pt);
        cast_normal = surface_normal;
    }

#else

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
            world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
            cast_index = voxel(cast_pt);
            if(cast_index != 0.0) {
                cast_normal = t == tbias
                    ? surface_normal
                    : -step(-t, -tv) * unbias(raysign);
                return;
            }

            tv += absrayinv * step(-t, -tv);
            t = minelt(tv);
        } while(t < maxt);

        discard;
    }

#endif

#ifdef TRIXEL_SMOOTH_SHADING

    vec3
    normal()
    {
        vec3 n = cast_normal*2.0;
        vec3 uaxis = cast_normal     * voxmap_size_inv,
             vaxis = cast_normal.yzx * voxmap_size_inv,
             waxis = cast_normal.zxy * voxmap_size_inv,
             vaxis_n = cast_normal.yzx,
             waxis_n = cast_normal.zxy;
        float slope = 0.0, i;

        for(i = 0.0; i < 3.0; i += 1.0)
            if(has_voxel(cast_pt + vaxis + uaxis*(1.0-i)))
                break;
        slope += i;
        for(i = 0.0; i < 3.0; i += 1.0)
            if(has_voxel(cast_pt - vaxis + uaxis*(1.0-i)))
                break;
        slope -= i;
        if(slope ==  3.0) slope =  4.0;
        if(slope == -3.0) slope = -4.0;
        n += vaxis_n * slope;

        slope = 0.0;
        for(i = 0.0; i < 3.0; i += 1.0)
            if(has_voxel(cast_pt + waxis + uaxis*(1.0-i)))
                break;
        slope += i;
        for(i = 0.0; i < 3.0; i += 1.0)
            if(has_voxel(cast_pt - waxis + uaxis*(1.0-i)))
                break;
        slope -= i;
        if(slope ==  3.0) slope =  4.0;
        if(slope == -3.0) slope = -4.0;
        n += waxis_n * slope;

        return normalize(n);
    }

#else

    vec3
    normal()
    {
        return cast_normal;
    }

#endif

#ifdef TRIXEL_LIGHTING

    vec4
    light(vec4 color)
    {
        vec4 lit_color = vec4(0.0);
        for(int light = 0; light < num_lights; ++light) {
            vec3 light_direction = normalize(lights[light].position.xyz - world_cast_pt);
            lit_color += (
                lights[light].ambient
                + lights[light].diffuse * clamp(dot(light_direction, normal()), 0.0, 1.0)
            ) * color;
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
    vec4 color = texture1D(palette, cast_index);

#ifdef TRIXEL_SURFACE_ONLY
    gl_FragData[0] = color.a == 0.0 ? vec4(color.rgb, 0.2) : color;
#else
    gl_FragData[0] = light(color);
    //gl_FragData[0] = vec4(normal(), 1.0);
#endif

#ifdef TRIXEL_SAVE_COORDINATES
    gl_FragData[1] = vec4(floor(cast_pt * voxmap_size), 1);
    gl_FragData[2] = vec4(cast_normal, 1);
#endif

    vec4 transformed_cast = gl_ModelViewProjectionMatrix * vec4(world_cast_pt, 1);
    gl_FragDepth = (transformed_cast.z/transformed_cast.w + 1.0) * 0.5;
}
