precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @sdf */
uniform sampler2D u_shape;
/**
 * @label Rotation
 * @default 20
 * @range -180, 180
 */
uniform float u_rotation;
/**
 * @label Speed (turns per minute)
 * @default 2
 * @range 0, 10
 */
uniform float u_speed;
/**
 * @label Tilt
 * @default 12
 * @range -60, 60
 */
uniform float u_tilt;
/**
 * @label Thickness
 * @default 12
 * @range 2, 30
 */
uniform float u_thickness;
/**
 * @label Rounding
 * @default 3
 * @range 0.2, 10
 */
uniform float u_rounding;
/**
 * @label Scale
 * @default 1
 * @range 0.4, 1.3
 */
uniform float u_scale;
/**
 * @label Chrome tint
 * @color
 * @default #12677c
 */
uniform vec3 u_tint;
/**
 * @label ENV rotation
 * @default 0
 * @range -180, 180
 */
uniform float u_envRotation;
/**
 * @label ENV tilt
 * @default 0
 * @range -90, 90
 */
uniform float u_envTilt;
/**
 * @label ENV strip angle
 * @default 0
 * @range -180, 180
 */
uniform float u_envAngle;
/**
 * @label ENV light strength
 * @default 1
 * @range 0, 3
 */
uniform float u_envLight;
/**
 * @label ENV light coverage
 * @default 1
 * @range 0.15, 3
 */
uniform float u_envCoverage;
/**
 * @label ENV dark strength
 * @default 0
 * @range 0, 1
 */
uniform float u_envDark;
/**
 * @label ENV dark coverage
 * @default 0.4
 * @range 0.02, 1
 */
uniform float u_envDarkCoverage;
/**
 * @label ENV softness
 * @default 1
 * @range 0, 1
 */
uniform float u_envSoftness;
/**
 * @label Shadow strength
 * @default 0.55
 * @range 0, 1
 */
uniform float u_shadowStrength;
/**
 * @label Shadow softness
 * @default 0.65
 * @range 0.05, 1
 */
uniform float u_shadowSoftness;
/**
 * @label Shadow direction
 * @default 135
 * @range -180, 180
 */
uniform float u_shadowDirection;
/**
 * @label Contact strength
 * @default 0.85
 * @range 0, 1
 */
uniform float u_contactStrength;
/**
 * @label Contact spread
 * @default 7
 * @range 1, 20
 */
uniform float u_contactSpread;
/**
 * @label Ground level
 * @default -29.5
 * @range -60, 0
 */
uniform float u_groundLevel;
/**
 * @label Shadow tint
 * @color
 * @default #080810
 */
