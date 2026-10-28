precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/**
 * @label Base Color
 * @color
 * @default #FF6200
 */
uniform vec3 u_color;
/**
 * @label Vividness
 * @default 1.4
 * @range 0.5, 2.5
 */
uniform float u_vivid;
/**
 * @label Curvature
 * @default 0.65
 * @range 0.0, 1.5
 */
uniform float u_curve;
/**
 * @label Glow Intensity
 * @default 0.8
 * @range 0.0, 2.0
 */
uniform float u_glowIntensity;
/**
 * @label Glow Spread
 * @default 0.65
 * @range 0.2, 1.4
 */
uniform float u_glowSpread;
/**
 * @label Shape Count
 * @default 3
 * @range 1, 6
 */
uniform int u_count;
/**
 * @label Form (0 Mixed, 1 Ribbons, 2 Lobes, 3 Lenses)
 * @default 0
 * @range 0, 3
 */
uniform int u_shape;
/**
 * @label Composition Seed
 * @default 12
 * @range 0, 999
 */
uniform int u_seed;
/**
 * @label Zoom
 * @default 0.9
 * @range 0.5, 3.0
 */
uniform float u_scale;
/**
 * @label Gap
 * @default 0.12
 * @range 0.04, 0.45
 */
uniform float u_gap;
/**
 * @label Variation
 * @default 0.7
 * @range 0.0, 1.0
 */
uniform float u_variation;
/**
 * @label Position X
 * @default 0.0
 * @range -1.0, 1.0
 */
uniform float u_x;
/**
 * @label Position Y
 * @default 0.0
 * @range -1.0, 1.0
 */
uniform float u_y;
/**
 * @label Angle
 * @default 0.0
 * @range -180, 180
 */
uniform float u_angle;
/**
 * @label Thickness
 * @default 0.415
 * @range 0.08, 0.8
 */
uniform float u_radius;
/**
 * @label Length
 * @default 1.1
 * @range 0.0, 2.0
 */
uniform float u_length;
/**
 * @label Heat
 * @default 1.26
 * @range 0.0, 1.8
 */
uniform float u_heat;
/**
 * @label Edge Detail
 * @default 1.0
 * @range 0.4, 2.0
 */
uniform float u_detail;
/**
 * @label Speed
 * @default 0.35
 * @range 0.0, 1.0
 */
uniform float u_speed;
/**
 * @label Phase
 * @default 0.0
 * @range 0.0, 6.283
 */
uniform float u_phase;
/**
 * @label Exposure
 * @default 1.6
 * @range 0.4, 1.6
 */
