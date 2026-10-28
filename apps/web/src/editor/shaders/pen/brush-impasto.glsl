// SPDX-License-Identifier: MIT
precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @content */
uniform sampler2D u_content;
/** @label Texture scale @default 1 @range 0.4, 3 */
uniform float u_scale;
/** @label Ragged edges @default 16 @range 0, 60 */
uniform float u_ragged;
/** @label Thick pigment @default 1.25 @range 0, 2 */
uniform float u_impasto;
/** @label Raised layer @default -1 @range -1, 1 */
uniform float u_polarity;
/** @label Dry brush @default 0.42 @range 0, 1 */
uniform float u_dry;
/** @label Canvas weave @default 0.6 @range 0, 1 */
uniform float u_canvas;
/** @label Splatter @default 0.5 @range 0, 1.5 */
uniform float u_splat;
/** @label Light angle @default 125 @range -180, 180 */
uniform float u_light;
/** @label Brush angle @default 0 @range -180, 180 */
uniform float u_angle;
/** @label Brush seed @default 1 @range 0, 100 */
uniform float u_seed;

#define TAU 6.28318530718
#define AUTH 0.055

float sq(float x) { return x*x; }
mat2 rot(float a) { float c=cos(a),s=sin(a); return mat2(c,-s,s,c); }

float hash12(vec2 p) {
    vec3 p3=fract(vec3(p.xyx)*0.1031);
    p3+=dot(p3,p3.yzx+33.33);
    return fract((p3.x+p3.y)*p3.z);
}
vec2 hash22(vec2 p) {
    vec3 p3=fract(vec3(p.xyx)*vec3(0.1031,0.1030,0.0973));
    p3+=dot(p3,p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}
float vnoise(vec2 p) {
    vec2 i=floor(p),f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash12(i),hash12(i+vec2(1.0,0.0)),f.x),
               mix(hash12(i+vec2(0.0,1.0)),hash12(i+vec2(1.0,1.0)),f.x),f.y);
}
const mat2 OCT=mat2(0.8018,-0.5977,0.5977,0.8018);
float fbm3(vec2 p) {
    float s=0.0,a=0.5;
    for(int i=0;i<3;i++){ s+=a*vnoise(p); p=OCT*p*2.03+19.3; a*=0.5; }
    return s*1.1429;
}

vec3 unpre(vec4 c) { return c.rgb/max(c.a,0.0001); }
float lum(vec3 c) { return dot(c,vec3(0.299,0.587,0.114)); }
vec4 readAt(vec2 p) { return texture2D(u_content,p/u_resolution); }

float bodyOf(vec3 c, float pol) {
    float pale=smoothstep(0.30,0.70,lum(c));
    float byLum=max((1.0-pale)*clamp(1.0-pol,0.0,1.0),pale*clamp(1.0+pol,0.0,1.0));
    float sat=max(max(c.r,c.g),c.b)-min(min(c.r,c.g),c.b);
    return max(byLum,smoothstep(0.10,0.30,sat));
}

float weaveHeight(vec2 c) {
    float wx=c.x+0.55*vnoise(vec2(c.y*0.07,3.1));
    float wy=c.y+0.55*vnoise(vec2(c.x*0.07,27.7));
    float ax=0.52+0.48*hash12(vec2(floor(wx/TAU),4.0));
    float ay=0.52+0.48*hash12(vec2(floor(wy/TAU),9.0));
    float tx=(sin(wx)*0.5+0.5)*ax;
    float ty=(sin(wy)*0.5+0.5)*ay;
    float t=mix(max(tx,ty),(tx+ty)*0.5,0.55);
    return clamp(t+0.12*(vnoise(c*7.3)-0.5),0.0,1.0);
}

