precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @content */
uniform sampler2D u_content;
/** @sdf */
uniform sampler2D u_shape;
/** @label Landscape HDR map */
uniform sampler2D u_environment;
/**
 * @label Puff
 * @default 115
 * @range 20, 240
 */
uniform float u_puff;
/**
 * @label Depth
 * @default 1.25
 * @range 0.3, 2.5
 */
uniform float u_depth;
/**
 * @label Roundness
 * @default 20
 * @range 1, 50
 */
uniform float u_roundness;
/**
 * @label Environment rotation
 * @default 115
 * @range -180, 180
 */
uniform float u_rotation;
/**
 * @label Environment tilt
 * @default 12
 * @range -60, 60
 */
uniform float u_tilt;
/**
 * @label Exposure
 * @default 1.8
 * @range 0.2, 5
 */
uniform float u_exposure;
/**
 * @label Contrast
 * @default 1.25
 * @range 0.6, 2
 */
uniform float u_contrast;
/**
 * @label Sky blue
 * @default 0.5
 * @range 0, 1
 */
uniform float u_sky;
vec2 grad(vec2 uv){return texture2D(u_shape,uv).gb;}
vec3 env(vec3 r){
 float a=radians(u_rotation), b=radians(u_tilt);
 r.xz=mat2(cos(a),-sin(a),sin(a),cos(a))*r.xz;
 r.yz=mat2(cos(b),-sin(b),sin(b),cos(b))*r.yz;
 vec2 uv=vec2(fract(atan(r.z,r.x)/6.2831853+0.5),1.0-acos(clamp(r.y,-1.0,1.0))/3.14159265);
 vec3 enc=texture2D(u_environment,uv).rgb;
 vec3 hdr=enc*enc*16.0;
 float sky=smoothstep(0.035,0.17,r.y);
 vec3 blue=mix(vec3(0.65,0.79,0.94),vec3(0.20,0.44,0.86),pow(max(r.y,0.0),0.5));
 float bright=max(hdr.r,max(hdr.g,hdr.b));
 hdr=mix(hdr,blue*0.7,sky*u_sky*(1.0-smoothstep(1.0,4.0,bright)));
 float lum=dot(hdr,vec3(0.2126,0.7152,0.0722));
 hdr=mix(hdr,vec3(lum),0.68*(1.0-sky));
 float sun=pow(max(dot(r,normalize(vec3(-0.62,0.65,-0.44))),0.0),180.0);
 hdr+=vec3(3.5,3.25,2.95)*sun;
 vec3 c=hdr*u_exposure;
 c=c/(vec3(1.0)+c);
 c=pow(c,vec3(0.454545));
 c=clamp((c-0.5)*u_contrast+0.5,0.0,1.0);
 return c;
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 content=texture2D(u_content,uv);
 vec4 field=texture2D(u_shape,uv);
 vec2 e=vec2(u_roundness)/u_resolution;
 vec2 g=field.gb*4.0;
 g+=2.0*(grad(uv+vec2(e.x,0))+grad(uv-vec2(e.x,0))+grad(uv+vec2(0,e.y))+grad(uv-vec2(0,e.y)));
 g+=grad(uv+e)+grad(uv-e)+grad(uv+vec2(e.x,-e.y))+grad(uv+vec2(-e.x,e.y));
 g/=16.0;
 float t=clamp(max(field.r,0.0)/u_puff,0.0,0.999);
 float h=sqrt(max(t*(2.0-t),0.0001));
 float slope=(1.0-t)/max(h,0.025);
 vec3 n=normalize(vec3(-g*slope*u_depth,1.0));
 vec3 r=reflect(vec3(0,0,-1),n);
 vec3 c=env(r);
 float rim=exp(-max(field.r,0.0)/1.25);
 c=mix(c,vec3(0.88,0.93,1.0),rim*0.45);
 gl_FragColor=vec4(c*content.a,content.a);
}
