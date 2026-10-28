precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @content */
uniform sampler2D u_content;
/** @sdf */
uniform sampler2D u_shape;
/**
 * @label Puff
 * @default 90
 * @range 4, 300
 */
uniform float u_puff;
/**
 * @label Dome
 * @default 0.35
 * @range 0, 1.5
 */
uniform float u_dome;
/**
 * @label Light elevation
 * @default 55
 * @range 10, 85
 */
uniform float u_lightElev;
/**
 * @label Light width
 * @default 14
 * @range 2, 45
 */
uniform float u_lightWidth;
/**
 * @label Light softness
 * @default 0.35
 * @range 0, 1
 */
uniform float u_lightSoft;
/**
 * @label Gloss
 * @default 1
 * @range 0, 2
 */
uniform float u_gloss;
/**
 * @label Rim light
 * @default 1
 * @range 0, 2
 */
uniform float u_rim;
/**
 * @label Shade
 * @default 0.7
 * @range 0, 1
 */
uniform float u_shade;
/**
 * @label Sparkle
 * @default 0.3
 * @range 0, 1
 */
uniform float u_sparkle;
/**
 * @label Shadow strength
 * @default 0.5
 * @range 0, 1
 */
uniform float u_shadow;
/**
 * @label Shadow distance
 * @default 40
 * @range 0, 200
 */
uniform float u_shadowDist;
/**
 * @label Shadow softness
 * @default 60
 * @range 1, 200
 */
uniform float u_shadowSoft;

float hash21(vec2 p){
 p=fract(p*vec2(0.1031,0.1030));
 p+=dot(p,p.yx+33.33);
 return fract((p.x+p.y)*p.x);
}
float heightAt(float d,float P,float D){
 float t=clamp(d/P,0.0,1.0);
 float q=1.0-clamp(d/D,0.0,1.0);
 return P*sqrt(max(1.0-(1.0-t)*(1.0-t),0.0))+0.5*u_dome*D*(1.0-q*q);
}
float strip(float ang,float center,float halfWidth,float soft){
 float e=max(halfWidth*(0.15+0.85*soft),0.005);
 return 1.0-smoothstep(halfWidth-e,halfWidth+e,abs(ang-center));
}
vec3 studio(vec3 r,vec3 n){
 float elev=atan(r.y,r.z);
 float side=abs(r.x);
 float wide=1.0-smoothstep(0.55,0.95,side);
 float keyC=radians(u_lightElev);
 float keyW=radians(u_lightWidth);
 float key=strip(elev,keyC,keyW,u_lightSoft)*wide;
 float halo=exp(-pow((elev-keyC)/(keyW*3.2),2.0))*(1.0-smoothstep(0.7,1.0,side));
 float rim=exp(-pow((elev-radians(152.0))/0.09,2.0))*(1.0-smoothstep(0.75,1.0,side));
 float floorB=exp(-pow((elev+radians(140.0))/0.16,2.0))*(1.0-smoothstep(0.6,1.0,side));
 float sky=smoothstep(-0.2,0.9,r.y);
 vec3 room=mix(vec3(0.05),vec3(0.5),sky)*mix(1.0,0.3,u_shade*(1.0-sky));
 vec3 col=room;
 col+=vec3(1.0,0.98,0.95)*(key*3.2+halo*1.2);
 col+=vec3(1.0)*rim*22.0*u_rim;
 col+=vec3(0.9,0.85,0.8)*floorB*1.1;
 return col;
}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec4 c=texture2D(u_content,uv);
 vec4 field=texture2D(u_shape,uv);
 vec2 shUV=(gl_FragCoord.xy+vec2(0.0,u_shadowDist))/u_resolution;
 vec4 shField=texture2D(u_shape,clamp(shUV,vec2(0.0),vec2(1.0)));
 float cov=c.a;
 vec3 albedo=c.rgb/max(c.a,0.002);
 float d=max(field.r,0.0);
 vec2 g=field.gb;
 vec2 gdir=g/max(length(g),0.02);
 float P=max(u_puff,1.0);
 float D=P*3.0+80.0;
 float t=clamp(d/P,0.0,1.0);
 float h=sqrt(max(1.0-(1.0-t)*(1.0-t),0.0));
 float q=1.0-clamp(d/D,0.0,1.0);
 vec2 slopeEdge=gdir*((1.0-t)/max(h,0.05)+u_dome*q);
 float R=max(P*0.45,10.0);
 vec2 px=1.0/u_resolution;
 vec2 slopeRing=vec2(0.0);
 for(int i=0;i<12;i++){
  float a=(float(i)+0.5)*0.5235988;
  vec2 dir=vec2(cos(a),sin(a));
  float di=texture2D(u_shape,clamp(uv+dir*R*px,0.0,1.0)).r;
  slopeRing+=heightAt(max(di,0.0),P,D)*dir;
 }
 slopeRing*=2.0/(12.0*R);
 float w=smoothstep(0.12*P,0.5*P,d);
 vec2 slope=mix(slopeEdge,slopeRing,w);
 vec3 n=normalize(vec3(-slope,1.0));
 vec3 r=reflect(vec3(0.0,0.0,-1.0),n);
 float keyC=radians(u_lightElev);
 vec3 L=normalize(vec3(0.0,sin(keyC),cos(keyC)));
 float hemi=n.y*0.5+0.5;
 float down=smoothstep(0.55,0.0,hemi);
 float ambient=mix(0.42,0.66,hemi)*mix(1.0,0.45,u_shade*down);
 float diffuse=max(dot(n,L),0.0)*0.45;
 float fres=pow(1.0-max(n.z,0.0),5.0);
 float F=0.06+0.94*fres;
 vec3 env=studio(r,n);
 vec3 col=albedo*(ambient+diffuse)+env*F*u_gloss;
 float cell=hash21(floor(gl_FragCoord.xy*0.5));
 float spark=step(1.0-u_sparkle*0.012,cell)*pow(max(n.y,0.0)*0.6+0.4,2.0)*(0.5+0.5*hash21(floor(gl_FragCoord.xy*0.5)+7.0));
 col+=vec3(1.0)*spark*0.9*u_gloss;
 vec3 over=max(col-0.85,0.0);
 col=min(col,vec3(0.85))+over/(1.0+1.6*over);
 col=clamp(col,0.0,1.0);
 float shadow=smoothstep(-u_shadowSoft,u_shadowSoft*0.35,shField.r)*u_shadow;
 float a=cov+shadow*(1.0-cov);
 gl_FragColor=vec4(col*cov,a);
}
