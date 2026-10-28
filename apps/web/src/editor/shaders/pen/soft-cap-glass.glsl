precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/** @sdf */
uniform sampler2D u_shape;
/**
 * @backdrop
 * @mipmap
 */
uniform sampler2D u_backdrop;
/**
 * @label Bevel
 * @default 42
 * @range 2, 60
 */
uniform float u_bevel;
/**
 * @label Refraction
 * @default 85
 * @range 0, 100
 */
uniform float u_depth;
/**
 * @label Frost
 * @default 0.3
 * @range 0, 4
 */
uniform float u_frost;
/**
 * @label Sheen
 * @default 0.7
 * @range 0, 1.5
 */
uniform float u_sheen;
/**
 * @label Rim
 * @default 0.48
 * @range 0, 1.5
 */
uniform float u_rim;
/**
 * @label Shade
 * @default 0.22
 * @range 0, 0.5
 */
uniform float u_shade;
void main(){
  vec2 p=gl_FragCoord.xy;
  vec2 uv=p/u_resolution;
  vec4 field=texture2D(u_shape,uv);
  float d=max(field.r,0.0);
  vec2 inward=field.gb/max(length(field.gb),0.0001);
  float t=clamp(d/max(u_bevel,1.0),0.0,1.0);
  float edge=1.0-t;
  float h=sqrt(max(1.0-edge*edge,0.001));
  vec3 normal=normalize(vec3(-inward*edge/max(h,0.14),1.0));
  vec3 ray=refract(vec3(0.0,0.0,-1.0),normal,0.66667);
  vec2 offset=ray.xy/max(-ray.z,0.2)*u_depth*(0.4+0.6*h);
  offset*=0.12+0.88*smoothstep(0.35,0.9,uv.x);
  vec2 q=(p+offset)/u_resolution;
  vec3 color=texture2D(u_backdrop,q).rgb*0.4;
  color+=texture2D(u_backdrop,q+vec2(u_frost,0.0)/u_resolution).rgb*0.15;
  color+=texture2D(u_backdrop,q-vec2(u_frost,0.0)/u_resolution).rgb*0.15;
  color+=texture2D(u_backdrop,q+vec2(0.0,u_frost)/u_resolution).rgb*0.15;
  color+=texture2D(u_backdrop,q-vec2(0.0,u_frost)/u_resolution).rgb*0.15;
  vec2 outn=-inward;
  float key=pow(max(dot(outn,normalize(vec2(-0.4,0.92))),0.0),1.2);
  float kick=pow(max(dot(outn,normalize(vec2(0.4,-0.92))),0.0),2.0);
  float hair=exp(-pow((d-0.8)/0.65,2.0));
  float shoulder=exp(-d/10.0);
  float softbox=exp(-pow((uv.y-0.83)/0.16,2.0))*0.12;
  float lower=exp(-pow((uv.y-0.25)/0.19,2.0));
  color*=1.0-u_shade*lower*(0.35+0.65*edge);
  float lowerbox=exp(-pow((uv.x-0.78)/0.34,2.0)-pow((uv.y-0.11)/0.14,2.0));
  color+=vec3(u_sheen*(shoulder*(0.18*key+0.12*kick)+softbox*0.4+lowerbox*0.35));
  color=mix(color,vec3(0.98),clamp(hair*u_rim*(0.17+0.83*key+0.25*kick),0.0,0.9));
  gl_FragColor=vec4(clamp(color,0.0,1.0),1.0);
}
