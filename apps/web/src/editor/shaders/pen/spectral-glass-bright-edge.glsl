precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @content */
uniform sampler2D u_content;
/** @sdf */
uniform sampler2D u_sdf;
/**
 * @label Interior color
 * @color
 * @default #070809
 */
uniform vec3 u_dark;
/**
 * @label Ramp red
 * @color
 * @default #FF2408
 */
uniform vec3 u_red;
/**
 * @label Ramp orange
 * @color
 * @default #FF8500
 */
uniform vec3 u_orange;
/**
 * @label Ramp yellow
 * @color
 * @default #FFF52B
 */
uniform vec3 u_yellow;
/**
 * @label Ramp cyan
 * @color
 * @default #4FF7FF
 */
uniform vec3 u_cyan;
/**
 * @label Ramp blue
 * @color
 * @default #143AFF
 */
uniform vec3 u_blue;
/**
 * @label Seed
 * @default 0
 * @range 0, 1000
 */
uniform float u_seed;
/**
 * @label Flow speed
 * @default 0.3
 * @range 0, 2
 */
uniform float u_speed;
/**
 * @label Flow amount
 * @default 0.65
 * @range 0, 2
 */
uniform float u_flow;
/**
 * @label Flow scale
 * @default 2.4
 * @range 0.5, 8
 */
uniform float u_scale;
/**
 * @label Phase
 * @default 0
 * @range 0, 6.28
 */
uniform float u_phase;
/**
 * @label Pool coverage
 * @default 0.47
 * @range 0, 1
 */
uniform float u_pool;
/**
 * @label Pool contrast
 * @default 1.4
 * @range 0.3, 4
 */
uniform float u_contrast;
/**
 * @label Glass edge width
 * @default 5
 * @range 1, 30
 */
uniform float u_edge;
/**
 * @label Edge brightness
 * @default 1.2
 * @range 0, 3
 */
uniform float u_rim;
/**
 * @label Edge refraction
 * @default 1.5
 * @range 0, 4
 */
uniform float u_refraction;
/**
 * @label Color dispersion
 * @default 0.75
 * @range 0, 2
 */
uniform float u_dispersion;
/**
 * @label Spark amount
 * @default 0.65
 * @range 0, 1
 */
uniform float u_sparks;
/**
 * @label Spark highlight threshold
 * @default 0.82
 * @range 0.5, 1
 */
uniform float u_highlightThreshold;
/**
 * @label Spark size
 * @default 65
 * @range 2, 120
 */
uniform float u_sparkSize;
/**
 * @label Spark brightness
 * @default 1.5
 * @range 0, 4
 */
uniform float u_sparkBrightness;
/**
 * @label Spark halo
 * @default 0.7
 * @range 0, 2
 */
uniform float u_sparkHalo;
/**
 * @label Spark twinkle
 * @default 0.65
 * @range 0, 1
 */
uniform float u_twinkle;
/**
 * @label Exposure
 * @default 1
 * @range 0.2, 2
 */
