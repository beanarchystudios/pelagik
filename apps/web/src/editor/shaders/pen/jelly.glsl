precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @sdf */
uniform sampler2D u_shape;
/** @backdrop */
uniform sampler2D u_backdrop;
/**
 * @label Colour
 * @color
 * @default #d80e66
 */
uniform vec3 u_color;
/**
 * @label Density
 * @default 1
 * @range 0.2, 3
 */
uniform float u_density;
/**
 * @label Depth
 * @default 240
 * @range 10, 400
 */
uniform float u_depth;
/**
 * @label Rounding
 * @default 70
 * @range 1, 120
 */
uniform float u_rounding;
/**
 * @label Camera elevation
 * @default 16
 * @range 0, 60
 */
uniform float u_camPitch;
/**
 * @label Object yaw
 * @default -24
 * @range -180, 180
 */
uniform float u_yaw;
/**
 * @label Object pitch
 * @default 0
 * @range -180, 180
 */
uniform float u_pitch;
/**
 * @label Object roll
 * @default -7
 * @range -180, 180
 */
uniform float u_roll;
/**
 * @label Perspective
 * @default 0.3
 * @range 0, 1
 */
uniform float u_perspective;
/**
 * @label Scale
 * @default 1
 * @range 0.4, 1.4
 */
uniform float u_scale;
/**
 * @label Refraction
 * @default 1.4
 * @range 1, 2
 */
uniform float u_ior;
/**
 * @label Reflections
 * @default 1
 * @range 0, 2
 */
uniform float u_gloss;
/**
 * @label Scattering
 * @default 0.6
 * @range 0, 2
 */
uniform float u_scatter;
/**
 * @label Scatter depth
 * @default 150
 * @range 10, 400
 */
uniform float u_scatterDepth;
/**
 * @label Light direction
 * @default 10
 * @range -180, 180
 */
uniform float u_lightDir;
/**
 * @label Light elevation
 * @default 65
 * @range 5, 85
 */
uniform float u_lightElev;
/**
 * @label Bubbles
 * @default 0.5
 * @range 0, 1
 */
uniform float u_bubbles;
/**
 * @label Bubble size
 * @default 5
 * @range 1, 12
 */
uniform float u_bubbleSize;
/**
 * @label Shadow strength
 * @default 0.5
 * @range 0, 1
 */
uniform float u_shadow;
/**
 * @label Shadow softness
 * @default 0.7
 * @range 0, 1
 */
uniform float u_shadowSoft;
/**
 * @label Floor level
 * @default 0.06
 * @range 0, 0.8
 */
uniform float u_ground;
/**
 * @label Edge light
 * @default 1
 * @range 0, 2.5
 */
uniform float u_edgeLight;
/**
 * @label Edge width
 * @default 0.5
 * @range 0, 1
 */
uniform float u_edgeWidth;
/**
 * @label Rim glow
 * @default 0
 * @range 0, 3
 */
uniform float u_rim;
/**
 * @label Rim width
 * @default 0.4
 * @range 0, 1
 */
uniform float u_rimWidth;
/**
 * @label Rim colour
 * @color
 * @default #ffffff
 */
uniform vec3 u_rimColor;
/**
 * @label Core glow
 * @default 0
 * @range 0, 1.5
 */
uniform float u_core;
mat3 worldToObject;
vec3 lightDir;
vec3 camPos,camFwd,camRight,camUp;
float side;
vec3 boxExt;

