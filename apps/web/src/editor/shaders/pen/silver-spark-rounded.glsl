precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @sdf */
uniform sampler2D u_sdf;
/** @content */
uniform sampler2D u_content;
/**
 * @label Bevel width
 * @default 19
 * @range 2, 50
 */
uniform float u_bevel;
/**
 * @label Bevel roundness
 * @default 1
 * @range 0.4, 2
 */
uniform float u_roundness;
/**
 * @label Bevel depth
 * @default 0.85
 * @range 0.2, 2
 */
uniform float u_depth;
/**
 * @label Polished rim
 * @default 0.3
 * @range 0, 1
 */
uniform float u_rim;
/**
 * @label Silver brightness
 * @default 0.82
 * @range 0.3, 1.4
 */
uniform float u_silver;
/**
 * @label Reflection contrast
 * @default 1.15
 * @range 0.4, 2
 */
uniform float u_contrast;
/**
 * @label Light angle
 * @default -12
 * @range -180, 180
 */
uniform float u_lightAngle;
/**
 * @label Softbox width
 * @default 0.22
 * @range 0.05, 0.5
 */
uniform float u_softness;
/**
 * @label Shine
 * @default 0.7
 * @range 0, 2
 */
uniform float u_shine;
/**
 * @label Spectrum amount
 * @default 0.9
 * @range 0, 1.5
 */
uniform float u_iris;
/**
 * @label Spectrum spread
 * @default 0.24
 * @range 0.04, 0.65
 */
uniform float u_spread;
/**
 * @label Spectrum position
 * @default 0.62
 * @range 0, 1
 */
uniform float u_position;
/**
 * @label Spectrum hue
 * @default 0
 * @range 0, 360
 */
uniform float u_hue;
/**
 * @label Spectrum cycles
 * @default 1.1
 * @range 0.2, 3
 */
uniform float u_cycles;
/**
 * @label Edge iridescence
 * @default 0.65
 * @range 0, 1.5
 */
uniform float u_edgeColour;
/**
 * @label Reflection speed
 * @default 0.35
 * @range 0, 1
 */
uniform float u_speed;
/**
 * @label Spark intensity
 * @default 1.5
 * @range 0, 3
 */
uniform float u_sparks;
/**
 * @label Spark size
 * @default 72
 * @range 10, 120
 */
uniform float u_sparkSize;
/**
 * @label Spark count
 * @default 6
 * @range 0, 8
 */
uniform float u_count;
/**
 * @label Spark width
 * @default 1.15
 * @range 0.3, 4
 */
uniform float u_sparkWidth;
/**
 * @label Spark halo
 * @default 0.55
 * @range 0, 2
 */
uniform float u_halo;
/**
 * @label Spark angle
 * @default 45
 * @range 0, 180
 */
uniform float u_sparkAngle;
/**
 * @label Spark speed
 * @default 0.65
 * @range 0, 2
 */
uniform float u_sparkSpeed;
/**
 * @label Satin grain
 * @default 0.025
 * @range 0, 0.12
 */
