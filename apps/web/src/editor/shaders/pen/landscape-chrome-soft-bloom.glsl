precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/**
 * @content
 * @mipmap
 */
uniform sampler2D u_content;
/**
 * @label Bloom
 * @default 0.8
 * @range 0, 3
 */
uniform float u_bloom;
/**
 * @label Softness
 * @default 16
 * @range 3, 40
 */
uniform float u_softness;
/**
 * @label Temperature (cool / warm)
 * @default 0.3
 * @range -1, 1
 */
uniform float u_temperature;
vec3 grade(vec3 c){
 vec3 gain=exp(u_temperature*vec3(0.22,0.035,-0.24));
 return clamp(c*gain,0.0,1.0);
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 src=texture2D(u_content,uv);
 vec3 metal=src.a>0.001 ? grade(clamp(src.rgb/src.a,0.0,1.0))*src.a : vec3(0.0);
 vec3 sum=vec3(0.0);
 for(int y=-4;y<=4;y++){
  for(int x=-4;x<=4;x++){
   if(x*x+y*y>13)continue;
   vec2 k=vec2(float(x),float(y))*0.75;
   float w=exp(-0.5*dot(k,k));
   vec4 s=texture2D(u_content,uv+k*u_softness/u_resolution);
   vec3 straight=s.a>0.001 ? clamp(s.rgb/s.a,0.0,1.0) : vec3(0.0);
   float l=dot(straight,vec3(0.2126,0.7152,0.0722));
   float bright=smoothstep(0.86,0.995,l);
   sum+=grade(straight)*bright*s.a*w;
  }
 }
 vec3 glow=vec3(1.0)-exp(-sum/11.158*u_bloom*2.4);
 glow*=smoothstep(0.002,0.012,max(glow.r,max(glow.g,glow.b)));
 float ga=max(glow.r,max(glow.g,glow.b));
 gl_FragColor=vec4(metal+glow-metal*glow,src.a+ga-src.a*ga);
}
