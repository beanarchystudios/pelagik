precision highp float;
/** @resolution */
uniform vec2 u_resolution;
/**
 * @label Time of day (hours)
 * @default 7.5
 * @range 0, 24
 */
uniform float u_hour;
/**
 * @label Sun glow
 * @default 0.8
 * @range 0, 2
 */
uniform float u_sun;
/**
 * @label Haze
 * @default 0.5
 * @range 0, 1.5
 */
uniform float u_haze;
/**
 * @label Horizon
 * @default 0.46
 * @range 0.2, 0.7
 */
uniform float u_horizon;
/**
 * @label Curvature
 * @default 0.23
 * @range 0.02, 0.6
 */
uniform float u_curvature;
/**
 * @label Atmosphere
 * @default 1
 * @range 0.5, 1.6
 */
uniform float u_atmosphere;
/**
 * @label Dispersion
 * @default 1
 * @range 0, 2
 */
uniform float u_dispersion;
/**
 * @label Softness
 * @default 1
 * @range 0.3, 3
 */
uniform float u_softness;
/**
 * @label Film grain
 * @default 0.7
 * @range 0, 1.5
 */
uniform float u_grain;
/**
 * @label Exposure
 * @default 1
 * @range 0.5, 1.6
 */
uniform float u_exposure;
/**
 * @label Grain seed
 * @default 7
 * @range 0, 100
 */
uniform float u_seed;
float hash(vec2 p){
 vec3 q=fract(vec3(p.xyx)*vec3(0.1031,0.1030,0.0973));
 q+=dot(q,q.yzx+33.33+u_seed);
 return fract((q.x+q.y)*q.z);
}
float noise(vec2 p){
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float bell(float d,float c,float s){float v=(d-c)/s;return exp(-0.5*v*v);}
void main(){
 vec2 uv=gl_FragCoord.xy/u_resolution;
 vec2 film=uv*vec2(1920,1080);
 float x=uv.x-0.5;
 float limb=u_horizon-u_curvature*x*x;
 float d=(uv.y-limb)/u_atmosphere;
 float soft=0.0035*u_softness;
 float sky=smoothstep(-soft,soft*2.0,d);
 float angle=(u_hour-6.0)*0.261799388;
 float elevation=sin(angle);
 float day=smoothstep(-0.10,0.30,elevation);
 float high=smoothstep(0.12,0.82,elevation);
 float twilight=bell(elevation,-0.035,0.21);
 float evening=smoothstep(12.0,17.0,u_hour)*(1.0-smoothstep(20.0,24.0,u_hour));
 float sx=0.5-0.43*cos(angle);
 float sy=u_horizon-u_curvature*(sx-0.5)*(sx-0.5)+0.44*elevation;
 vec2 delta=(uv-vec2(sx,sy))*vec2(u_resolution.x/u_resolution.y,1.0);
 float r=length(delta);
 float facing=0.60+0.40*exp(-pow((uv.x-sx)/0.45,2.0));
 float altitude=max(d,0.0);
 vec3 night=mix(vec3(0.018,0.035,0.075),vec3(0.004,0.008,0.022),smoothstep(0.0,0.5,altitude));
 vec3 zenith=mix(vec3(0.16,0.34,0.55),vec3(0.07,0.32,0.68),high);
 vec3 low=mix(vec3(0.88,0.61,0.37),vec3(0.61,0.78,0.89),high);
 float falloff=exp(-altitude/(0.13+0.08*u_haze));
 vec3 daylight=mix(zenith,low,falloff);
 daylight=mix(daylight,vec3(0.70,0.77,0.81),u_haze*0.15*exp(-altitude/0.4));
 vec3 col=mix(night,daylight,day);
 vec3 warm=mix(vec3(0.92,0.32,0.055),vec3(1.0,0.20,0.045),evening);
 col+=twilight*facing*(vec3(0.18,0.30,0.43)*bell(d,0.24,0.13)
   +vec3(0.34,0.24,0.29)*bell(d,0.13,0.085)
   +warm*bell(d,0.04+0.008*u_dispersion,0.04+soft)
   +vec3(0.40,0.05,0.005)*bell(d,0.002-0.003*u_dispersion,0.016+soft));
 float solar=smoothstep(-0.075,0.025,elevation);
 vec3 sunColor=mix(vec3(1.0,0.44,0.12),vec3(1.0,0.97,0.85),high);
 float aureole=exp(-r*r/(0.004+0.011*u_haze));
 float broad=exp(-r*r/0.10);
 float disc=1.0-smoothstep(0.008,0.011+soft*0.4,r);
 col+=sunColor*u_sun*solar*(aureole*0.25+broad*0.075+disc*0.9);
 float veil=noise(film/220.0)*0.5+noise(film/81.0)*0.3+noise(film/29.0)*0.2-0.5;
 col*=1.0+veil*0.055;
 vec3 earth=mix(vec3(0.009,0.013,0.021),vec3(0.065,0.095,0.12),day);
 earth+=vec3(0.055,0.026,0.009)*twilight*facing*exp(min(d,0.0)/0.06);
 earth+=vec3(0.035,0.070,0.095)*day*exp(min(d,0.0)/0.12);
 col=mix(earth,col,sky);
 col*=u_exposure*(1.0-0.12*pow(abs(x)*2.0,2.0));
 float fine=hash(floor(film))+hash(floor(film)+vec2(93,173))-1.0;
 float clump=noise(film/2.1)-0.5;
 float coarse=noise(film/5.5)-0.5;
 float lum=dot(col,vec3(0.2126,0.7152,0.0722));
 float amp=u_grain*(0.022+0.09*sqrt(max(lum,0.0)));
 col+=(fine*0.8+clump*0.5+coarse*0.18)*amp;
 col+=vec3(hash(floor(film)+21.0)-0.5,hash(floor(film)+47.0)-0.5,hash(floor(film)+83.0)-0.5)*amp*0.18;
 gl_FragColor=vec4(clamp(col,0.0,1.0),1.0);
}