uniform float u_grain;
float gauss(float x,float w){return exp(-x*x/max(w*w,0.00001));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
mat2 rotate(float a){return mat2(cos(a),-sin(a),sin(a),cos(a));}
vec3 spectrum(float h){
 vec3 c=clamp(abs(fract(h+vec3(0.0,0.666667,0.333333))*6.0-3.0)-1.0,0.0,1.0);
 return mix(vec3(0.06),vec3(1.0),c*c*(3.0-2.0*c));
}
vec3 studio(vec2 p,float t){
 vec2 q=rotate(u_lightAngle*0.0174533)*(p-0.5)+0.5;
 float y=q.y+0.035*sin(t);
 float v=0.24+0.42*(1.0-smoothstep(0.14,0.95,y));
 v+=u_shine*(0.53*gauss(y-0.22,u_softness)+0.22*gauss(y-0.08,0.035));
 v-=0.20*gauss(y-0.62,0.09);
 v+=0.18*gauss(y-0.89,0.10);
 v=max(0.035,(v-0.4)*u_contrast+0.4)*u_silver;
 float envelope=gauss(y-u_position-0.035*sin(q.x*5.0+t),u_spread);
 float h=q.x*u_cycles+q.y*0.22+0.06*sin(t*0.7)+u_hue/360.0;
 vec3 rainbow=spectrum(h);
 vec3 colour=mix(vec3(v)*vec3(0.96,0.99,1.03),vec3(v)*(0.18+rainbow*1.25),clamp(envelope*u_iris,0.0,0.95));
 return max(colour,0.0);
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 field=texture2D(u_sdf,uv);
 float d=field.r;
 vec2 g=field.gb/max(length(field.gb),0.001);
 float a=texture2D(u_content,uv).a;
 float t=u_time*u_speed;
 float z=clamp(d/max(u_bevel,1.0),0.0,1.0);
 float shoulder=pow(1.0-z,u_roundness);
 float slope=u_depth*shoulder/max(sqrt(max(1.0-shoulder*shoulder,0.0)),0.10);
 vec3 n=normalize(vec3(-g*slope,1.0));
 vec3 r=reflect(vec3(0.0,0.0,-1.0),n);
 vec2 look=vec2(uv.x,1.0-uv.y)+vec2(r.x,-r.y)*0.43;
 vec3 col=studio(look,t);
 vec3 light=normalize(vec3(-0.45,0.65,0.85));
 float shoulderLight=pow(max(dot(n,normalize(light+vec3(0.0,0.0,1.0))),0.0),16.0);
 float bevel=1.0-smoothstep(0.65,1.0,z);
 col*=1.0-0.4*bevel*(1.0-max(dot(n,light),0.0));
 col+=vec3(0.82,0.90,1.0)*shoulderLight*bevel*u_shine*0.7;
 float thinfilm=gauss(z-0.30,0.17)*u_edgeColour;
 vec3 edge=spectrum(z*0.75+g.x*0.22+u_hue/360.0+t*0.04);
 col=mix(col,col*(0.2+edge*1.45),clamp(thinfilm,0.0,0.85));
 float rim=gauss(d-0.9,0.8)*u_rim;
 col+=vec3(rim);
 col+=gauss(uv.x*0.8+uv.y*0.3-0.5-0.38*sin(t*0.6),0.14)*0.12*u_shine;
 col+=(hash(floor(gl_FragCoord.xy))-0.5)*u_grain;
 col=clamp(col,0.0,1.0);
 vec3 rgb=col*a;
 float alpha=a;
 for(int i=0;i<8;i++){
  float k=float(i);
  vec2 seed=vec2(0.23,0.17);
  if(i==1)seed=vec2(0.80,0.24);
  if(i==2)seed=vec2(0.83,0.53);
  if(i==3)seed=vec2(0.50,0.88);
  if(i==4)seed=vec2(0.31,0.58);
  if(i==5)seed=vec2(0.19,0.40);
  if(i==6)seed=vec2(0.56,0.25);
  if(i==7)seed=vec2(0.65,0.66);
  seed.y=1.0-seed.y;
  vec4 s=texture2D(u_sdf,seed);
  vec2 grad=s.gb/max(length(s.gb),0.001);
  vec2 center=seed*u_resolution-grad*s.r;
  vec2 q=rotate(u_sparkAngle*0.0174533)*(gl_FragCoord.xy-center);
  float pulse=pow(0.5+0.5*cos(u_time*u_sparkSpeed*1.8+k*2.2),3.0);
  pulse=mix(0.035,1.0,pulse)*step(k+0.5,u_count);
  float size=u_sparkSize*(0.65+0.35*pulse);
  float ray=gauss(q.y,u_sparkWidth)*pow(max(0.0,1.0-abs(q.x)/size),1.7)+gauss(q.x,u_sparkWidth)*pow(max(0.0,1.0-abs(q.y)/size),1.7);
  float glow=exp(-dot(q,q)/(size*size*0.03));
  float core=exp(-dot(q,q)/5.0);
  float star=(ray*0.9+glow*u_halo+core)*pulse*u_sparks;
  float sa=clamp(star,0.0,1.0);
  rgb=vec3(sa)+rgb*(1.0-sa);
  alpha=sa+alpha*(1.0-sa);
 }
 gl_FragColor=vec4(rgb,alpha);
}
