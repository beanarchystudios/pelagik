precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @content */
uniform sampler2D u_content;
/** @label Glow @default 1.8 @range 0, 2 */
uniform float u_glow;
/** @label Glow spread @default 0 @range 0, 1 */
uniform float u_glowSpread;
float g(float x,float w){return exp(-x*x/(w*w));}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 under=texture2D(u_content,uv);
 vec2 q=(vec2(uv.x,1.0-uv.y)-0.5)*u_resolution/733.0;
 vec3 bloom=vec3(0.61,0.48,0.27)*g(length(q-vec2(0.075,-0.145)),0.090)*0.25;
 bloom+=vec3(0.64,0.73,0.77)*g(length(q-vec2(0.005,-0.168)),0.040)*0.30;
 bloom+=vec3(0.16,0.28,0.48)*g(length(q-vec2(-0.035,-0.190)),0.082)*0.18;
 bloom+=vec3(0.60,0.21,0.035)*g(length(q-vec2(-0.162,0.022)),0.054)*0.16;
 bloom+=vec3(0.08,0.22,0.40)*g(length(q-vec2(-0.139,0.093)),0.057)*0.14;
 float s=clamp(u_glowSpread,0.0,1.0);
 float reach=mix(-0.025,0.245,s);
 float fade=1.0-smoothstep(reach-0.075,reach,q.y);
 vec3 lower=vec3(0.58,0.30,0.08)*g(length(q-vec2(-0.16,0.027)),0.060)*0.32;
 lower+=vec3(0.11,0.34,0.55)*g(length(q-vec2(-0.125,0.105)),0.065)*0.36;
 lower+=vec3(0.15,0.42,0.58)*g(length(q-vec2(-0.04,0.16)),0.063)*0.32;
 lower+=vec3(0.56,0.37,0.13)*g(length(q-vec2(0.13,0.10)),0.070)*0.32;
 lower+=vec3(0.31,0.29,0.46)*g(length(q-vec2(0.065,0.154)),0.060)*0.22;
 bloom+=lower*fade*smoothstep(0.0,0.20,s);
 vec2 core=(q-vec2(0.032,-0.158))/vec2(0.045,0.020);
 bloom+=vec3(3.5)*exp(-dot(core,core))*exp(-pow((length(q)-0.166)/0.010,2.0));
 bloom*=u_glow;
 vec3 glowColor=vec3(1.0)-exp(-bloom);
 float alpha=max(glowColor.r,max(glowColor.g,glowColor.b));
 gl_FragColor=vec4(under.rgb+glowColor*(1.0-under.rgb),alpha+under.a*(1.0-alpha));
}
