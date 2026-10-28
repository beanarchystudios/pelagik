precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @content */
uniform sampler2D u_content;
/**
 * @label Bloom
 * @default 3.7
 * @range 0, 5
 */
uniform float u_bloom;
/**
 * @label Softness
 * @default 11.88
 * @range 1, 40
 */
uniform float u_softness;
/**
 * @label Temperature (cool / warm)
 * @default 0.22
 * @range -1, 1
 */
uniform float u_temperature;
vec3 grade(vec3 c){
 return clamp(c*exp(u_temperature*vec3(0.22,0.035,-0.24)),0.0,1.0);
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 src=texture2D(u_content,uv);
 vec3 c=src.a>0.001 ? clamp(src.rgb/src.a,0.0,1.0) : vec3(0.0);
 vec3 metal=grade(c)*src.a;
 float radius=clamp(u_softness,1.0,40.0);
 float taps=floor(clamp(radius*radius*0.16,32.0,256.0));
 vec3 sum=vec3(0.0);
 float weight=0.0;
 if(u_bloom>0.0){
  for(int i=0;i<256;i++){
   float fi=float(i)+0.5;
   if(fi>taps) break;

   float d=sqrt(-0.5*log(1.0-(fi/taps)*0.86466472));
   float ang=fi*2.39996323;
   vec2 k=vec2(cos(ang),sin(ang))*(d*radius);
   float w=1.0-smoothstep(0.8,1.0,d*d);
   vec4 s=texture2D(u_content,uv+k/u_resolution);
   vec3 rgb=s.a>0.001 ? clamp(s.rgb/s.a,0.0,1.0) : vec3(0.0);
   float l=dot(rgb,vec3(0.2126,0.7152,0.0722));
   float h=smoothstep(0.80,0.995,l)*s.a;
   sum+=grade(rgb)*h*w;
   weight+=w;
  }
 }
 vec3 glow=vec3(1.0)-exp(-sum/max(weight,0.0001)*u_bloom*1.6);
 glow*=smoothstep(0.001,0.006,max(glow.r,max(glow.g,glow.b)));
 float a=max(glow.r,max(glow.g,glow.b));
 gl_FragColor=vec4(metal+glow-metal*glow,src.a+a-src.a*a);
}
