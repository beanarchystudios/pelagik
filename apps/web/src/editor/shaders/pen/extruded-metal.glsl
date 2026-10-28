precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @sdf */
uniform sampler2D u_shape;
/**
 * @label Camera yaw
 * @default 40
 * @range -180, 180
 */
uniform float u_cameraYaw;
/**
 * @label Camera pitch
 * @default 26.62
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
mat3 worldToObject;
mat3 rotationX(float a){float c=cos(a),s=sin(a);return mat3(1.0,0.0,0.0,0.0,c,s,0.0,-s,c);}
mat3 rotationY(float a){float c=cos(a),s=sin(a);return mat3(c,0.0,-s,0.0,1.0,0.0,s,0.0,c);}
mat3 rotationZ(float a){float c=cos(a),s=sin(a);return mat3(c,s,0.0,-s,c,0.0,0.0,0.0,1.0);}
/**
 * @label Depth
 * @default 56.7
 * @range 1, 120
 */
uniform float u_depth;
/**
 * @label Bevel
 * @default 5.445
 * @range 0.5, 15
 */
uniform float u_bevel;
/**
 * @label Metal grain
 * @default 0.3
 * @range 0, 1
 */
uniform float u_grain;
/**
 * @label Shadow strength
 * @default 0.56
 * @range 0, 1
 */
uniform float u_shadow;
/**
 * @label Shadow softness
 * @default 0.7
 * @range 0, 1
 */
uniform float u_shadowSoftness;
/**
 * @label Shadow direction
 * @default 133
 * @range -180, 180
 */
uniform float u_shadowDirection;
/**
 * @label Shadow elevation
 * @default 60
 * @range 25, 85
 */
uniform float u_shadowElevation;
/**
 * @label Contact strength
 * @default 0.85
 * @range 0, 1
 */
uniform float u_contactStrength;
/**
 * @label Contact spread
 * @default 42
 * @range 5, 100
 */
uniform float u_contactSpread;
/**
 * @label Ground level
 * @default 0.28
 * @range 0, 0.8
 */
uniform float u_ground;
/**
 * @label Exposure
 * @default 1
 * @range 0.5, 1.5
 */
uniform float u_exposure;
/**
 * @label Ground opacity
 * @default 0
 * @range 0, 1
 */
uniform float u_stage;
/**
 * @label Chrome roughness
 * @default 0.24
 * @range 0.05, 0.8
 */
uniform float u_roughness;
/**
 * @label Studio rotation
 * @default 0
 * @range -180, 180
 */