mat3 rotationX(float a){float c=cos(a),s=sin(a);return mat3(1.0,0.0,0.0,0.0,c,s,0.0,-s,c);}
mat3 rotationY(float a){float c=cos(a),s=sin(a);return mat3(c,0.0,-s,0.0,1.0,0.0,s,0.0,c);}
mat3 rotationZ(float a){float c=cos(a),s=sin(a);return mat3(c,s,0.0,-s,c,0.0,0.0,0.0,1.0);}
vec3 hash3(vec3 p){
 p=fract(p*vec3(0.1031,0.1030,0.0973));
 p+=dot(p,p.yxz+33.33);
 return fract((p.xxy+p.yxx)*p.zyx);
}
float solid(vec3 worldPoint){
 vec3 p=worldToObject*worldPoint/u_scale;
 vec2 uv=p.xy*side/u_resolution+0.5;
 vec2 safe=clamp(uv,vec2(0.001),vec2(0.999));
 float planar=-texture2D(u_shape,safe).r/side+length((uv-safe)*u_resolution/side);
 float halfDepth=max(u_depth/side*0.5,0.0005);
 float bevel=min(u_rounding/side,halfDepth*0.98);
 vec2 q=vec2(planar+bevel,abs(p.z)-halfDepth+bevel);
 return (min(max(q.x,q.y),0.0)+length(max(q,0.0))-bevel)*u_scale;
}

