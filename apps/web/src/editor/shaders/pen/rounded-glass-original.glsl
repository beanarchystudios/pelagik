precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @backdrop */
uniform sampler2D u_backdrop;
/** @content */
uniform sampler2D u_content;
/**
 * @label Thickness
 * @default 0.85
 * @range 0.1, 1
 */
uniform float u_thickness;
/**
 * @label Refraction
 * @default 1.2
 * @range 0, 3
 */
uniform float u_refraction;
/**
 * @label IOR
 * @default 1.46
 * @range 1, 2.4
 */
uniform float u_ior;
/**
 * @label Highlight
 * @default 0.65
 * @range 0, 2
 */
uniform float u_highlight;
/**
 * @label Shade
 * @default 0.22
 * @range 0, 0.6
 */
uniform float u_shade;
void main(){
 vec2 p=gl_FragCoord.xy;
 vec2 uv=p/u_resolution;
 float radius=min(u_resolution.x,u_resolution.y)*0.5;
 vec2 q=p-u_resolution*0.5;
 vec2 line=vec2(clamp(q.x,-u_resolution.x*0.5+radius,u_resolution.x*0.5-radius),0.0);
 vec2 v=q-line;
 float len=length(v);
 vec2 outward=v/max(len,0.001);
 float d=radius-len;
 float bw=radius*u_thickness;
 float t=clamp(d/max(bw,1.0),0.0,1.0);
 float z=sqrt(max(1.0-(1.0-t)*(1.0-t),0.001));
 vec3 n=normalize(vec3(outward*(1.0-t),z));
 vec3 ray=refract(vec3(0.0,0.0,-1.0),n,1.0/max(u_ior,1.0));
 vec2 off=ray.xy/max(-ray.z,0.15)*bw*u_refraction*(0.35+0.65*z);
 vec3 col=texture2D(u_backdrop,(p+off)/u_resolution).rgb;
 float shoulder=exp(-max(d,0.0)/(radius*0.33));
 col*=1.0-u_shade*(0.35+0.65*shoulder);
 float top=pow(max(dot(outward,normalize(vec2(-0.35,1.0))),0.0),2.0);
 float bottom=pow(max(dot(outward,normalize(vec2(0.35,-1.0))),0.0),3.0);
 float rim=exp(-pow((d-1.65)/1.0,2.0));
 float inner=exp(-pow((d-4.0)/2.0,2.0));
 col+=u_highlight*(rim*(top*0.95+bottom*0.8+0.07)+inner*top*0.12);
 col+=u_highlight*0.095*pow(1.0-n.z,2.0);
 col+=0.045*exp(-pow((d-radius*0.27)/(radius*0.22),2.0))*bottom;
 float alpha=smoothstep(-0.6,0.6,d);
 vec4 label=texture2D(u_content,uv);
 vec3 glass=clamp(col,0.0,1.0)*alpha;
 gl_FragColor=vec4(label.rgb+glass*(1.0-label.a),label.a+alpha*(1.0-label.a));
}
