precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/**
 * @label Resin color
 * @color
 * @default #FF580D
 */
uniform vec3 u_color;
/**
 * @label Pressed
 * @default 0
 * @range 0, 1
 */
uniform float u_pressed;
/**
 * @label Bevel
 * @default 23
 * @range 8, 45
 */
uniform float u_bevel;
/**
 * @label Gloss
 * @default 0.85
 * @range 0, 1
 */
uniform float u_gloss;
void main(){
 vec2 p=gl_FragCoord.xy;
 vec2 q=p-u_resolution*0.5;
 float r=u_resolution.y*0.5;
 float h=u_resolution.x*0.5-r;
 vec2 v=vec2(q.x-clamp(q.x,-h,h),q.y);
 float len=length(v);
 float d=r-len;
 vec2 outward=v/max(len,0.001);
 float shoulder=1.0-smoothstep(0.0,u_bevel,d);
 vec3 n=normalize(vec3(outward*shoulder*1.5,1.0));
 vec3 light=normalize(vec3(-0.42,0.7,0.68));
 float diffuse=dot(n,light);
 vec3 col=u_color*(0.83+0.31*diffuse);
 float lower=shoulder*smoothstep(0.1,0.85,-outward.y);
 col*=1.0-0.33*lower*(1.0-u_pressed);
 float soft=exp(-dot((q-vec2(-65.0,32.0))/vec2(135.0,95.0),(q-vec2(-65.0,32.0))/vec2(135.0,95.0)));
 col=mix(col,vec3(1.0,0.80,0.66),soft*0.42*u_gloss);
 float edgeLight=exp(-pow((d-3.0)/1.5,2.0))*max(0.0,outward.y*0.75-outward.x*0.4);
 col=mix(col,vec3(1.0,0.91,0.86),edgeLight*0.8*(1.0-u_pressed));
 float rim=1.0-smoothstep(0.8,3.5,d);
 col=mix(col,vec3(0.12,0.045,0.025),rim*0.88);
 float recess=exp(-max(d,0.0)/8.0)*smoothstep(-0.35,0.7,outward.y);
 col*=1.0-u_pressed*recess*0.94;
 vec2 arc=p-vec2(r,r);
 float angle=atan(arc.y,arc.x);
 float t=clamp((angle-1.80)/1.03,0.0,1.0);
 float taper=pow(max(sin(t*3.14159265),0.0),0.65);
 float arcRadius=r*(0.90+0.025*(t-0.5));
 float halfWidth=r*0.033*taper;
 float aa=max(0.7,r*0.003);
 float crescent=(1.0-smoothstep(max(halfWidth-aa,0.0),halfWidth+aa,abs(length(arc)-arcRadius)));
 crescent*=smoothstep(0.0,0.045,t)*(1.0-smoothstep(0.955,1.0,t));
 col=mix(col,vec3(1.0,0.98,0.94),crescent*u_gloss);
 gl_FragColor=vec4(col,1.0);
}