uniform vec3 u_shadowTint;
mat3 turn(float a,float b){
 float c=cos(a),s=sin(a),v=cos(b),w=sin(b);
 return mat3(c,0.0,-s,0.0,1.0,0.0,s,0.0,c)*mat3(1.0,0.0,0.0,0.0,v,w,0.0,-w,v);
}
float objectDistance(vec3 p){
 float side=min(u_resolution.x,u_resolution.y);
 vec2 uv=p.xy*side/u_resolution+0.5;
 vec2 safeUV=clamp(uv,vec2(0.001),vec2(0.999));
 float planar=-texture2D(u_shape,safeUV).r/side;
 planar+=length((uv-safeUV)*u_resolution/side);
 float depth=u_thickness*0.005;
 float bevel=min(u_rounding*0.01,depth*0.95);
 vec2 q=vec2(planar+bevel,abs(p.z)-depth+bevel);
 return min(max(q.x,q.y),0.0)+length(max(q,0.0))-bevel;
}
float panel(float distanceToCenter,float width){
 float x=abs(distanceToCenter)/max(width*u_envCoverage,0.0001);
 return exp(-pow(min(x,20.0),mix(10.0,2.0,u_envSoftness)));
}
vec3 environment(vec3 r){
 r=turn(radians(u_envRotation),radians(u_envTilt))*r;
 float a=radians(u_envAngle);
 r.xy=mat2(cos(a),-sin(a),sin(a),cos(a))*r.xy;
 float band=r.x*0.72+r.y*0.45;
 float cyan=panel(band-0.26,0.19);
 float white=panel(band-0.52,0.047);
 float pink=panel(band+0.46,0.067);
 float lower=panel(r.y+0.65,0.08);
 vec3 base=vec3(0.006,0.014,0.022)+u_tint*(0.22+0.5*(r.y*0.5+0.5));
 vec3 lights=cyan*vec3(0.13,0.62,0.74)+white*vec3(1.5,1.65,1.7)
  +pink*vec3(0.68,0.34,0.57)+lower*vec3(0.35,0.86,0.91);
 float facing=dot(r,normalize(vec3(-0.7,0.2,0.68)));
 float boundary=1.0-2.0*u_envDarkCoverage;
 float softness=mix(0.008,0.20,u_envSoftness);
 float flag=smoothstep(boundary-softness,boundary+softness,facing);
 return (base+lights*u_envLight)*(1.0-flag*u_envDark);
}
void main(){
 float side=min(u_resolution.x,u_resolution.y);
 vec2 xy=(gl_FragCoord.xy-u_resolution*0.5)/side/max(u_scale,0.1);
 float yaw=radians(u_rotation)+u_time*u_speed*0.104719755;
 mat3 rot=turn(-yaw,-radians(u_tilt));
 vec3 origin=rot*vec3(xy,1.5);
 vec3 ray=rot*vec3(0.0,0.0,-1.0);
 float epsilon=0.65/side;

 vec3 boxH=vec3(u_resolution/side*0.5,u_thickness*0.005)+4.0/side;
 vec3 rd=ray+vec3(1e-7)*step(abs(ray),vec3(1e-7));
 vec3 b0=(-boxH-origin)/rd,b1=(boxH-origin)/rd;
 vec3 bn=min(b0,b1),bf=max(b0,b1);
 float tFar=min(min(bf.x,bf.y),bf.z);
 float travel=4.0;
 if(max(max(bn.x,bn.y),bn.z)<tFar&&tFar>0.0){
  travel=0.0;
  for(int i=0;i<80;i++){
   vec3 p=origin+ray*travel;
   float distanceToSurface=objectDistance(p);
   if(distanceToSurface<epsilon)break;
   travel+=max(distanceToSurface*0.65,epsilon*0.25);
   if(travel>3.0)break;
   if(travel>tFar){travel=4.0;break;}
  }
 }
 vec3 p=origin+ray*travel;
 float hit=0.0;
 if(travel<3.0){
 float d=objectDistance(p);
 hit=1.0-smoothstep(epsilon,epsilon*2.5,d);
 }
 vec3 col=vec3(0.0);
 if(hit>0.0){
 float e=1.0/side;
 vec3 n=normalize(vec3(
 objectDistance(p+vec3(e,0,0))-objectDistance(p-vec3(e,0,0)),
 objectDistance(p+vec3(0,e,0))-objectDistance(p-vec3(0,e,0)),
 objectDistance(p+vec3(0,0,e))-objectDistance(p-vec3(0,0,e)))+vec3(0.000001));
 vec3 reflected=reflect(ray,n);
 vec3 worldReflection=vec3(dot(rot[0],reflected),dot(rot[1],reflected),dot(rot[2],reflected));
 float fresnel=pow(1.0-max(dot(n,-ray),0.0),3.0);
 col=environment(worldReflection)*(0.7+0.65*fresnel);
 col+=u_tint*0.08;
 }
 float floorY=u_groundLevel*0.01;
 vec3 floorPoint=vec3(xy.x,floorY,(xy.y-floorY)/0.35);
 float lightAngle=radians(u_shadowDirection);
 vec3 light=normalize(vec3(cos(lightAngle)*0.85,2.8,sin(lightAngle)*0.85));
 float penumbra=exp2(mix(5.0,2.0,u_shadowSoftness));
 float shadowAlpha=0.0;
 if(hit<1.0){

 vec3 fo=rot*floorPoint,lo=rot*light;
 vec3 slope=abs(lo)-1.0/penumbra;
 vec3 axisStop=(boxH-sign(lo)*fo)/max(slope,1e-6)+step(slope,vec3(0.0))*1e6;
 float stopAt=min(min(axisStop.x,axisStop.y),axisStop.z);
 float visibility=1.0;
 float st=0.003;
 if(u_shadowStrength>0.0)for(int j=0;j<40;j++){
  if(st>=stopAt||visibility<=0.0)break;
  float sd=objectDistance(rot*(floorPoint+light*st));
  visibility=min(visibility,penumbra*max(sd,0.0)/max(st,0.001));
  st+=clamp(sd,0.008,0.055);
 }
 visibility=clamp(visibility,0.0,1.0);
 visibility=visibility*visibility*(3.0-2.0*visibility);
 float spread=u_contactSpread*0.01;
 float occlusion=0.0;
 float totalWeight=1.0;

 float maxReach=spread*0.81+0.001;
 if(u_contactStrength>0.0&&objectDistance(fo)<maxReach*2.0){
 totalWeight=0.0;
 for(int k=0;k<6;k++){
  float az=float(k)*1.04719755;
  vec3 hemisphere=normalize(vec3(cos(az)*0.65,1.0,sin(az)*0.65));
  for(int l=0;l<5;l++){
   float fraction=(float(l)+0.5)/5.0;
   float reach=spread*fraction*fraction+0.001;
   float nearSurface=objectDistance(rot*(floorPoint+hemisphere*reach));
   float weight=exp(-fraction*2.0);
   occlusion+=clamp(1.0-nearSurface/reach,0.0,1.0)*weight;
   totalWeight+=weight;
  }
 }
 }
 float ao=clamp(occlusion/max(totalWeight,0.001),0.0,1.0);
 float contact=pow(ao,0.8)*u_contactStrength;
 float castShadow=(1.0-visibility)*u_shadowStrength;
 shadowAlpha=1.0-(1.0-contact)*(1.0-castShadow);
 }
 vec2 edge=min(gl_FragCoord.xy,u_resolution-gl_FragCoord.xy)/side;
 shadowAlpha*=smoothstep(0.0,0.045,min(edge.x,edge.y));
 vec3 rgb=clamp(col,0.0,1.0)*hit+u_shadowTint*shadowAlpha*(1.0-hit);
 gl_FragColor=vec4(rgb,hit+shadowAlpha*(1.0-hit));
}
