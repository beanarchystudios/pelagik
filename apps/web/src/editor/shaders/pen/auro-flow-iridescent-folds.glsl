precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @sdf */
uniform sampler2D u_sdf;
/**
 * @label Speed
 * @default 0.75
 * @range 0, 2
 */
uniform float u_speed;
/**
 * @label Flow
 * @default 0.8
 * @range 0, 1.5
 */
uniform float u_flow;
/**
 * @label Bevel width
 * @default 30
 * @range 2, 70
 */
uniform float u_bevel;
/**
 * @label Depth
 * @default 0.85
 * @range 0, 1.5
 */
uniform float u_depth;
/**
 * @label Edge light
 * @default 0.65
 * @range 0, 1.5
 */
uniform float u_light;
/**
 * @label Accent intensity
 * @default 0.85
 * @range 0, 1.5
 */
uniform float u_orange;
/**
 * @label Accent colour
 * @color
 * @default #FF790A
 */
uniform vec3 u_amber;
/**
 * @label Dark pool
 * @default 0.98
 * @range 0, 1
 */
uniform float u_dark;
/**
 * @label Pool height
 * @default 0.56
 * @range 0.3, 0.8
 */
uniform float u_height;
/**
 * @label Cool rim
 * @default 0.75
 * @range 0, 1.5
 */
uniform float u_cool;
/**
 * @label Grain
 * @default 0.035
 * @range 0, 0.12
 */
uniform float u_grain;
/**
 * @label Body colour
 * @color
 * @default #FFDAA3
 */
uniform vec3 u_body;
/**
 * @label Pool colour
 * @color
 * @default #0A0201
 */
uniform vec3 u_pool;
/**
 * @label Cool light colour
 * @color
 * @default #91C2C9
 */
uniform vec3 u_coolColor;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec3 film(float x){
 float p=fract(x)*6.0;
 vec3 gold=u_body;
 vec3 rose=u_amber;
 vec3 violet=vec3(0.51,0.37,0.88);
 vec3 blue=vec3(0.25,0.52,0.92);
 vec3 cyan=u_coolColor;
 vec3 pearl=vec3(0.82,0.90,0.84);
 if(p<1.0)return mix(gold,rose,smoothstep(0.0,1.0,p));
 if(p<2.0)return mix(rose,violet,smoothstep(1.0,2.0,p));
 if(p<3.0)return mix(violet,blue,smoothstep(2.0,3.0,p));
 if(p<4.0)return mix(blue,cyan,smoothstep(3.0,4.0,p));
 if(p<5.0)return mix(cyan,pearl,smoothstep(4.0,5.0,p));
 return mix(pearl,gold,smoothstep(5.0,6.0,p));
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 sdf=texture2D(u_sdf,uv);
 float dist=max(sdf.r,0.0);
 vec2 inward=sdf.gb/max(length(sdf.gb),0.001);
 float shoulder=1.0-clamp(dist/max(u_bevel,0.1),0.0,1.0);
 float z=sqrt(max(0.001,1.0-shoulder*shoulder));
 vec3 normal=normalize(vec3(-inward*shoulder*u_depth,z));
 vec2 q=uv+inward*shoulder*u_depth*0.028;
 float t=u_time*u_speed;
 q+=u_flow*vec2(0.045*sin(q.y*5.0+t),0.060*sin(q.x*5.5-t*0.8));
 float bend=0.16*sin(q.x*6.0-q.y*4.0+t*0.16)+0.07*sin(q.y*12.0+q.x*3.0-t*0.12);
 float phase=(q.x*0.63+q.y*0.48+bend)*1.55+shoulder*0.22+normal.x*0.08;
 float ridge=0.5+0.5*sin((q.y*0.8-q.x*0.42+bend)*9.0+t*0.12);
 float fold=smoothstep(0.12,0.9,ridge);
 float pool=exp(-pow((q.x-0.34)/0.49,4.0)-pow((q.y-0.92)/(1.08-u_height),4.0));
 float dark=smoothstep(0.16,0.9,pool)*u_dark;
 float illumination=mix(0.36,1.08,fold)*(1.0-dark*0.68);
 vec3 col=mix(u_pool,film(phase),illumination);
 float edge=exp(-dist/(u_bevel*0.30));
 col=mix(col,film(phase+0.16),edge*0.55);
 vec3 light=normalize(vec3(-0.65,0.65,0.8));
 float diffuse=dot(normal,light);
 col*=1.0-u_depth*0.23*shoulder+u_depth*0.14*shoulder*diffuse;
 float spec=pow(max(dot(normal,normalize(light+vec3(0.0,0.0,1.0))),0.0),22.0);
 col+=mix(vec3(1.0),u_body,0.5)*spec*shoulder*u_light*0.6;
 float rim=exp(-dist/1.6);
 col+=rim*u_light*film(phase+0.16)*0.60;
 float frost=exp(-pow((q.x-0.67)/0.15,2.0))*smoothstep(0.4,0.9,q.y);
 col+=(hash(floor(gl_FragCoord.xy))-0.5)*u_grain*(0.2+frost*2.0);
 gl_FragColor=vec4(clamp(col,0.0,1.0),1.0);
}
