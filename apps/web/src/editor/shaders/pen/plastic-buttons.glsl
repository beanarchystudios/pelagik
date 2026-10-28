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
 vec2 hp=p-vec2(78.0,u_resolution.y-54.0);
 hp=mat2(0.866,-0.5,0.5,0.866)*hp;
 vec2 g=hp/vec2(51.0,24.0);
 float outer=length(g);
 vec2 g2=(hp-vec2(5.0,-9.0))/vec2(52.0,24.0);
 float crescent=(1.0-smoothstep(0.96,1.04,outer))*smoothstep(0.98,1.06,length(g2));
 crescent*=smoothstep(0.0,13.0,d);
 col=mix(col,vec3(1.0,0.96,0.91),crescent*u_gloss*0.88);
 gl_FragColor=vec4(col,1.0);
}