float boxDist(vec3 p){return length(max(abs(p)-boxExt,0.0))*u_scale;}
vec3 normalAt(vec3 p){
 float e=0.7/side;
 return normalize(vec3(
  solid(p+vec3(e,0,0))-solid(p-vec3(e,0,0)),
  solid(p+vec3(0,e,0))-solid(p-vec3(0,e,0)),
  solid(p+vec3(0,0,e))-solid(p-vec3(0,0,e)))+vec3(0.0000001));
}
vec3 studio(vec3 r,float keyScale){
 float sky=r.y*0.5+0.5;
 vec3 col=vec3(mix(0.78,1.0,sky));
 float ang=acos(clamp(dot(r,lightDir),-1.0,1.0));
 col+=vec3(1.0,0.99,0.97)*keyScale*(10.0*exp(-pow(ang/1.0,2.0))+34.0*exp(-pow(ang/0.3,2.0)));
 vec3 fillDir=normalize(vec3(-lightDir.x,0.35,0.8));
 float fang=acos(clamp(dot(r,fillDir),-1.0,1.0));
 col+=vec3(0.5)*exp(-pow(fang/0.5,2.0));
 return col;
}
vec3 wallColor(vec2 uv){
 vec4 bd=texture2D(u_backdrop,uv);
 return bd.rgb+(1.0-bd.a)*vec3(0.93);
}
vec2 screenUV(vec3 p,float camZ){
 vec3 v=p-camPos;
 vec2 s=vec2(dot(v,camRight),dot(v,camUp))*camZ/max(dot(v,camFwd),0.05);
 return s*side/u_resolution+0.5;
}
void main(){
 side=min(u_resolution.x,u_resolution.y);
 worldToObject=rotationY(-radians(u_yaw))*rotationX(-radians(u_pitch))*rotationZ(-radians(u_roll));
 float az=radians(u_lightDir),el=radians(u_lightElev);
 lightDir=normalize(vec3(sin(az)*cos(el),sin(el),cos(az)*cos(el)));
 vec2 xy=(gl_FragCoord.xy-u_resolution*0.5)/side;
 float camZ=2.5/max(u_perspective,0.03);
 float pitch=radians(u_camPitch);
 camPos=vec3(0.0,sin(pitch),cos(pitch))*camZ;
 camFwd=-normalize(camPos);
 camRight=vec3(1.0,0.0,0.0);
 camUp=cross(camRight,camFwd);
 vec3 origin=camPos;
 vec3 ray=normalize(camRight*xy.x+camUp*xy.y+camFwd*camZ);
 float epsilon=0.35/side;
 boxExt=vec3(u_resolution/side*0.5,max(u_depth/side*0.5,0.0005))+4.0/side;
 vec3 oO=worldToObject*origin/u_scale,rO=worldToObject*ray/u_scale;
 rO=mix(vec3(0.000001),rO,step(0.000001,abs(rO)));
 vec3 tA=(-boxExt-oO)/rO,tB=(boxExt-oO)/rO;
 vec3 tMin=min(tA,tB),tMax=max(tA,tB);
 float tFar=min(min(tMax.x,tMax.y),tMax.z);
 bool miss=max(max(tMin.x,tMin.y),tMin.z)>tFar;
 float t=camZ-1.4;
 float tEnd=camZ+1.4;
 for(int i=0;i<80;i++){
  if(miss||t>tEnd)break;
  if(t>tFar){miss=true;break;}
  float d=boxDist(oO+rO*t);
  if(d<0.13)d=solid(origin+ray*t);
  if(d<epsilon)break;
  t+=clamp(d*0.8,epsilon*0.3,0.1);
 }
 vec3 p1=origin+ray*t;
 float hit=(1.0-smoothstep(epsilon,epsilon*2.4,solid(p1)))*(1.0-step(tEnd,t));
 if(miss)hit=0.0;
 float ior=max(u_ior,1.0);
 vec3 tint=clamp(u_color,vec3(0.02),vec3(0.995));
 float depthUnits=max(u_depth/side,0.002);
 vec3 absorb=-log(tint)/depthUnits*u_density;
 vec4 objOut=vec4(0.0);
 vec3 n1=normalAt(p1);
 if(hit>0.0){
 p1-=n1*solid(p1);
 p1-=n1*solid(p1);
 vec3 d1=refract(ray,n1,1.0/ior);
 d1=normalize(mix(ray,d1,step(0.0001,dot(d1,d1))));
 vec3 q=p1-n1*epsilon*1.5;
 for(int i=0;i<48;i++){
  float dIn=-solid(q);
  if(dIn<epsilon*0.5)break;
  q+=d1*clamp(dIn*0.8,epsilon*0.4,0.08);
 }
 vec3 p2=q;
 float chord=max(length(p2-p1),0.0);
 vec3 n2=normalAt(p2);
 vec3 d2=refract(d1,-n2,ior);
 vec3 bounce=reflect(d1,n2);
 float cosIn=clamp(dot(-d1,n2),0.0,1.0);
 float sinOut2=ior*ior*(1.0-cosIn*cosIn);
 float tir=smoothstep(0.82,1.0,sinOut2);
 d2=mix(d2,bounce,1.0-step(0.0001,dot(d2,d2)));
 d2=normalize(mix(d2,bounce,tir)+vec3(0.0000001));
 vec3 trans=exp(-absorb*chord*(1.0+tir*0.8));
 float wallZ=-0.6;
 float reach=(p2.z-wallZ)/max(-d2.z,0.02);
 vec3 landing=p2+d2*reach;
 vec3 throughWall=wallColor(screenUV(landing,camZ));
 vec3 throughEnv=studio(d2,0.25);
 float toWall=smoothstep(0.0,-0.35,d2.z)*(1.0-tir);
 vec3 behind=mix(throughEnv,throughWall,toWall);
 float f0=pow((ior-1.0)/(ior+1.0),2.0);
 float cosv=max(dot(n1,-ray),0.0);
 float edgeMask=pow(1.0-cosv,mix(9.0,2.5,u_edgeWidth));
 float fresnel=f0+(1.0-f0)*edgeMask*u_edgeLight;
 behind*=mix(1.0,u_edgeLight,edgeMask);
 vec3 reflection=studio(reflect(ray,n1),1.0)*fresnel*u_gloss;
 float scatterReach=max(u_scatterDepth/side,0.004);
 float sigma=2.5/scatterReach;
 vec3 scat=vec3(0.0);
 for(int k=0;k<6;k++){
  float s=chord*(float(k)+0.5)/6.0;
  vec3 m=p1+d1*s;
  float thick=0.0;
  float ds=scatterReach/5.0;
  for(int j=1;j<=6;j++){
   float dm=solid(m+lightDir*ds*float(j));
   thick+=clamp(0.5-dm/ds,0.0,1.0)*ds;
  }
  float lightT=exp(-thick*sigma);
  vec3 viewT=exp(-absorb*s);
  scat+=lightT*viewT/6.0;
 }
 scat*=1.0-exp(-chord/scatterReach);
 float wrap=dot(n1,lightDir)*0.5+0.5;
 vec3 glowTint=mix(tint,vec3(1.0),0.1);
 vec3 sss=glowTint*scat*u_scatter*0.9*(0.25+0.75*wrap);
 float rimShape=pow(1.0-cosv,mix(6.0,1.5,u_rimWidth));
 vec3 rim=u_rimColor*rimShape*u_rim;
 vec3 core=pow(tint,vec3(0.6))*u_core*(1.0-exp(-chord/depthUnits*2.5))*0.7;
 vec3 col=trans*behind*(1.0-fresnel)+sss+reflection+rim+core;
 vec3 p1o=worldToObject*p1;
 vec3 d1o=normalize(worldToObject*d1+vec3(0.0000001));
 float cellSize=max(u_bubbleSize,1.0)*9.0/side;
 float radius0=max(u_bubbleSize,1.0)/side;
 float stepLen=chord/24.0;
 float transmit=1.0;
 vec3 bubbleCol=vec3(0.0);
 vec3 sparkDir=normalize(worldToObject*lightDir);
 float flatFace=smoothstep(0.97,0.995,abs((worldToObject*n1).z));
 for(int i=0;i<24;i++){
  float s=stepLen*(float(i)+0.5);
  vec3 cell=floor((p1o+d1o*s)/cellSize);
  vec3 h=hash3(cell+vec3(7.0,3.0,11.0));
  vec3 center=(cell+0.15+0.7*h)*cellSize;
  float rad=radius0*(0.5+0.5*h.x);
  float tc=dot(center-p1o,d1o);
  float owned=step(float(i)*stepLen,tc)*step(tc,float(i+1)*stepLen)*step(h.z,u_bubbles*0.6)*step(rad*1.5,tc)*step(tc,chord-rad*1.5)*flatFace;
  vec3 offset=p1o+d1o*tc-center;
  float u=length(offset)/rad;
  float rim=smoothstep(0.5,0.8,u)*(1.0-smoothstep(0.85,1.05,u));
  float core=1.0-smoothstep(0.0,0.45,u);
  float spark=exp(-dot(offset-sparkDir*rad*0.35,offset-sparkDir*rad*0.35)/(rad*rad*0.08));
  vec3 viewT=exp(-absorb*tc);
  float a=owned*max(rim*0.2,max(core,spark));
  vec3 c=mix(trans*behind*0.45,mix(vec3(1.0)*viewT*2.2,vec3(1.0),spark),max(core,spark));
  bubbleCol+=transmit*a*c;
  transmit*=1.0-a;
 }
 col=col*transmit+bubbleCol;
 objOut=vec4(clamp(col,0.0,1.0),1.0);
 }
 vec4 wallOut=vec4(0.0);
 if(hit<1.0){
 float floorY=(u_ground-0.5)*u_resolution.y/side;
 float tF=(floorY-origin.y)/min(ray.y,-0.0001);
 float onFloor=step(0.0,-ray.y)*step(0.0,tF);
 vec3 floorPoint=origin+ray*tF;
 float through=0.0;
 float s=0.0;
 vec3 fO=worldToObject*floorPoint/u_scale,lO=worldToObject*lightDir/u_scale;
 for(int i=0;i<24;i++){
  if(onFloor*u_shadow==0.0)break;
  float ds=0.07;
  s+=ds;
  float pen=max(0.004,u_shadowSoft*0.5*s);
  if(boxDist(fO+lO*s)>=0.5*pen)continue;
  vec3 wp=floorPoint+lightDir*s;
  through+=clamp(0.5-solid(wp)/pen,0.0,1.0)*ds;
 }
 vec3 shadowT=exp(-absorb*through*0.9)*(1.0-0.3*clamp(through/depthUnits,0.0,1.0));
 shadowT=mix(vec3(1.0),shadowT,u_shadow*onFloor);
 float minT=min(shadowT.r,min(shadowT.g,shadowT.b));
 vec3 wallBase=wallColor(gl_FragCoord.xy/u_resolution);
 wallOut=vec4(wallBase*(shadowT-minT),1.0-minT);
 }
 gl_FragColor=mix(wallOut,objOut,hit);
}