uniform float u_exposure;
vec3 ramp(float v){
 vec3 c=mix(u_dark,u_blue,smoothstep(0.0,0.09,v));
 c=mix(c,u_cyan,smoothstep(0.09,0.17,v));
 c=mix(c,u_yellow,smoothstep(0.17,0.28,v));
 c=mix(c,u_orange,smoothstep(0.38,0.65,v));
 return mix(c,u_red,smoothstep(0.65,1.0,v));
}
float hash(vec2 p){p+=vec2(17.13,43.71)*floor(u_seed+0.5);return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec3 colorField(vec2 q,float t,float lens){
 q+=u_flow*0.22*vec2(sin(q.y*3.1+t),cos(q.x*2.7-t*0.8));
 float f=sin(q.x*3.0+q.y*2.4+t*0.45)+0.48*sin(q.y*4.8-q.x*1.7-t*0.7);
 return ramp(clamp((f*0.39+u_pool-0.39+lens*0.16)*u_contrast,0.0,1.0));
}
float edgeLuminance(vec2 point,vec2 normal,float angle,vec2 offset,float t){
 float d=1.1;
 mat2 rot=mat2(cos(angle),sin(angle),-sin(angle),cos(angle));
 vec2 q=rot*((point+normal*d-0.5*u_resolution)/min(u_resolution.x,u_resolution.y))*u_scale+offset;
 vec2 nq=rot*normal;
 float lens=exp(-d/(u_edge*6.0));
 float depth=clamp(d/(u_edge*2.5),0.0,1.0);
 vec2 bend=nq*sin(depth*6.2831853)*pow(1.0-depth,0.6)*u_refraction*0.85;
 float split=u_dispersion*0.24;
 vec3 cr=colorField(q+bend*(1.0+split),t,lens);
 vec3 cg=colorField(q+bend,t,lens);
 vec3 cb=colorField(q+bend*(1.0-split),t,lens);
 vec3 c=vec3(cr.r,cg.g,cb.b);
 float inner=exp(-pow((d-u_edge)/0.85,2.0));
 c+=mix(colorField(q+nq*u_refraction*0.45,t,lens),vec3(0.8,0.87,1.0),0.3)*(1.0+inner*0.45)*u_rim;
 c*=1.0-0.4*exp(-pow((d-u_edge*1.35)/1.4,2.0));
 c+=vec3(0.65,0.85,1.0)*pow(max(dot(normal,normalize(vec2(-0.65,0.76))),0.0),18.0)*u_rim*0.7;
 return dot(clamp(c*u_exposure,0.0,1.0),vec3(0.2126,0.7152,0.0722));
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 src=texture2D(u_content,uv);
 vec4 sdf=texture2D(u_sdf,uv);
 float d=sdf.r;
 vec2 n=sdf.gb/max(length(sdf.gb),0.0001);
 float t=u_time*u_speed+u_phase;
 vec2 p=(gl_FragCoord.xy-0.5*u_resolution)/min(u_resolution.x,u_resolution.y);
 float s=floor(u_seed+0.5);
 float angle=6.2831853*fract(s*0.618033989);
 vec2 offset=vec2(fract(s*0.754877666),fract(s*0.569840296))*8.0;
 vec2 q=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*p*u_scale+offset;
 float lens=exp(-max(d,0.0)/(u_edge*6.0));
 float depth=clamp(d/(u_edge*2.5),0.0,1.0);
 float profile=sin(depth*6.2831853)*pow(1.0-depth,0.6);
 vec2 normalQ=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*n;
 vec2 bend=normalQ*profile*u_refraction*0.85;
 float split=u_dispersion*0.24;
 vec3 cr=colorField(q+bend*(1.0+split),t,lens);
 vec3 cg=colorField(q+bend,t,lens);
 vec3 cb=colorField(q+bend*(1.0-split),t,lens);
 vec3 col=vec3(cr.r,cg.g,cb.b);
 float outer=exp(-pow((d-1.1)/0.72,2.0));
 float inner=exp(-pow((d-u_edge)/0.85,2.0));
 float bevel=exp(-max(d,0.0)/u_edge);
 float facing=dot(n,normalize(vec2(-0.65,0.76)));
 vec3 edgeColor=colorField(q+normalQ*u_refraction*0.45,t,lens);
 col+=mix(edgeColor,vec3(0.8,0.87,1.0),0.3)*(outer+inner*0.45)*u_rim;
 col*=1.0-0.4*exp(-pow((d-u_edge*1.35)/1.4,2.0));
 col+=vec3(0.65,0.85,1.0)*pow(max(facing,0.0),18.0)*outer*u_rim*0.7;
 vec3 sparkle=vec3(0.0);
 float haloAlpha=0.0;
 float cell=86.0;
 vec2 grid=floor(gl_FragCoord.xy/cell);
 for(int j=-2;j<=2;j++){
  for(int i=-2;i<=2;i++){
   vec2 id=grid+vec2(float(i),float(j));
   vec2 seed=(id+vec2(0.2+0.6*hash(id),0.2+0.6*hash(id+13.7)))*cell;
   vec4 sd=texture2D(u_sdf,seed/u_resolution);
   vec2 normal=sd.gb/max(length(sd.gb),0.0001);
   vec2 anchor=seed-normal*sd.r;
   vec4 edgeSample=texture2D(u_sdf,anchor/u_resolution);
   vec2 edgeNormal=edgeSample.gb/max(length(edgeSample.gb),0.0001);
   anchor-=edgeNormal*edgeSample.r;
   float onEdge=1.0-smoothstep(1.5,4.0,abs(edgeSample.r));
   float gate=(1.0-step(cell*0.55,abs(sd.r)))*step(hash(id+7.4),u_sparks*0.6)*onEdge;

   float luminance=0.0;
   if(gate>0.0)luminance=edgeLuminance(anchor,edgeNormal,angle,offset,t);
   vec2 tangent=vec2(-edgeNormal.y,edgeNormal.x);
   vec2 origin=anchor;
   for(int k=-2;k<=2;k++){
    vec2 probe=origin+tangent*float(k)*12.0;
    vec4 ps=texture2D(u_sdf,probe/u_resolution);
    vec2 pn=ps.gb/max(length(ps.gb),0.0001);
    probe-=pn*ps.r;
    if(gate>0.0){
     float score=edgeLuminance(probe,pn,angle,offset,t);
     float better=step(luminance+0.001,score)*(1.0-step(12.0,abs(ps.r)));
     anchor=mix(anchor,probe,better);
     luminance=mix(luminance,score,better);
    }
   }
   float highlight=smoothstep(u_highlightThreshold,min(u_highlightThreshold+0.10,1.001),luminance);
   gate*=highlight;
   vec2 delta=gl_FragCoord.xy-anchor;
   float pulse=mix(1.0,0.3+0.7*pow(0.5+0.5*sin(t*3.0+hash(id)*6.28),3.0),u_twinkle);
   float size=u_sparkSize*(0.6+hash(id+3.2)*0.7);
   float radius=length(delta);
   float core=exp(-dot(delta,delta)/max(size*size*0.006,1.0));
   float rayWidth=max(0.8,size*0.018);
   float cross=exp(-abs(delta.x)/rayWidth)*pow(max(1.0-abs(delta.y)/size,0.0),2.0)+exp(-abs(delta.y)/rayWidth)*pow(max(1.0-abs(delta.x)/size,0.0),2.0);
   vec2 diagonal=vec2(delta.x+delta.y,delta.x-delta.y)*0.7071;
   float rays=(exp(-abs(diagonal.x)/rayWidth)+exp(-abs(diagonal.y)/rayWidth))*pow(max(1.0-radius/(size*0.45),0.0),3.0)*0.22;
   float glow=exp(-dot(delta,delta)/max(size*size*0.055,1.0))*u_sparkHalo*0.32;
   float star=(core+cross*0.8+rays+glow)*gate*pulse*u_sparkBrightness;
   sparkle+=vec3(star);
   haloAlpha+=star;
  }
 }
 float coverage=min(src.a,smoothstep(-0.5,0.5,d));
 float alpha=max(coverage,smoothstep(0.0001,0.025,haloAlpha));
 vec3 rgb=col*u_exposure*coverage+sparkle;
 gl_FragColor=vec4(min(rgb,vec3(alpha)),alpha);
}
