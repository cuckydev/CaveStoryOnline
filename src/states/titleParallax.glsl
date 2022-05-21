#ifdef VERTEX
    vec4 position( mat4 transform_projection, vec4 vertex_position ) 
    {
        return transform_projection * vertex_position;
    }
#endif

#ifdef PIXEL
    uniform number U_TIME;

    vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) 
    {
        vec4 parallax = Texel(tex,tex_coords+vec2(0,0.4838709677419355));

        tex_coords += vec2(floor(mod(parallax.r*U_TIME,1)*640)/640,0);
        return Texel(tex,tex_coords) * color;
    }
#endif