float ground(vec2 q, float plaster) {
    vec2 s=q*0.0055;
    s+=0.8*(vec2(vnoise(s*0.7),vnoise(s*0.7+7.0))-0.5);
    float broad=fbm3(s);
    vec2 wq=q+260.0*(vec2(vnoise(q*0.0009+5.0),vnoise(q*0.0009+55.0))-0.5);
    float edge=smoothstep(0.46,0.65,vnoise(rot(0.55)*wq*vec2(0.0045,0.016)+3.0))*0.80
              +smoothstep(0.47,0.78,vnoise(rot(-1.05)*wq*vec2(0.0090,0.030)+17.0))*0.42;
    float gou=smoothstep(0.66,0.86,vnoise(rot(0.25)*wq*vec2(0.005,0.060)+21.0));
    return broad*1.05+(edge*0.38+gou*0.18)*plaster;
}

float licStreak(vec2 pos, vec2 t, float freq, float step, float sd) {
    vec2 a=pos*freq+sd;
    vec2 d=t*freq*step;
    float acc=0.0;
    for(int i=0;i<14;i++){ acc+=vnoise(a); a+=d; }
    return clamp((acc/14.0-0.5)*2.5+0.5,0.0,1.0);
}

float bodyRelief(vec2 q, vec2 t, float load, float furrow, float fur) {
    float drag=fbm3(q*0.011+5.0);
    float mid=licStreak(q,t,0.075,8.0,31.0);
    float ridge=smoothstep(0.60,0.74,licStreak(q,t,0.055,11.0,13.0));
    return drag*0.90+load*(mid*0.26+ridge*0.26)+furrow*(fur-0.5)*0.95;
}

float splatLayer(vec2 p, float cell, float sd, float rMax, float prob) {
    vec2 pr=rot(sd*0.9)*p+sd*37.0;
    vec2 gi=floor(pr/cell);
    float ex=step(1.0-prob,hash12(gi+sd*3.1+0.5));
    float sz=rMax*(0.22+0.78*hash12(gi+sd*3.1+13.7));
    float el=1.0+2.2*hash12(gi+sd*3.1+8.3);
    float reach=sz*sqrt(el)*1.4;
    float slack=max(0.5-reach/cell,0.0);
    vec2 ctr=(gi+0.5+(hash22(gi+sd*3.1+21.3)-0.5)*2.0*slack)*cell;
    vec2 de=rot(-TAU*hash12(gi+sd*3.1+4.9))*(pr-ctr);
    de.x/=el;
    float rr=sz/sqrt(el);
    float th=atan(de.y,de.x);
    vec2 cs=vec2(cos(th),sin(th));
    rr*=0.60+0.30*vnoise(cs*2.1+gi*13.0)+0.22*vnoise(cs*5.3+gi*7.0+41.0);
    return ex*smoothstep(rr,rr*0.70,length(de));
}
float splatField(vec2 q, float sd) {
    float s=splatLayer(q,420.0,sd+1.0,26.0,0.30);
    s=max(s,splatLayer(q,185.0,sd+2.0,11.0,0.30));
    s=max(s,splatLayer(q, 74.0,sd+3.0, 3.6,0.26));
    s=max(s,splatLayer(q, 31.0,sd+4.0, 1.4,0.22));
    return s;
}

float heightAt(vec2 q, vec2 tang, float load, vec4 w, float sd, float plaster, float furrow) {
    float h=weaveHeight(q*1.40)*w.x+ground(q,plaster)*w.y;
    if(w.z>0.0) h+=bodyRelief(q,tang,load,furrow,licStreak(q,tang,0.110,5.5,57.0))*w.z;
    if(w.w>0.0) h+=splatField(q,sd)*w.w;
    return h;
}

