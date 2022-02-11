#ifndef REMAPPING_INCLUDED
#define REMAPPING_INCLUDED

// pixelate remapping operation from https://www.shadertoy.com/view/wtlcDj by @marcelliino
float2 pixelate(float2 pos, float res){
    return floor(pos * res+0.5)/res;
}

#endif