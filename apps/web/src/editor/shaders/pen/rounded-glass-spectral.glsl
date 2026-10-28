precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @time */
uniform float u_time;
/** @backdrop */
uniform sampler2D u_backdrop;
/** @content */
uniform sampler2D u_content;
/**
 * @label Bevel width
 * @default 0.6
 * @range 0.05, 1
 */
uniform float u_bevel;
/**
 * @label Thickness
 * @default 0.85
 * @range 0.05, 2
 */
uniform float u_thickness;
/**
 * @label Refraction
 * @default 1.2
 * @range 0, 8
 */
uniform float u_refraction;
/**
 * @label Background distance
 * @default 0.35
 * @range 0, 3
 */
uniform float u_backDistance;
/**
 * @label IOR
 * @default 1.21
 * @range 1, 2.4
 */
uniform float u_ior;
/**
 * @label Chromatic aberration
 * @default 0.35
 * @range 0, 2
 */
uniform float u_dispersion;
/**
 * @label Distortion
 * @default 0.12
 * @range 0, 1
 */
uniform float u_distortion;
/**
 * @label Distortion scale
 * @default 2.5
 * @range 0.5, 8
 */
uniform float u_scale;
/**
 * @label Distortion speed
 * @default 0.15
 * @range 0, 2
 */
uniform float u_speed;
/**
 * @label Frosting
 * @default 0.4
 * @range 0, 12
 */
uniform float u_roughness;
/**
 * @label Glass tint
 * @color
 * @default #CAE8E0
 */
uniform vec3 u_tint;
/**
 * @label Absorption
 * @default 0.12
 * @range 0, 2
 */
uniform float u_absorption;
/**
 * @label Fresnel reflection
 * @default 0.45
 * @range 0, 2
 */
uniform float u_fresnel;
/**
 * @label Highlight
 * @default 0.65
 * @range 0, 2
 */
uniform float u_highlight;
/**
 * @label Light direction
 * @default 110
 * @range 0, 360
 */
uniform float u_angle;
/**
 * @label Shade
 * @default 0.22
 * @range 0, 0.8
 */
uniform float u_shade;
/**
 * @label Shade gradient
 * @default 0
 * @range 0, 1
 */
uniform float u_shadeGradient;
/**
 * @label Caustic
 * @default 0.3
 * @range 0, 2
 */
uniform float u_caustic;
/**
 * @label Edge width
 * @default 1.2
 * @range 0.3, 5
 */
uniform float u_edge;
/**
 * @label Grain
 * @default 0.006
 * @range 0, 0.08
 */
