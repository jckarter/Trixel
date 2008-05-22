varying vec3 ray, p0, rayscaled, p0scaled, surface_normal;

uniform sampler3D voxmap;
uniform sampler1D palette;
uniform vec3 voxmap_size, voxmap_size_inv;

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
         delta_tv = vec3(0.0),
         tv_ray = tv * absrayinv;
    
    float t_near = 0.0, t_far = minelt(tv_ray),
          t_max = minelt((bound - p0) * rayinv);
    
    do {
        vec3 sample_pt = p0scaled + rayscaled*(0.5*(t_near+t_far));
        cast_index = voxel(sample_pt);
        if(cast_index != 0.0) {
            cast_pt = p0scaled + rayscaled*t_near;
            cast_normal = t_near == 0.0 ? surface_normal : -delta_tv * unbias(raysign);
            world_cast_pt = p0 + ray*t_near;
            return;
        }
        
        t_near = t_far;
        tv += (delta_tv = step(-t_far, -tv_ray));
        tv_ray = tv * absrayinv;
        t_far = minelt(tv_ray);
    } while(t_near < t_max);
    
    discard;
}
