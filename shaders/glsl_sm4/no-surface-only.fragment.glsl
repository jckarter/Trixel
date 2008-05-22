const float tbias = 0.000001;

vec3 cast_pt, world_cast_pt, cast_normal;
float cast_index;

float minelt(vec3 v) { return min(v.x, min(v.y, v.z)); }
vec3 unbias(vec3 v) { return v * vec3(2) - vec3(1); }

float voxel(vec3 pt);

void
cast_ray()
{
    vec3 rayinv = vec3(1.0)/ray,
         absrayinv = abs(rayinv),
         raysign = step(0.0, ray),
         bound = raysign * voxmap_size,
         tv = abs(raysign - fract(p0)),
         dtv = vec3(0.0),
         tvr = tv * absrayinv;
    
    float t = 0.0, lastt = 0.0,
          maxt = minelt((bound - p0) * rayinv);

    do {
        cast_pt = p0scaled + rayscaled*(0.5*(t+lastt) + tbias);
        world_cast_pt = (cast_pt - vec3(0.5)) * voxmap_size;
        cast_index = voxel(cast_pt);
        if(cast_index != 0.0) {
            cast_normal = t == 0.0
                ? surface_normal
                : -dtv * unbias(raysign);
            return;
        }

        tv += (dtv = step(-t, -tvr));
        lastt = t;
        t = minelt(tvr);
        tvr = tv * absrayinv;
    } while(t < maxt);

    discard;
}