uniform float u_grain;
vec3 backdrop(vec2 p){
 vec2 uv=p/u_resolution;
 vec2 b=vec2(u_roughness)/u_resolution;
 vec3 c=texture2D(u_backdrop,uv).rgb*0.4;
 c+=texture2D(u_backdrop,uv+vec2(b.x,b.y)).rgb*0.15;
 c+=texture2D(u_backdrop,uv+vec2(-b.x,b.y)).rgb*0.15;
 c+=texture2D(u_backdrop,uv+vec2(b.x,-b.y)).rgb*0.15;
 c+=texture2D(u_backdrop,uv-b).rgb*0.15;
 return c;
}
vec2 refractOffset(vec2 q,vec2 axis,float radius,float ior){
 vec2 v=q-clamp(q,-axis,axis);
 float rho=clamp(length(v)/radius,0.0,1.0);
 float power=max(u_refraction,0.0)*max(u_thickness,0.0)*2.0*(1.0+u_backDistance);
 float eta=1.0+max(ior-1.0,0.0)*power;
 float angle=asin(rho);
 float mapped=sin(angle/eta);
 float scale=rho>0.0001 ? mapped/rho : 1.0/eta;
 return q*(scale-1.0);
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void main(){
 vec2 p=gl_FragCoord.xy;
 vec2 uv=p/u_resolution;
 vec2 q=p-u_resolution*0.5;
 float radius=min(u_resolution.x,u_resolution.y)*0.5;
 vec2 halfLine=max(u_resolution*0.5-vec2(radius),vec2(0.0));
 vec2 v=q-clamp(q,-halfLine,halfLine);
 float len=length(v);
 vec2 outward=v/max(len,0.001);
 float d=radius-len;
 float bw=max(radius*u_bevel,1.0);
 float k=1.0-clamp(d/bw,0.0,1.0);
 float z=sqrt(max(1.0-k*k,0.001));
 float time=u_time*u_speed;
 vec2 w=q/radius*u_scale;
 vec2 ripple=vec2(cos(w.x*1.4+time)*sin(w.y+time*0.7),sin(w.x*1.4+time)*cos(w.y+time*0.7));
 ripple+=0.35*vec2(cos(w.x*2.3-w.y+time*0.4),-cos(w.x*2.3-w.y+time*0.4));
 vec3 n=normalize(vec3(outward*k+ripple*u_distortion*0.22*(1.0-k*0.6),z));
 float split=u_dispersion*0.055;
 vec2 rippleOffset=ripple*u_distortion*radius*0.12;
 vec3 spectralSum=vec3(0.0);
 vec3 spectralWeight=vec3(0.0);
 for(int i=0;i<21;i++){
  float s=(float(i)+0.5)/21.0;
  float wavelength=mix(0.42,0.68,s);
  float bend=(1.0/(wavelength*wavelength)-3.305785)*0.80;
  vec2 offset=refractOffset(q,halfLine,radius,u_ior+split*bend)+rippleOffset;
  vec3 sensitivity=exp(-0.5*pow((vec3(s)-vec3(0.80,0.46,0.16))/vec3(0.24,0.21,0.22),vec3(2.0)));
  vec3 sampleColor=pow(max(backdrop(p+offset),vec3(0.0)),vec3(2.2));
  spectralSum+=sampleColor*sensitivity;
  spectralWeight+=sensitivity;
 }
 vec3 col=pow(spectralSum/max(spectralWeight,vec3(0.0001)),vec3(1.0/2.2));
 float path=u_thickness*(0.35+0.65*z);
 col*=exp(-(vec3(1.0)-u_tint)*u_absorption*path*2.0);
 float shadeFade=mix(1.0,clamp(uv.y,0.0,1.0),u_shadeGradient);
 col*=1.0-u_shade*(0.25+0.55*k)*shadeFade;
 float a=radians(u_angle);
 vec2 light=vec2(cos(a),sin(a));
 float top=pow(max(dot(outward,light),0.0),3.0);
 float bottom=pow(max(dot(outward,-light),0.0),5.0);
 float lip=exp(-pow((d-u_edge*1.1)/max(u_edge,0.2),2.0));
 float inner=exp(-pow((d-u_edge*3.0)/(u_edge*2.1),2.0));
 float f0=pow((u_ior-1.0)/(u_ior+1.0),2.0);
 float fresnel=f0+(1.0-f0)*pow(1.0-max(n.z,0.0),5.0);
 vec3 reflected=reflect(vec3(0.0,0.0,-1.0),n);
 float softbox=pow(max(dot(reflected,normalize(vec3(light*0.7,0.8))),0.0),12.0);
 col+=u_fresnel*(fresnel*0.22+softbox*0.16)*(1.0-u_roughness*0.025);
 col+=u_highlight*(lip*(top*0.95+bottom*0.65+0.055)+inner*top*0.10);
 float caustic=exp(-pow((d-bw*0.52)/max(bw*0.23,1.0),2.0))*bottom;
 col+=mix(vec3(1.0),u_tint,0.4)*caustic*u_caustic*0.22;
 col+=(hash(floor(p))-0.5)*u_grain;
 float alpha=smoothstep(-0.6,0.6,d);
 vec4 label=texture2D(u_content,uv);
 gl_FragColor=vec4(label.rgb+clamp(col,0.0,1.0)*alpha*(1.0-label.a),label.a+alpha*(1.0-label.a));
}
