precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/**
 * @label Speed
 * @default 0.28
 * @range 0, 1
 */
uniform float u_speed;
/**
 * @label Liquid
 * @default 0.45
 * @range 0, 1
 */
uniform float u_liquid;
/**
 * @label Dispersion
 * @default 0.65
 * @range 0, 1
 */
uniform float u_dispersion;
/**
 * @label Contrast
 * @default 0.8
 * @range 0, 1
 */
uniform float u_contrast;
float room(float q){
 float a=0.5+0.5*sin(q);
 float base=mix(0.48,0.11,u_contrast)+0.36*smoothstep(0.1,0.85,a);
 float box=smoothstep(0.89,0.94,a);
 float strip=exp(-pow((a-0.70)/0.027,2.0));
 return base+box*0.58+strip*0.48;
}
void main(){
 vec2 p=gl_FragCoord.xy-0.5*u_resolution;
 float radius=u_resolution.y*0.5;
 float halfLine=max(0.0,u_resolution.x*0.5-radius);
 vec2 v=p-vec2(clamp(p.x,-halfLine,halfLine),0.0);
 vec2 n=normalize(v+vec2(0.0001));
 float t=u_time*u_speed;
 float x=p.x/u_resolution.x;
 float warp=u_liquid*(sin(x*13.0+t*1.3)+0.42*sin(x*27.0-t*0.9));
 float q=n.x*1.65+n.y*1.8+x*5.8+warp+t;
 float split=u_dispersion*0.095;
 vec3 c=vec3(room(q+split),room(q),room(q-split));
 c*=vec3(0.94,0.96,1.0);
 float edge=abs(length(v)-radius);
 c+=0.12*exp(-edge*edge/1.4);
 gl_FragColor=vec4(clamp(c,0.0,1.0),1.0);
}
