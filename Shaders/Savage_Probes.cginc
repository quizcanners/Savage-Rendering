// sample the 2D texture by direction
/*
vec2 sampleEM(vec3 dir)
{
    vec2 pt;
    pt.y = acos(dir.y) / PI;
    float sin_theta = sqrt(1. - dir.y * dir.y);
    dir.z > 0. ? pt.x = acos(dir.x / sin_theta) : (pt.x = 2. * PI - acos(dir.x / sin_theta));
    pt.x /= (2. * PI);
    return pt;
}

// uniform sampling on the hemisphere of the surface
vec3 uniSampleSphere(vec2 uv, vec3 norm)
{
    float phi = uv.x * 2. * PI;
    float cos_theta = cos(2. * acos(sqrt(1. - uv.y)));
    float sin_theta = sqrt(1. - cos_theta * cos_theta);
   
    
    float x = sin_theta * cos(phi);
    float y = sin_theta * sin(phi);
    float z = cos_theta;
    
    // refers to the function in the 'Common' tab, which I found is good to reach a smooth result
    // cite: https://www.shadertoy.com/view/MsXBzl
    vec3 up = stepValue3(0.999, norm.z, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
    vec3 tangent = normalize(cross(up, norm));
    vec3 bitangent = cross(norm, tangent);

    return tangent * x + bitangent * y + norm * z;
    
}
*/