uniform float u_studio;
float hash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
vec3 objectPoint(vec3 p){
 float side=min(u_resolution.x,u_resolution.y);
 vec3 pivot=vec3(0.0,0.0,-u_depth/side*0.5);
 return worldToObject*(p-pivot)+pivot;
}
float solid(vec3 worldPoint){
 vec3 p=objectPoint(worldPoint);
 float side=min(u_resolution.x,u_resolution.y);
 vec2 uv=p.xy*side/u_resolution+0.5;
 vec2 safe=clamp(uv,vec2(0.001),vec2(0.999));
 float planar=-texture2D(u_shape,safe).r/side+length((uv-safe)*u_resolution/side);
 float halfDepth=max(u_depth/side*0.5,0.0005);
 float bevel=min(u_bevel/side,halfDepth*0.95);
 vec2 q=vec2(planar+bevel,abs(p.z+halfDepth)-halfDepth+bevel);
 return min(max(q.x,q.y),0.0)+length(max(q,0.0))-bevel;
}
vec3 studio(vec3 r){
 float a=radians(u_studio);
 r.xz=mat2(cos(a),-sin(a),sin(a),cos(a))*r.xz;
 float blur=u_roughness*0.23;
 float sky=smoothstep(-0.65,0.8,r.y);
 vec3 value=vec3(mix(0.10,0.53,sky));
 float key=exp(-pow(abs((r.x+0.40)/(0.18+blur)),4.0))*smoothstep(-0.65,0.45,r.z);
 float strip=exp(-pow(abs((r.x-0.67)/(0.045+blur*0.6)),2.0));
 float overhead=exp(-pow(abs((r.y-0.78)/(0.12+blur)),4.0));
 float flag=exp(-pow(abs((r.x-0.18)/(0.10+blur)),4.0))*smoothstep(-0.4,0.3,r.z);
 value*=1.0-0.78*flag;
 value+=vec3(0.95,0.97,1.0)*key*0.72;
 value+=vec3(1.0,0.98,0.94)*strip*0.60;
 value+=vec3(0.42)*overhead;
 return value;
}
void main(){
 worldToObject=rotationY(-radians(u_objectYaw))*rotationX(-radians(u_objectPitch))*rotationZ(-radians(u_objectRoll));
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

 float halfDepth=max(u_depth/side*0.5,0.0005);
 vec3 boxC=vec3(0.0,0.0,-halfDepth),boxH=vec3(u_resolution/side*0.5,halfDepth)+4.0/side;
 vec3 ro=objectPoint(origin),rd=worldToObject*ray;
 rd+=vec3(1e-7)*step(abs(rd),vec3(1e-7));
 vec3 b0=(boxC-boxH-ro)/rd,b1=(boxC+boxH-ro)/rd;
 vec3 bn=min(b0,b1),bf=max(b0,b1);
 float tFar=min(min(bf.x,bf.y),bf.z);
 float t=4.0;
 if(max(max(bn.x,bn.y),bn.z)<tFar&&tFar>0.0){
  t=0.0;
  for(int i=0;i<112;i++){
   float d=solid(origin+ray*t);
   if(d<epsilon)break;
   t+=clamp(d*0.75,epsilon*0.3,0.09);
   if(t>3.0)break;
   if(t>tFar){t=4.0;break;}
  }
 }
 vec3 p=origin+ray*t;
 float hit=0.0;
 vec3 metal=vec3(0.0);
 if(t<3.0){
 float distanceToSolid=solid(p);
 hit=1.0-smoothstep(epsilon,epsilon*2.4,distanceToSolid);
 }
 if(hit>0.0){
 float e=0.7/side;
 vec3 n=normalize(vec3(solid(p+vec3(e,0,0))-solid(p-vec3(e,0,0)),solid(p+vec3(0,e,0))-solid(p-vec3(0,e,0)),solid(p+vec3(0,0,e))-solid(p-vec3(0,0,e)))+vec3(0.0000001));
 vec3 reflected=reflect(ray,n);
 float fresnel=0.91+0.09*pow(1.0-max(dot(n,view),0.0),5.0);
 vec3 materialPoint=objectPoint(p);
 float speck=hash(floor(materialPoint.xy*side*1.4)+floor(materialPoint.z*side)*0.37)-0.5;
 float brush=hash(vec2(floor(materialPoint.x*side*0.12),floor((materialPoint.y+materialPoint.z)*side*2.8)))-0.5;
 metal=studio(reflected)*fresnel;
 metal*=1.0+u_grain*(speck*0.09+brush*0.06);
 metal=clamp(metal*u_exposure,0.0,1.0);
 }
 float floorY=(u_ground-0.5)*u_resolution.y/side;
 float floorT=(origin.y-floorY)/max(view.y,0.05);
 vec3 floorPoint=origin-view*floorT;
 float azimuth=radians(u_shadowDirection);
 float elevation=radians(u_shadowElevation);
 vec3 light=vec3(cos(azimuth)*cos(elevation),sin(elevation),sin(azimuth)*cos(elevation));
 float penumbra=exp2(mix(5.5,2.0,u_shadowSoftness));
 float shadow=0.0;
 if(hit<1.0){

 vec3 fo=objectPoint(floorPoint),lo=worldToObject*light;
 vec3 slope=abs(lo)-1.0/penumbra;
 vec3 axisStop=(boxH+sign(lo)*(boxC-fo))/max(slope,1e-6)+step(slope,vec3(0.0))*1e6;
 float stopAt=min(min(axisStop.x,axisStop.y),axisStop.z);
 float visibility=1.0;
 float st=0.002;
 if(u_shadow>0.0)for(int j=0;j<36;j++){
  if(st>=stopAt||visibility<=0.0)break;
  float d=solid(floorPoint+light*st);
  visibility=min(visibility,penumbra*max(d,0.0)/max(st,0.001));
  st+=clamp(d,0.006,0.065);
 }
 visibility=clamp(visibility,0.0,1.0);
 visibility=visibility*visibility*(3.0-2.0*visibility);
 float ao=0.0;
 float totalWeight=1.0;
 float spread=u_contactSpread/side;

 float maxReach=0.7/side+spread*0.81;
 if(u_contactStrength>0.0&&solid(floorPoint)<maxReach*2.0){
 totalWeight=0.0;
 for(int k=0;k<8;k++){
  float angle=float(k)*0.785398163;
  vec3 hemisphere=normalize(vec3(cos(angle)*0.75,1.0,sin(angle)*0.75));
  for(int m=0;m<5;m++){
   float fraction=(float(m)+0.5)/5.0;
   float reach=0.7/side+spread*fraction*fraction;
   float d=solid(floorPoint+hemisphere*reach);
   float weight=exp(-fraction*1.5);
   float proximity=clamp(1.0-d/reach,0.0,1.0);
   ao+=proximity*weight;
   totalWeight+=weight;
  }
 }
 }
 ao=clamp(ao/max(totalWeight,0.001),0.0,1.0);
 float contact=pow(ao,0.85)*u_contactStrength;
 float castShadow=(1.0-visibility)*u_shadow;
 shadow=1.0-(1.0-contact)*(1.0-castShadow);
 }
 vec2 edge=min(gl_FragCoord.xy,u_resolution-gl_FragCoord.xy)/side;
 shadow*=smoothstep(0.0,0.05,min(edge.x,edge.y));
 float paper=0.92+0.045*exp(-dot(xy,xy)*5.0);
 vec3 base=vec3(paper*(1.0-shadow))*u_stage;
 float baseAlpha=u_stage+(1.0-u_stage)*shadow;
 gl_FragColor=vec4(mix(base,metal,hit),hit+baseAlpha*(1.0-hit));
}