uniform float u_exposure;
float hash(float n){return fract(sin(n*127.1+float(u_seed)*311.7)*43758.5453);}
float bell(float x,float w){return exp(-x*x/(w*w));}
vec3 toHSV(vec3 c){
 vec4 K=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
 vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
 vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
 float d=q.x-min(q.w,q.y);
 return vec3(abs(q.z+(q.w-q.y)/(6.0*d+1.0e-8)),d/(q.x+1.0e-8),q.x);
}
vec3 fromHSV(vec3 c){
 vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
 return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
vec3 palette(vec3 original){
 vec3 seed=toHSV(clamp(u_color,0.0,1.0));
 vec3 c=toHSV(max(original,vec3(0.0)));
 c.x=fract(c.x+seed.x-0.720893142);
 c.y=clamp(c.y*seed.y/0.819607843,0.0,1.0);
 c.z*=0.2+0.8*seed.z;
 c.y=clamp(c.y*(0.65+0.35*u_vivid),0.0,1.0);
 c.z*=pow(max(u_vivid,0.1),0.65);
 return fromHSV(c);
}
vec3 material(vec3 N,float depth,vec2 q,float t){
 vec3 L=normalize(vec3(-0.58,0.82,0.65));
 float diffuse=max(dot(N,L),0.0);
 float rim=pow(1.0-N.z,2.2);
 float direction=dot(N.xy,normalize(vec2(-0.58,0.82)));
 float hot=pow(max(direction,0.0),2.0)+0.52*pow(max(-direction,0.0),4.0);
 hot*=0.94+0.06*cos(t+q.x*2.0);
 vec3 body=mix(vec3(0.020,0.008,0.072),vec3(0.17,0.045,0.38),diffuse);
 body+=vec3(0.095,0.025,0.24)*pow(1.0-N.z,0.7);
 body+=u_heat*vec3(0.32,0.06,0.13)*hot*pow(1.0-N.z,0.8);
 vec3 H=normalize(L+vec3(0.0,0.0,1.0));
 body+=vec3(0.32,0.24,0.44)*pow(max(dot(N,H),0.0),65.0)*0.55;
 float strip=bell(dot(N,normalize(vec3(0.65,0.45,0.22)))-0.88,0.023);
 body+=vec3(0.09,0.065,0.20)*strip*rim;
 float w=u_detail;
 float warm=bell(depth-0.031*w,0.017*w)*hot*u_heat;
 float green=bell(depth-0.009*w,0.006*w)*hot*u_heat;
 body=mix(body,vec3(0.94,0.43,0.12),clamp(warm,0.0,0.90));
 body=mix(body,vec3(0.11,0.65,0.43),clamp(green,0.0,0.80));
 body+=vec3(0.13,0.015,0.20)*bell(depth-0.085*w,0.022*w)*(0.3+0.7*hot);
 body+=vec3(0.15,0.12,0.28)*bell(depth-0.0025,0.0015)*(0.2+0.8*hot);
 return body;
}

float abstractField(vec2 q,float index,float t,float spacing){
 float phase=hash(71.0)*6.283185;
 float wave=u_curve*(0.24*sin(q.x*1.65+phase+t*0.18)+0.10*sin(q.x*3.0-phase));
 float y=q.y-wave-(index-(float(u_count)-1.0)*0.5)*spacing;
 float shift=(hash(index*7.0+3.0)-0.5)*1.5*u_variation;
 float x=q.x-shift;
 float len=max(u_length,0.15)*(1.0+hash(index*7.0+5.0)*0.55*u_variation);
 float kind=float(u_shape);
 if(kind<0.5) kind=1.0+mod(index+floor(hash(99.0)*3.0),3.0);
 float width=spacing*0.48*(1.0-clamp(u_gap,0.04,0.45));
 width*=clamp(u_radius/0.415,0.25,1.0);
 width*=mix(1.0,0.8+0.2*hash(index*7.0+1.0),u_variation);
 float envelope=1.0;
 if(kind>1.5) envelope=sqrt(max(1.0-pow(abs(x)/len,2.0),0.0));
 if(kind>2.5) envelope=pow(max(1.0-abs(x)/len,0.0),0.65);
 if(kind<1.5) envelope=0.82+0.18*sin(q.x*1.5+index+t*0.1);
 float side=abs(y)-width*envelope;
 if(kind>1.5 && abs(x)>len) side=max(side,abs(x)-len);
 return side;
}
vec2 profile(vec2 q,float index,float t,float spacing){
 float phase=hash(71.0)*6.283185;
 float wave=u_curve*(0.24*sin(q.x*1.65+phase+t*0.18)+0.10*sin(q.x*3.0-phase));
 float y=q.y-wave-(index-(float(u_count)-1.0)*0.5)*spacing;
 float width=max(abs(y)-abstractField(q,index,t,spacing),0.0001);
 return vec2(y,width);
}
float surfaceHeight(vec2 q,float index,float t,float spacing){
 vec2 v=profile(q,index,t,spacing);
 return sqrt(max(v.y*v.y-v.x*v.x,0.0));
}
void main(){
 float aspect=u_resolution.x/u_resolution.y;
 vec2 screen=(gl_FragCoord.xy-0.5*u_resolution)/u_resolution.y;
 vec2 p=(screen-vec2(u_x*aspect,-u_y))/max(u_scale,0.1);
 float t=u_time*u_speed*0.3+u_phase;
 float angle=radians(u_angle);
 float ca=cos(angle),sa=sin(angle);
 vec2 q=vec2(ca*p.x+sa*p.y,-sa*p.x+ca*p.y);
 float spacing=0.52;
 float spread=max(u_glowSpread,0.05);
 vec2 gp=(screen-vec2(0.12,-0.12))/vec2(spread*1.35,spread);
 vec2 gp2=(screen-vec2(-0.42,0.25))/vec2(spread*0.8,spread*0.65);
 float glow=0.19*exp(-dot(gp,gp)*1.8)+0.075*exp(-dot(gp2,gp2)*2.0);
 vec3 col=vec3(0.012,0.005,0.043)+vec3(0.447058824,0.180392157,1.0)*glow*u_glowIntensity;
 for(int i=0;i<6;i++){
  if(i>=u_count) break;
  float index=float(i);
  float d=abstractField(q,index,t,spacing);
  float aa=0.8/(u_resolution.y*max(u_scale,0.1));
  if(d>8.0*aa) continue;
  float eps=0.0005;
  vec2 grad=vec2(abstractField(q+vec2(eps,0.0),index,t,spacing)-abstractField(q-vec2(eps,0.0),index,t,spacing),abstractField(q+vec2(0.0,eps),index,t,spacing)-abstractField(q-vec2(0.0,eps),index,t,spacing))/(2.0*eps);
  float glen=clamp(length(grad),0.01,8.0);
  d/=glen;
  if(d<aa){
   grad/=glen;
   grad=vec2(ca*grad.x-sa*grad.y,sa*grad.x+ca*grad.y);
   vec2 hg=vec2(surfaceHeight(q+vec2(eps,0.0),index,t,spacing)-surfaceHeight(q-vec2(eps,0.0),index,t,spacing),surfaceHeight(q+vec2(0.0,eps),index,t,spacing)-surfaceHeight(q-vec2(0.0,eps),index,t,spacing))/(2.0*eps);
   hg=vec2(ca*hg.x-sa*hg.y,sa*hg.x+ca*hg.y);
   vec3 N=normalize(vec3(-hg,1.0));
   vec2 pr=profile(q,index,t,spacing);
   float depth=clamp(1.0-abs(pr.x)/pr.y,0.0,1.0);
   vec3 body=material(N,depth,q,t+index);
   body+=vec3(0.10,0.012,0.17)*bell(depth-0.25,0.21)*(0.6+0.4*sin(q.x+index));
   col=mix(col,body,1.0-smoothstep(-aa,aa,d));
  }
 }
 col=palette(col)*u_exposure;
 float noise=fract(sin(dot(gl_FragCoord.xy,vec2(12.9898,78.233)))*43758.5453)-0.5;
 gl_FragColor=vec4(clamp(col+noise/255.0,0.0,1.0),1.0);
}
