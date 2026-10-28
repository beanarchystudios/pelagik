precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @sdf */
uniform sampler2D u_shape;
/** @content */
uniform sampler2D u_content;
/** @backdrop */
uniform sampler2D u_backdrop;
/**
 * @label Camera yaw
 * @default 0
 * @range -180, 180
 */
uniform float u_cameraYaw;
/**
 * @label Camera pitch
 * @default 10
 * @range 5, 85
 */
uniform float u_cameraPitch;
/**
 * @label Camera roll
 * @default 0
 * @range -180, 180
 */
uniform float u_cameraRoll;
/**
 * @label Object yaw
 * @default 0
 * @range -180, 180
 */
uniform float u_objectYaw;
/**
 * @label Object pitch
 * @default 0
 * @range -180, 180
 */
uniform float u_objectPitch;
/**
 * @label Object roll
 * @default 0
 * @range -180, 180
 */
uniform float u_objectRoll;
/**
 * @label Depth
 * @default 300
 * @range 10, 600
 */
uniform float u_depth;
/**
 * @label Rounding
 * @default 130
 * @range 1, 300
 */
uniform float u_round;
/**
 * @label Tint
 * @color
 * @default #ff2416
 */
uniform vec3 u_tint;
/**
 * @label Tint mix
 * @default 0
 * @range 0, 1
 */
uniform float u_tintMix;
/**
 * @label Density
 * @default 0.45
 * @range 0, 4
 */
uniform float u_density;
/**
 * @label Inner glow
 * @default 0.8
 * @range 0, 1.5
 */
uniform float u_glow;
/**
 * @label See through
 * @default 0.5
 * @range 0, 1
 */
uniform float u_seeThrough;
/**
 * @label Refraction
 * @default 1.4
 * @range 1, 2
 */
uniform float u_ior;
/**
 * @label Reflection
 * @default 1
 * @range 0, 2
 */
uniform float u_reflect;
/**
 * @label Gloss
 * @default 0.65
 * @range 0, 1
 */
uniform float u_gloss;
/**
 * @label Light size
 * @default 0.5
 * @range 0, 1
 */
uniform float u_lightSize;
/**
 * @label Studio rotation
 * @default 0
 * @range -180, 180
 */
uniform float u_studio;
/**
 * @label Exposure
 * @default 1
 * @range 0.5, 1.5
 */
uniform float u_exposure;
/**
 * @label Shadow strength
 * @default 0.65
 * @range 0, 1
 */
uniform float u_shadow;
/**
 * @label Shadow softness
 * @default 0.9
 * @range 0, 1
 */
uniform float u_shadowSoftness;
/**
 * @label Shadow direction
 * @default 125
 * @range -180, 180
 */
uniform float u_shadowDirection;
/**
 * @label Shadow elevation
 * @default 70
 * @range 25, 85
 */
uniform float u_shadowElevation;
/**
 * @label Shadow glow
 * @default 0.6
 * @range 0, 1
 */
uniform float u_caustic;
/**
 * @label Contact strength
 * @default 0.8
 * @range 0, 1
 */
uniform float u_contactStrength;
/**
 * @label Contact spread
 * @default 60
 * @range 5, 160
 */
uniform float u_contactSpread;
/**
 * @label Ground level
 * @default 0.335
 * @range 0, 0.8
 */
uniform float u_ground;
/**
 * @label Ground opacity
 * @default 0
 * @range 0, 1
 */
uniform float u_stage;
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
vec3 keyDir;
vec3 boxExt;
mat3 rotationX(float a){float c=cos(a),s=sin(a);return mat3(1.0,0.0,0.0,0.0,c,s,0.0,-s,c);}
mat3 rotationY(float a){float c=cos(a),s=sin(a);return mat3(c,0.0,-s,0.0,1.0,0.0,s,0.0,c);}
mat3 rotationZ(float a){float c=cos(a),s=sin(a);return mat3(c,s,0.0,-s,c,0.0,0.0,0.0,1.0);}
float hash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}

