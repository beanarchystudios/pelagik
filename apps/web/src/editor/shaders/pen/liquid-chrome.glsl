precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @content */
uniform sampler2D u_content;
/** @sdf */
uniform sampler2D u_sdf;
/** @label Metal @default 1 @range 0, 2 */
uniform float u_metal;
/** @label Dispersion @default 1.44 @range 0, 2 */
uniform float u_dispersion;
/** @label Liquid texture @default 0.8 @range 0, 2 */
uniform float u_liquid;
/** @label Speed @default 0.77 @range 0, 1 */
uniform float u_speed;
vec3 key(float k){
 k=mod(k,24.0);
 if(k<0.5)return vec3(182,110,39);
 if(k<1.5)return vec3(42,22,16);
 if(k<2.5)return vec3(22,14,31);
 if(k<3.5)return vec3(27,51,109);
 if(k<4.5)return vec3(94,146,212);
 if(k<5.5)return vec3(228,249,254);
 if(k<6.5)return vec3(251,255,254);
 if(k<7.5)return vec3(255,255,255);
 if(k<8.5)return vec3(255,255,254);
 if(k<9.5)return vec3(254,250,243);
 if(k<10.5)return vec3(227,217,209);
 if(k<11.5)return vec3(202,176,172);
 if(k<12.5)return vec3(111,82,47);
 if(k<13.5)return vec3(104,85,157);
 if(k<14.5)return vec3(203,182,110);
 if(k<15.5)return vec3(142,84,38);
 if(k<16.5)return vec3(49,28,24);
 if(k<17.5)return vec3(21,30,59);
 if(k<18.5)return vec3(40,98,133);
 if(k<19.5)return vec3(134,151,232);
 if(k<20.5)return vec3(217,241,220);
 if(k<21.5)return vec3(228,158,184);
 if(k<22.5)return vec3(176,251,255);
 return vec3(255,252,171);
}
vec3 palette(float a){float k=(a+3.14159265)*3.81971863; return mix(key(floor(k)),key(floor(k)+1.0),smoothstep(0.0,1.0,fract(k)))/255.0;}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec2 q=(vec2(uv.x,1.0-uv.y)-0.5)*u_resolution;
 float a=atan(q.y,q.x),t=u_time*u_speed;
 vec4 src=texture2D(u_content,uv);
 float d=texture2D(u_sdf,uv).r;
 float alpha=src.a;
 float ripple=sin(6.0*a-2.7*t+1.1*sin(3.0*a+t));
 float reflection=a+0.035*u_liquid*sin(4.0*a-1.7*t);
 float split=0.018*u_dispersion*sin(d*0.85);
 vec3 env=vec3(palette(reflection+split).r,palette(reflection).g,palette(reflection-split).b);
 float bevel=1.20+0.35*smoothstep(0.0,3.0,d);
 float brightness=0.90+0.10*u_liquid*ripple;
 vec3 metal=env*bevel*brightness;
 metal+=env*exp(-pow((d-2.0-0.9*u_liquid*ripple)/0.65,2.0))*0.22;
 vec3 ring=min(metal*u_metal,vec3(1.0))*alpha;
 gl_FragColor=vec4(ring,alpha);
}