void main() {
    vec2 p=gl_FragCoord.xy;
    float sc=max(u_scale,0.15);
    float sd=u_seed;
    vec2 seedOff=vec2(53.17,91.73)*sd;
    vec2 q=p/sc+seedOff;
    float pol=clamp(u_polarity,-1.0,1.0);

    vec4 c0=readAt(p);
    vec3 col0=unpre(c0);
    float R=110.0*sc;
    float rj=0.70+0.60*vnoise(p*0.004/sc+17.0);
    vec2 tensor=vec2(0.0);
    vec3 inkAcc=vec3(0.0);
    float inkW=0.0;
    for(int i=0;i<8;i++){
        float a=TAU*float(i)/8.0;
        vec2 o=vec2(cos(a),sin(a));
        vec2 dbl=vec2(cos(2.0*a),sin(2.0*a));
        for(int j=0;j<6;j++){
            float ri=R*rj*(0.32+0.31*float(j))
                    *(0.90+0.20*vnoise(p*0.006/sc+float(i)*31.7+float(j)*7.3));
            vec4 s=readAt(p+o*ri);
            vec3 k=unpre(s);
            vec3 v=k-col0;
            float d=dot(v,v)*s.a*c0.a;
            float m=d/(d+0.12);
            tensor+=m*dbl;
            inkAcc+=k*d*s.a;
            inkW+=d*s.a;
        }
    }
    tensor/=48.0;
    vec3 inkColor=inkAcc/max(inkW,0.0001);
    float inkNear=smoothstep(0.003,0.045,inkW/48.0);

    float fallback=radians(u_angle)+(vnoise((p+seedOff)*0.0006/sc)-0.5)*radians(15.0);
    float tmag=length(tensor);
    float strength=tmag/(tmag+AUTH);
    vec2 dd=normalize(vec2(cos(2.0*fallback),sin(2.0*fallback))*AUTH-tensor
                      +vec2(0.000001));
    float angle=0.5*atan(dd.y,dd.x)
               +(vnoise((p+seedOff)*0.0007/sc+123.0)-0.5)*radians(26.0)
                *(1.0-strength);
    vec2 tang=vec2(cos(angle),sin(angle));

    vec2 n=p/sc+seedOff*1.37;
    vec2 rn=vec2(dot(n,tang),dot(n,vec2(-tang.y,tang.x)));
    vec2 w1=vec2(fbm3(n*0.008),fbm3(n*0.008+41.0))-0.5;
    vec2 w2=(vec2(vnoise(n*0.07),vnoise(n*0.07+91.0))-0.5)
            *smoothstep(0.42,0.78,fbm3(n*0.004+5.0));
    vec2 w3=(vec2(vnoise(n*0.26),vnoise(n*0.26+23.0))-0.5)
            *(0.10+0.95*smoothstep(0.38,0.80,fbm3(n*0.0028+131.0)));
    float hairs=(vnoise(rn*vec2(0.0045,1.9))-0.5)*1.5
               +(vnoise(rn*vec2(0.012,4.3)+5.0)-0.5)*0.6;
    hairs*=smoothstep(0.62,0.93,fbm3(n*0.0035+77.0))
          *(0.30+1.35*vnoise(vec2(rn.x*0.0008,rn.y*1.9)+9.0));
    vec2 warp=w1*1.80+w2*0.70+w3*0.35+tang*hairs*2.6;

    vec2 edgeD=min(p,u_resolution-p);
    float border=smoothstep(0.0,max(u_ragged*2.5,1.0),min(edgeD.x,edgeD.y));
    vec2 dp=p+warp*u_ragged*border;

    vec4 src=readAt(dp);
    vec3 color=unpre(src);
    float rN=3.0*sc,rF=7.5*sc;
    float bAcc=bodyOf(color,pol)*src.a*0.9,bW=0.9;
    vec2 bGrad=vec2(0.0);
    vec3 othAcc=vec3(0.0);
    float othW=0.0;
    for(int i=0;i<8;i++){
        float a=TAU*(float(i)+0.5)/8.0;
        vec2 o=vec2(cos(a),sin(a));
        vec4 s1=readAt(dp+o*rN);
        vec4 s2=readAt(dp+o*rF);
        vec3 k1=unpre(s1),k2=unpre(s2);
        float b1=bodyOf(k1,pol)*s1.a;
        float b2=bodyOf(k2,pol)*s2.a;
        bAcc+=b1*0.62+b2*0.38;
        bW+=1.0;
        bGrad+=o*(b1*0.45+b2*0.80);
        float ow=(1.0-b2)*s2.a;
        othAcc+=k2*ow;
        othW+=ow;
    }
    float body=bAcc/bW;
    vec3 othColor=othAcc/max(othW,0.0001);
    float othMix=smoothstep(0.6,3.2,othW);

    if(src.a<=0.0){ gl_FragColor=vec4(0.0); return; }

    float burst=smoothstep(0.20,0.60,fbm3((p+seedOff)*0.0016/sc+61.0));
    float rawSplat=splatField(q,sd);
    float splat=rawSplat*(1.0-body)*src.a
                *smoothstep(0.12,0.48,inkNear*burst*clamp(u_splat,0.0,2.0));
    color=mix(color,inkColor*(0.93+0.14*vnoise(q*0.06)),splat);

    float load=smoothstep(0.18,0.82,fbm3(q*0.011+sd*0.7));
    float bodyAll=max(body,splat);
    vec4 wts=vec4(u_canvas*0.18*(0.25+0.75*(1.0-bodyAll)),
                  0.80*(1.0-0.45*bodyAll),
                  bodyAll*0.45,
                  splat*1.6);
    float E=0.75;
    float plaster=1.0-smoothstep(0.10,0.55,u_canvas);
    float furrow=smoothstep(0.18,0.62,strength);

    float weave0=weaveHeight(q*1.40);
    float fur0=licStreak(q,tang,0.110,5.5,57.0);
    float h0=weave0*wts.x+ground(q,plaster)*wts.y;
    if(wts.z>0.0) h0+=bodyRelief(q,tang,load,furrow,fur0)*wts.z;
    if(wts.w>0.0) h0+=rawSplat*wts.w;
    vec2 gProc=vec2(heightAt(q+vec2(E,0.0),tang,load,wts,sd,plaster,furrow)-h0,
                    heightAt(q+vec2(0.0,E),tang,load,wts,sd,plaster,furrow)-h0)/E;
    vec2 g=gProc*1.8+bGrad*0.46*smoothstep(0.30,0.68,body);
    vec3 N=normalize(vec3(-g*1.9,1.0));
    float la=radians(u_light);
    vec3 L=normalize(vec3(cos(la),sin(la),0.72));
    vec3 F=normalize(vec3(-cos(la),-sin(la),1.35));
    float relief=((dot(N,L)-0.615)*0.80+(dot(N,F)-0.630)*0.26)*u_impasto;

    float pale=smoothstep(0.25,0.80,lum(color));
    float rel=relief;
    color*=exp(rel*1.00);
    color+=pow(max(rel,0.0),2.40)*mix(0.12,0.06,pale);

    if(body*u_dry>0.0){
        vec2 qw=rot(0.41)*q+70.0*(vec2(vnoise(q*0.0019+3.0),vnoise(q*0.0019+29.0))-0.5);
        float dl=fbm3(qw*0.0024+sd*0.7+5.0)*0.66+fbm3(qw*0.012+21.0)*0.34;
        float streak=licStreak(q,tang,0.034,11.0,3.0);
        float thin=smoothstep(0.60,0.22,dl)*smoothstep(0.22,0.74,streak);
        float crown=smoothstep(0.30,0.85,weave0);
        float scratch=0.55*smoothstep(0.60,0.93,licStreak(q,tang,0.055,11.0,7.0))
                     *smoothstep(0.24,0.72,fbm3(qw*0.0045+33.0));
        scratch+=0.26*smoothstep(0.74,0.97,licStreak(q,tang,0.085,7.0,91.0));
        scratch+=0.45*furrow*smoothstep(0.32,0.08,fur0);
        float skip=(thin*(0.28+0.72*crown)+scratch*0.85)*body*u_dry;
        vec3 substrate=mix(clamp(color*1.35+vec3(0.30,0.27,0.24),0.0,1.0),othColor,othMix);
        color=mix(color,substrate,clamp(skip,0.0,1.0));
    }

    vec2 uv=p/u_resolution;
    float amb=1.0+dot(uv-0.5,vec2(cos(la),sin(la)))*0.34
               +(fbm3(uv*1.4+sd)-0.5)*0.16;
    vec2 v=(uv-0.5)*vec2(1.0,0.95);
    amb*=1.0-0.30*dot(v,v);
    color*=amb*(0.955+0.09*fbm3(q*0.085+sd));

    gl_FragColor=vec4(clamp(color,0.0,1.0)*src.a,src.a);
}