vec3 objectPoint(vec3 p){
 float side=min(u_resolution.x,u_resolution.y);
 vec3 pivot=vec3(0.0,0.0,-u_depth/side*0.5);
 return worldToObject*(p-pivot)+pivot;
}
vec2 objectUv(vec3 p){
 float side=min(u_resolution.x,u_resolution.y);
 return p.xy*side/u_resolution+0.5;
}
float solid(vec3 worldPoint){
 vec3 p=objectPoint(worldPoint);
 float side=min(u_resolution.x,u_resolution.y);
 vec2 uv=objectUv(p);
 vec2 safe=clamp(uv,vec2(0.001),vec2(0.999));
 float planar=-texture2D(u_shape,safe).r/side+length((uv-safe)*u_resolution/side);
 float halfDepth=max(u_depth/side*0.5,0.0005);
 float bevel=min(u_round/side,halfDepth*0.96);
 vec2 q=vec2(planar+bevel,abs(p.z+halfDepth)-halfDepth+bevel);
 return min(max(q.x,q.y),0.0)+length(max(q,0.0))-bevel;
}

float boxDist(vec3 p){return length(max(abs(p+vec3(0.0,0.0,boxExt.z))-boxExt,0.0));}
vec3 normalAt(vec3 p){
 float e=0.7/min(u_resolution.x,u_resolution.y);
 return normalize(vec3(solid(p+vec3(e,0,0))-solid(p-vec3(e,0,0)),solid(p+vec3(0,e,0))-solid(p-vec3(0,e,0)),solid(p+vec3(0,0,e))-solid(p-vec3(0,0,e)))+vec3(0.0000001));
}
float softLight(vec3 r,vec3 d,float angle,float edge){
 return smoothstep(cos(angle+edge),cos(angle),dot(r,d));
}
vec3 studio(vec3 r){
 float a=radians(u_studio);
 vec3 s=r;
 s.xz=mat2(cos(a),-sin(a),sin(a),cos(a))*s.xz;
 float edge=radians(mix(24.0,4.0,u_gloss));
 float base=mix(0.62,1.1,smoothstep(-0.85,0.55,r.y));
 float flag=smoothstep(0.15,-0.55,r.y)*smoothstep(-0.3,0.6,r.z);
 base*=1.0-0.45*flag;
 float key=softLight(r,keyDir,radians(mix(10.0,30.0,u_lightSize)),edge);
 vec3 rimDir=normalize(vec3(0.85,0.35,-0.45));
 float rim=softLight(s,rimDir,radians(7.0+8.0*u_lightSize),edge*0.7);
 vec3 fillDir=normalize(vec3(-0.2,0.9,0.4));
 float fill=softLight(s,fillDir,radians(26.0),radians(18.0));
 return vec3(base)+vec3(1.0,0.99,0.97)*key*55.0+vec3(0.96,0.98,1.0)*rim*18.0+vec3(0.9)*fill;
}
void main(){
 worldToObject=rotationY(-radians(u_objectYaw))*rotationX(-radians(u_objectPitch))*rotationZ(-radians(u_objectRoll));
 float azimuth=radians(u_shadowDirection);
 float elevation=radians(u_shadowElevation);
 keyDir=vec3(cos(azimuth)*cos(elevation),sin(elevation),sin(azimuth)*cos(elevation));
 float side=min(u_resolution.x,u_resolution.y);
 vec2 xy=(gl_FragCoord.xy-u_resolution*0.5)/side;
 float yaw=radians(u_cameraYaw);
 float pitch=radians(clamp(u_cameraPitch,5.0,85.0));
 float roll=radians(u_cameraRoll);
 vec3 baseRight=vec3(cos(yaw),0.0,-sin(yaw));
 vec3 baseUp=vec3(-sin(pitch)*sin(yaw),cos(pitch),-sin(pitch)*cos(yaw));
 vec3 right=baseRight*cos(roll)+baseUp*sin(roll);
 vec3 up=baseUp*cos(roll)-baseRight*sin(roll);
 vec3 view=vec3(cos(pitch)*sin(yaw),sin(pitch),cos(pitch)*cos(yaw));
 vec3 origin=right*xy.x+up*xy.y+view*1.5;
 vec3 ray=-view;
 float epsilon=0.35/side;
 boxExt=vec3(u_resolution/side*0.5,max(u_depth/side*0.5,0.0005));
 vec3 oO=objectPoint(origin),rO=worldToObject*ray;
 float t=0.0;
 for(int i=0;i<112;i++){
  float d=boxDist(oO+rO*t)-4.0/side;
  if(d<0.121)d=solid(origin+ray*t);
  float going=step(epsilon,d)*step(t,3.0);
  t+=clamp(d*0.75,epsilon*0.3,0.09)*going;
  if(going==0.0)break;
 }
 vec3 p=origin+ray*t;
 float distanceToSolid=solid(p);
 float hit=(1.0-smoothstep(epsilon,epsilon*2.4,distanceToSolid))*(1.0-step(3.0,t));
 vec2 uvC=clamp(objectUv(objectPoint(p)),vec2(0.001),vec2(0.999));
 vec4 content=texture2D(u_content,uvC);
 vec3 bodyColor=content.rgb/max(content.a,0.02);
 bodyColor=mix(u_tint,bodyColor,smoothstep(0.0,0.3,content.a));
 bodyColor=mix(bodyColor,u_tint,u_tintMix);
 bodyColor=clamp(bodyColor,0.0,1.0)/max(max(bodyColor.r,max(bodyColor.g,bodyColor.b)),0.05);

 vec3 sigma=(vec3(1.0)-bodyColor*0.92)*vec3(1.0,1.0,1.3)*u_density*30.0;
 vec3 jelly=vec3(0.0);
 if(hit>0.0){
 vec3 n=normalAt(p);
 float ior=max(u_ior,1.0);
 float f0=pow((ior-1.0)/(ior+1.0),2.0);
 float ndv=clamp(dot(n,view),0.0,1.0);
 float fresnel=clamp((f0+(1.0-f0)*pow(1.0-ndv,5.0))*u_reflect,0.0,1.0);

 vec3 dIn=refract(ray,n,1.0/ior);
 dIn=normalize(mix(ray,dIn,step(0.5,dot(dIn,dIn))));
 float tIn=0.0;
 vec3 q0=p+dIn*epsilon*4.0;
 for(int j=0;j<48;j++){
  float d=solid(q0+dIn*tIn);
  if(d>0.0)break;
  tIn+=max(-d*0.8,0.002);
 }
 vec3 pOut=q0+dIn*tIn;
 float thick=(tIn+epsilon*4.0)*hit;
 vec3 nOut=normalAt(pOut);
 vec3 dOut=refract(dIn,-nOut,ior);
 dOut=normalize(mix(dIn,dOut,step(0.5,dot(dOut,dOut))));
 float exitF=f0+(1.0-f0)*pow(1.0-clamp(dot(nOut,-dIn),0.0,1.0),5.0);

 vec2 screen=vec2(dot(pOut,right),dot(pOut,up))*side+u_resolution*0.5;
 vec2 shift=vec2(dot(dOut,right),dot(dOut,up))*0.3*side;
 vec4 bd=texture2D(u_backdrop,(screen+shift)/u_resolution);
 vec3 behindCanvas=bd.rgb+(1.0-bd.a)*vec3(0.96,0.95,0.94);
 vec3 behindStudio=min(studio(dOut),vec3(1.6));
 vec3 behind=mix(behindStudio,behindCanvas,u_seeThrough);

 vec3 transmit=exp(-sigma*thick);
 float wrap=clamp(dot(n,keyDir)*0.6+0.4,0.0,1.0);
 vec3 scatter=pow(bodyColor,vec3(0.55))*vec3(1.0,1.0,0.8)*u_glow*wrap*(1.0-exp(-thick*14.0))*0.6;
 vec3 body=behind*transmit*(1.0-exitF*0.5)+scatter;

 vec3 reflected=reflect(ray,n);
 vec3 mirror=studio(reflected)*fresnel;
 vec3 h=normalize(keyDir+view);
 float spec=pow(clamp(dot(n,h),0.0,1.0),mix(30.0,900.0,u_gloss*u_gloss));
 float fh=f0+(1.0-f0)*pow(1.0-clamp(dot(h,view),0.0,1.0),5.0);
 mirror+=spec*fh*u_reflect*mix(8.0,40.0,u_gloss);
 float rimShape=pow(1.0-ndv,mix(6.0,1.5,u_rimWidth));
 vec3 rim=u_rimColor*rimShape*u_rim;
 vec3 core=pow(bodyColor,vec3(0.6))*u_core*(1.0-exp(-thick*10.0))*0.7;
 jelly=body*(1.0-fresnel)+mirror+rim+core;
 jelly=clamp(jelly*u_exposure,0.0,1.0);
 }
 vec3 ground=vec3(0.0);
 float groundAlpha=0.0;
 if(hit<1.0){
 float floorY=(u_ground-0.5)*u_resolution.y/side;
 float floorT=(origin.y-floorY)/max(view.y,0.05);
 vec3 floorPoint=origin-view*floorT;
 float penumbra=exp2(mix(5.5,0.8,u_shadowSoftness));
 float visibility=1.0;
 float st=0.002;
 vec3 fO=objectPoint(floorPoint),kO=worldToObject*keyDir;
 for(int j=0;j<36;j++){
  if(u_shadow==0.0||visibility==0.0)break;
  float d=boxDist(fO+kO*st)-4.0/side;
  if(d<max(0.065,max(st,0.001)/penumbra)){
   d=solid(floorPoint+keyDir*st);
   visibility=min(visibility,penumbra*max(d,0.0)/max(st,0.001));
  }
  st+=clamp(d,0.006,0.065);
 }
 visibility=clamp(visibility,0.0,1.0);
 visibility=visibility*visibility*(3.0-2.0*visibility);
 float lightThick=0.0;
 for(int k=0;k<24;k++){
  if(u_shadow*u_caustic==0.0)break;
  float sk=0.01+float(k)*0.022;
  if(boxDist(fO+kO*sk)-4.0/side>=0.03)continue;
  float d=solid(floorPoint+keyDir*sk);
  lightThick+=smoothstep(0.03,-0.03,d)*0.022;
 }
 vec3 caustic=exp(-sigma*lightThick)*u_caustic*0.85*smoothstep(0.0,0.03,lightThick);
 float ao=0.0;
 float totalWeight=0.0;
 float spread=u_contactSpread/side;
 for(int k=0;k<8;k++){
  float angle=float(k)*0.785398163;
  vec3 hemisphere=normalize(vec3(cos(angle)*0.75,1.0,sin(angle)*0.75));
  for(int m=0;m<5;m++){
   float fraction=(float(m)+0.5)/5.0;
   float reach=0.7/side+spread*fraction*fraction;
   float weight=exp(-fraction*1.5);
   totalWeight+=weight;
   vec3 ap=floorPoint+hemisphere*reach;
   if(u_contactStrength==0.0||boxDist(objectPoint(ap))-4.0/side>=reach)continue;
   float d=solid(ap);
   float proximity=clamp(1.0-d/reach,0.0,1.0);
   ao+=proximity*weight;
  }
 }
 ao=clamp(ao/max(totalWeight,0.001),0.0,1.0);
 float contact=pow(ao,0.85)*u_contactStrength;
 vec3 lit=mix(vec3(1.0),vec3(visibility)+(1.0-visibility)*caustic,u_shadow);
 vec3 floorMul=lit*(1.0-contact);
 vec2 edge=min(gl_FragCoord.xy,u_resolution-gl_FragCoord.xy)/side;
 floorMul=mix(vec3(1.0),floorMul,smoothstep(0.0,0.05,min(edge.x,edge.y)));
 float shadowAlpha=1.0-min(floorMul.r,min(floorMul.g,floorMul.b));
 vec3 shadowColor=floorMul-(1.0-shadowAlpha);
 float paper=0.95+0.03*exp(-dot(xy,xy)*5.0);
 vec3 stageColor=vec3(paper,paper*0.985,paper*0.97)*floorMul;
 ground=mix(shadowColor,stageColor,u_stage);
 groundAlpha=mix(shadowAlpha,1.0,u_stage);
 }
 vec3 col=mix(ground,jelly,hit)+(hash(gl_FragCoord.xy)-0.5)*0.004;
 gl_FragColor=vec4(col,hit+groundAlpha*(1.0-hit));
}
