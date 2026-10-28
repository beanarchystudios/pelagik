precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @content */
uniform sampler2D u_content;
/**
 * @label Water colour
 * @color
 * @default #527F82
 */
uniform vec3 u_water;
/**
 * @label Water tint
 * @default 0.28
 * @range 0, 1
 */
uniform float u_tint;
/**
 * @label Depth
 * @default 0.12
 * @range 0, 1
 */
uniform float u_depth;
/**
 * @label Bottom depth
 * @default 0.85
 * @range 0, 2
 */
uniform float u_bottom;
/**
 * @label Waterline
 * @default 0.37
 * @range 0, 1
 */
uniform float u_waterline;
/**
 * @label Refraction
 * @default 1
 * @range 0, 3
 */
uniform float u_refraction;
/**
 * @label Underwater softness
 * @default 0.55
 * @range 0, 2
 */
uniform float u_softness;
/**
 * @label Depth fade
 * @default 0.9
 * @range 0, 3
 */
uniform float u_fade;
/**
 * @label Ripple source X
 * @default 0.51
 * @range 0, 1
 */
uniform float u_sourceX;
/**
 * @label Ripple source Y
 * @default 0.39
 * @range 0, 1
 */
uniform float u_sourceY;
/**
 * @label Ripples
 * @default 0.75
 * @range 0, 2
 */
uniform float u_ripples;
/**
 * @label Ripple spacing
 * @default 0.034
 * @range 0.012, 0.12
 */
uniform float u_spacing;
/**
 * @label Roughness
 * @default 0.65
 * @range 0, 2
 */
uniform float u_roughness;
/**
 * @label Speed
 * @default 0.55
 * @range 0, 2
 */
uniform float u_speed;
/**
 * @label Light X
 * @default 0.48
 * @range 0, 1
 */
uniform float u_lightX;
/**
 * @label Light Y
 * @default 0.08
 * @range -0.5, 1
 */
uniform float u_lightY;
/**
 * @label Light brightness
 * @default 1.15
 * @range 0, 4
 */
uniform float u_light;
/**
 * @label Light spread
 * @default 0.65
 * @range 0.1, 2
 */
uniform float u_spread;
/**
 * @label Light falloff
 * @default 2.8
 * @range 0, 8
 */
uniform float u_falloff;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float surface(vec2 p,float t){
 vec2 origin=vec2((u_sourceX-0.5)*u_resolution.x/u_resolution.y,u_sourceY);
 vec2 delta=p-origin;
 float r=length(delta);
 vec2 drift=vec2(0.011,-0.019)*t;
 vec2 warp=vec2(noise(p*5.7+drift+13.7),noise(p*7.3-drift*0.7+39.1))-0.5;
 vec2 q=p+warp*0.075;
 float swell=noise(q*vec2(7.0,19.0)+vec2(t*0.07,-t*0.19))-0.5;
 float mid=noise(q*vec2(19.0,67.0)+vec2(-t*0.21,t*0.39));
 vec2 fineWarp=vec2(mid,noise(q*vec2(33.0,29.0)+t*0.12))-0.5;
 vec2 fq=q+fineWarp*0.014;
 float chop=noise(fq*vec2(43.0,143.0)+vec2(t*0.33,-t*0.57))-0.5;
 float detail=noise((fq+warp*0.008)*vec2(89.0,281.0)+vec2(-t*0.48,t*0.79))-0.5;
 float radial=(r+dot(warp,vec2(0.024,0.038)))/max(u_spacing,0.005)-t*0.65;
 float packet=noise(vec2(radial*1.4,delta.x*9.0+t*0.07));
 float wake=(packet-0.5)*exp(-r*2.2)*smoothstep(0.012,0.065,r);
 float broken=0.35+0.65*noise(q*11.0+vec2(t*0.09,3.7));
 return 0.010*swell+0.007*(mid-0.5)+u_roughness*(0.0027*chop+0.0007*detail)+0.011*u_ripples*wake*broken;
}
vec4 sourceAt(vec2 uv){
 vec2 inside=step(vec2(0.0),uv)*step(uv,vec2(1.0));
 return texture2D(u_content,clamp(uv,0.0,1.0))*inside.x*inside.y;
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec2 top=vec2(uv.x,1.0-uv.y);
 float aspect=u_resolution.x/u_resolution.y;
 vec2 p=vec2((top.x-0.5)*aspect,top.y);
 float t=u_time*u_speed;
 float eps=0.00065;
 float h=surface(p,t);
 vec2 slope=vec2(surface(p+vec2(eps,0),t)-surface(p-vec2(eps,0),t),surface(p+vec2(0,eps),t)-surface(p-vec2(0,eps),t))/(2.0*eps);
 float descend=smoothstep(u_waterline,u_waterline+0.42,top.y);
 float depth=u_depth+u_bottom*descend;
 vec2 displace=slope*(0.003+depth*0.040)*u_refraction;
 vec2 refracted=uv+vec2(displace.x/aspect,-displace.y);
 float blur=u_softness*(0.00015+0.0018*depth);
 vec2 bx=vec2(blur/aspect,0),by=vec2(0,blur);
 vec4 src=sourceAt(refracted)*0.4;
 src+=0.15*(sourceAt(refracted+bx)+sourceAt(refracted-bx)+sourceAt(refracted+by)+sourceAt(refracted-by));
 vec3 normal=normalize(vec3(-slope*0.9,1.0));
 vec2 lightPos=vec2((u_lightX-0.5)*aspect,u_lightY);
 vec3 lightDir=normalize(vec3((lightPos-p)*0.8,0.65));
 vec3 halfDir=normalize(lightDir+vec3(0,0,1));
 float spec=pow(max(dot(normal,halfDir),0.0),125.0);
 float wide=pow(max(dot(normal,halfDir),0.0),12.0);
 float distanceLight=length((p-lightPos)/u_spread);
 float illumination=exp(-distanceLight*distanceLight*1.1)*exp(-max(top.y-u_lightY,0.0)*u_falloff)*u_light;
 float vignette=1.0-smoothstep(0.55,1.12,length(vec2(p.x*0.9,(p.y-0.45)*1.1)));
 vec3 water=u_water*(0.006+0.028*illumination)*vignette;
 vec3 reflection=mix(vec3(0.8,0.91,0.94),u_water,0.3)*(spec*0.65+wide*0.026)*illumination*vignette;
 vec3 transmitted=src.rgb*mix(vec3(1.0),u_water,u_tint*(0.25+0.75*clamp(depth,0.0,1.0)));
 transmitted*=exp(-depth*u_fade)*(0.97+0.03*clamp(h*160.0,-1.0,1.0));
 vec3 col=water*(1.0-src.a*0.75)+transmitted+reflection;
 gl_FragColor=vec4(clamp(col,0.0,1.0),1.0);
}
