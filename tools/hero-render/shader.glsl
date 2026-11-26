#version 300 es
precision highp float;
uniform vec2 uRes;
uniform float uYaw, uPitch, uPPU; // pixels per unit
uniform vec2 uCenter;            // world point (x,y on screen plane) at canvas center
uniform vec3 J[64];
uniform int uHero;               // 0 = guanyu, 1 = lubu
uniform float uT;
out vec4 outC;

#define PEL J[0]
#define CHE J[1]
#define NEC J[2]
#define HEA J[3]
#define SHL J[4]
#define SHR J[5]
#define ELL J[6]
#define ELR J[7]
#define HAL J[8]
#define HAR J[9]
#define HIL J[10]
#define HIR J[11]
#define KNL J[12]
#define KNR J[13]
#define ANL J[14]
#define ANR J[15]
#define TOL J[16]
#define TOR J[17]
#define WB  J[18]
#define WT  J[19]
#define WNV J[20]
#define BF  J[21]
#define BU  J[22]
#define HEM J[23]
#define CAPEV J[24]
#define HF  J[25]
#define TASV J[26]
// feathers 32..39 and 40..47, beard 48..51

// materials
#define M_SKIN 1.
#define M_ROBE 2.
#define M_GOLD 3.
#define M_SCALE 4.
#define M_HAIR 5.
#define M_BOOT 6.
#define M_STEEL 7.
#define M_WOOD 8.
#define M_RED 9.
#define M_CAPE 10.
#define M_GEM 11.
#define M_FEATH 12.
#define M_DARKCLOTH 13.
#define M_HAT 14.
#define M_TASSEL 15.

float sdCap(vec3 p, vec3 a, vec3 b, float r){vec3 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);return length(pa-ba*h)-r;}
float sdRC(vec3 p, vec3 a, vec3 b, float r1, float r2){ // round cone
  vec3 ba=b-a; float l2=dot(ba,ba); float rr=r1-r2; float a2=l2-rr*rr; float il2=1./l2;
  vec3 pa=p-a; float y=dot(pa,ba); float z=y-l2; vec3 xv=pa*l2-ba*y; float x2=dot(xv,xv);
  float y2=y*y*l2; float z2=z*z*l2; float k=sign(rr)*rr*rr*x2;
  if(sign(z)*a2*z2>k) return sqrt(x2+z2)*il2-r2;
  if(sign(y)*a2*y2<k) return sqrt(x2+y2)*il2-r1;
  return (sqrt(x2*a2*il2)+y*rr)*il2-r1;}
float sdEll(vec3 p, vec3 r){float k0=length(p/r);float k1=length(p/(r*r));return k0*(k0-1.)/k1;}
float smin(float a,float b,float k){float h=clamp(.5+.5*(b-a)/k,0.,1.);return mix(b,a,h)-k*h*(1.-h);}
float sdTorus(vec3 p, float R, float r){vec2 q=vec2(length(p.xz)-R,p.y);return length(q)-r;}

vec2 U(vec2 a, vec2 b){return a.x<b.x?a:b;}

// frame of body
vec3 bodyRight(){return normalize(cross(BU,BF));} // character's left actually; used symmetric

float blade2D_gy(vec2 q){ // x across (blade side +), y along shaft from blade base
  float a=length(q-vec2(-0.35,0.18))-0.52;
  float b=length(q-vec2(-0.64,0.31))-0.58;
  float d=max(a,-b);
  d=max(d,-(q.y+0.02));
  d=max(d,-(q.x+0.05));
  // back hook spike
  float hk=length(q-vec2(-0.09,0.10))-0.035;
  d=min(d,max(hk,-(q.x+0.03)+0.0*q.y));
  return d;}
float sdRhombus(vec2 p, vec2 b){p=abs(p);vec2 bb=b;float h=clamp((-2.*p.x*bb.x+2.*p.y*bb.y+bb.x*bb.x-bb.y*bb.y)/dot(bb,bb),-1.,1.);
  // simple approx
  float d=length(p-.5*bb*vec2(1.-h,1.+h));return d*sign(p.x*bb.y+p.y*bb.x-bb.x*bb.y);}
float blade2D_zy(vec2 q){
  float y=q.y-0.2; float w=0.058*(1.-smoothstep(-0.2,0.22,y)*0.85);
  float d=(length(vec2(q.x/max(w,0.004),y/0.22))-1.)*min(w,0.05);
  return d;}
float blade2D_lb(vec2 q){
  float tip=sdRhombus(q-vec2(0.,0.27),vec2(0.05,0.24));
  float cr=1e5;
  for(int s=-1;s<=1;s+=2){float fs=float(s);
    float a=length(q-vec2(fs*0.02,0.09))-0.15;
    float b=length(q-vec2(fs*-0.05,0.10))-0.15;
    float c=max(a,-b); c=max(c,-(q.x*fs-0.025)); cr=min(cr,c);}
  return min(tip,cr);}

vec2 weapon(vec3 p){
  vec3 u=normalize(WT-WB); vec3 n=normalize(WNV-u*dot(WNV,u)); vec3 v=cross(n,u);
  vec2 r=vec2(sdCap(p,WB,WT+u*(uHero==0?0.12:0.06),uHero==2?0.019:0.022),M_WOOD);
  // butt cap
  r=U(r,vec2(sdCap(p,WB,WB+u*0.06,0.028),M_GOLD));
  vec3 q=p-WT; vec2 q2=vec2(dot(q,v),dot(q,u)); float qz=dot(q,n);
  float d2=uHero==0?blade2D_gy(q2):uHero==1?blade2D_lb(q2):blade2D_zy(q2);
  float th=uHero==0?0.016:0.012; th*=clamp(1.-max(d2,-0.05)/-0.05*0.,0.,1.);
  // beveled: thinner near edge
  float thick=mix(0.003,th,clamp(-d2/0.04,0.,1.));
  float bd=max(d2,abs(qz)-thick);
  r=U(r,vec2(bd*0.8,M_STEEL));
  // collar / dragon head
  if(uHero==0){
    r=U(r,vec2(sdEll(q-u*0.0+v*0.02,vec3(0.05,0.07,0.05)),M_GOLD));
    r=U(r,vec2(sdCap(p,WT-u*0.08,WT-u*0.02,0.032),M_GOLD));
  } else {
    r=U(r,vec2(sdCap(p,WT-u*0.02,WT+u*0.04,0.03),M_GOLD));
  }
  // tassel hanging under the head
  vec3 ta=WT-u*0.05; vec3 tb=ta+TASV;
  r=U(r,vec2(sdRC(p,ta,tb,0.018,0.05)*0.9,M_TASSEL));
  return r;}

vec2 body(vec3 p){
  vec3 fw=normalize(BF), up=normalize(BU), rt=normalize(cross(up,fw));
  vec2 r=vec2(1e5,0.);
  // legs / boots
  float lg=min(sdRC(p,HIL,KNL,0.075,0.06),sdRC(p,HIR,KNR,0.075,0.06));
  float shin=min(sdRC(p,KNL,ANL,0.06,0.045),sdRC(p,KNR,ANR,0.06,0.045));
  r=U(r,vec2(lg,M_DARKCLOTH));
  float boot=min(sdRC(p,ANL,TOL,0.05,0.035),sdRC(p,ANR,TOR,0.05,0.035));
  boot=min(boot,min(sdCap(p,mix(KNL,ANL,.45),ANL,0.055),sdCap(p,mix(KNR,ANR,.45),ANR,0.055)));
  r=U(r,vec2(min(shin+0.004,boot),M_BOOT));
  // torso
  float tor=sdRC(p,PEL+up*0.02,CHE,0.16,0.2);
  tor=smin(tor,sdEll(p-CHE-up*0.03,vec3(0.24,0.15,0.16)),0.05);
  r=U(r,vec2(tor,M_ROBE));
  // chest armor plates
  float ch=sdEll(p-CHE-fw*0.05+up*0.0,vec3(0.22,0.16,0.14));
  ch=max(ch,-(dot(p-CHE,fw)-0.0));
  r=U(r,vec2(ch,M_SCALE));
  // belly beast face / belt
  vec3 bp=p-(PEL+up*0.17);
  float belt=sdTorus(vec3(dot(bp,rt),dot(bp,up),dot(bp,fw))*vec3(1.,1.,1.15),0.165,0.032);
  r=U(r,vec2(belt,M_GOLD));
  float beast=sdEll(p-(PEL+up*0.2+fw*0.15),vec3(0.07,0.06,0.04));
  r=U(r,vec2(beast,uHero==0?M_GOLD:M_GOLD));
  // skirt
  float hemR=uHero==0?0.23:uHero==1?0.2:0.21;
  float sk=sdRC(p,PEL+up*0.08,HEM-up*0.12,0.17,hemR+0.02);
  sk=max(sk,-dot(p-HEM,vec3(0.,1.,0.)));
  r=U(r,vec2(sk,uHero==1?M_RED:M_ROBE));
  // armored tassets (front + sides) — shorter, scale pattern
  vec3 tasEnd=mix(PEL,HEM,uHero==0?0.5:0.62);
  float ts=sdRC(p,PEL+up*0.05,tasEnd,0.19,0.24);
  ts=max(ts,-(dot(p-PEL,fw)+0.06));
  ts=max(ts,0.075-abs(dot(p-PEL,rt)));
  r=U(r,vec2(sdRC(p,PEL+up*0.05,mix(PEL,HEM,0.8),0.18,0.22)+0.0,uHero==1?M_RED:M_ROBE));
  r=U(r,vec2(ts,M_SCALE));
  // shoulders + pauldrons
  for(int s=0;s<2;s++){
    vec3 S=s==0?SHL:SHR, E=s==0?ELL:ELR, H=s==0?HAL:HAR;
    vec3 out_=normalize(S-CHE);
    // sleeve
    float sl=sdRC(p,S,E,0.08,0.07);
    float fa=sdRC(p,E,H,0.07,0.055);
    r=U(r,vec2(min(sl,fa),M_ROBE));
    // bracer
    float br=sdRC(p,mix(E,H,0.3),mix(E,H,0.9),0.058,0.048);
    r=U(r,vec2(br,M_GOLD));
    // hand
    r=U(r,vec2(sdEll(p-H,vec3(0.042)),uHero==0?M_BOOT:M_BOOT));
    // pauldron (layered)
    vec3 pc=S+out_*0.035+up*0.03;
    float pd=sdEll(p-pc,vec3(0.125,0.095,0.125));
    float pd2=sdEll(p-(pc-up*0.07+out_*0.03),vec3(0.13,0.08,0.13));
    float pdl=min(pd,pd2);
    pdl=max(pdl,-(dot(p-pc,up)+0.11));
    r=U(r,vec2(pdl,M_SCALE));
    // pauldron rim (gold)
    r=U(r,vec2(sdEll(p-(pc+up*0.035),vec3(0.085,0.05,0.085)),M_GOLD));
  }
  // neck
  r=U(r,vec2(sdCap(p,CHE+up*0.1,NEC+up*0.04,0.055),M_SKIN));
  // collar
  vec3 cp=p-(CHE+up*0.13);
  float col=sdTorus(vec3(dot(cp,rt),dot(cp,up),dot(cp,fw)),0.08,0.03);
  r=U(r,vec2(col,M_GOLD));
  // head
  vec3 hf=normalize(HF); vec3 hr=normalize(cross(up,hf));
  vec3 hq=p-HEA; vec3 hl=vec3(dot(hq,hr),dot(hq,up),dot(hq,hf));
  hl/=1.1;
  float head=sdEll(hl,vec3(0.088,0.108,0.098));
  float nose=sdEll(hl-vec3(0.,-0.005,0.09),vec3(0.018,0.03,0.02));
  head=smin(head,nose,0.02);
  float jaw=sdEll(hl-vec3(0.,-0.05,0.03),vec3(0.07,0.06,0.07));
  head=smin(head,jaw,0.03);
  r=U(r,vec2(head,M_SKIN));
  if(uHero==0){
    // green hat / headscarf
    float hat=sdEll(hl-vec3(0.,0.035,-0.01),vec3(0.1,0.095,0.105));
    hat=max(hat,-(hl.y-0.035-hl.z*0.25));
    float knot=sdEll(hl-vec3(0.,0.11,-0.03),vec3(0.05,0.045,0.05));
    r=U(r,vec2(min(hat,knot),M_HAT));
    // gold band and front jewel
    float band=sdEll(hl-vec3(0.,0.045,0.0),vec3(0.103,0.03,0.108));
    band=max(band,abs(hl.y-0.04-hl.z*0.25)-0.014);
    r=U(r,vec2(band,M_GOLD));
    r=U(r,vec2(sdEll(hl-vec3(0.,0.06,0.1),vec3(0.018)),M_GEM));
    // tails of headscarf flowing back
    for(int s=-1;s<=1;s+=2){float fs=float(s);
      vec3 a=HEA+hr*fs*0.04-hf*0.09+up*0.03; vec3 b=a-hf*0.08+up*-0.18+CAPEV*0.3+hr*fs*0.03;
      r=U(r,vec2(sdRC(p,a,b,0.02,0.028)*0.9,M_HAT));}
    // beard (chain)
    float bd=sdRC(p,J[48],J[49],0.045,0.04);
    bd=smin(bd,sdRC(p,J[49],J[50],0.04,0.03),0.02);
    bd=smin(bd,sdRC(p,J[50],J[51],0.03,0.012),0.02);
    // sideburns + moustache
    bd=min(bd,sdCap(hl,vec3(0.075,-0.0,0.02),vec3(0.06,-0.07,0.05),0.017));
    bd=min(bd,sdCap(hl,vec3(-0.075,-0.0,0.02),vec3(-0.06,-0.07,0.05),0.017));
    bd=min(bd,sdCap(hl,vec3(-0.035,-0.042,0.094),vec3(0.035,-0.042,0.094),0.011));
    r=U(r,vec2(bd,M_HAIR));
  } else if(uHero==2){
    // silver helmet
    float hm=sdEll(hl-vec3(0.,0.03,-0.005),vec3(0.1,0.1,0.108));
    hm=max(hm,-(hl.y-0.03-hl.z*0.3));
    float neckg=sdEll(hl-vec3(0.,-0.02,-0.04),vec3(0.105,0.09,0.09)); neckg=max(neckg,hl.z+0.0);
    hm=min(hm,neckg);
    float brim=sdEll(hl-vec3(0.,0.035,0.035),vec3(0.105,0.022,0.1));
    hm=min(hm,brim);
    r=U(r,vec2(hm,M_GOLD));
    float ridge=sdCap(hl,vec3(0.,0.09,0.09),vec3(0.,0.12,-0.06),0.016);
    r=U(r,vec2(ridge,M_SCALE));
    // plume (red tassel spike)
    vec3 pt=HEA+up*0.14*1.1;
    r=U(r,vec2(sdRC(p,pt,pt+up*0.06,0.022,0.008),M_GOLD));
    vec3 pb=pt+up*0.05; vec3 pe=pb+up*0.05-HF*0.16+CAPEV*0.4;
    r=U(r,vec2(sdRC(p,pb,pe,0.03,0.05)*0.9,M_TASSEL));
    r=U(r,vec2(sdEll(hl-vec3(0.,0.065,0.11),vec3(0.016)),M_GEM));
  } else {
    // hair
    float hair=sdEll(hl-vec3(0.,0.02,-0.015),vec3(0.094,0.1,0.1));
    hair=max(hair,-(hl.z-0.02-hl.y*0.6+0.0));
    r=U(r,vec2(hair,M_HAIR));
    // crown
    vec3 cq=hl-vec3(0.,0.095,-0.0);
    float cr=sdEll(cq,vec3(0.075,0.05,0.08));
    cr=max(cr,-(cq.y+0.012));
    float crf=sdEll(cq-vec3(0.,0.03,0.05),vec3(0.05,0.06,0.02)); // front plate
    r=U(r,vec2(min(cr,crf),M_GOLD));
    r=U(r,vec2(sdEll(cq-vec3(0.,0.04,0.07),vec3(0.018)),M_GEM));
    // band around forehead
    float band=sdEll(hl-vec3(0.,0.05,0.0),vec3(0.097,0.022,0.105));
    r=U(r,vec2(band,M_GOLD));
    // pheasant feathers
    float fd=1e5;
    for(int i=0;i<7;i++){float k=float(i)/7.;
      fd=min(fd,sdCap(p,J[32+i],J[33+i],mix(0.022,0.009,k)));
      fd=min(fd,sdCap(p,J[40+i],J[41+i],mix(0.022,0.009,k)));}
    r=U(r,vec2(fd,M_FEATH));
    // red ribbon / tassel puffs on shoulders
    r=U(r,vec2(sdEll(p-(CHE+up*0.16-fw*0.06),vec3(0.07,0.04,0.06)),M_RED));
  }
  // cape (shell behind body)
  {
    vec3 cq=p-(CHE+up*0.12+fw*0.06);
    float y=dot(cq,up);
    float depth=max(0.,-y);
    cq-=CAPEV*depth*depth*1.2;
    vec3 hz=cq-up*dot(cq,up);
    float R=0.2+0.10*depth+0.03*sin(uT*3.+depth*6.);
    float bot=uHero==0?1.3:1.25;
    float sh=abs(length(hz)-R)-0.012;
    sh=max(sh,dot(hz,fw)+0.04+0.02*depth);
    sh=max(sh,y-0.0);
    sh=max(sh,-y-bot+0.04*sin(dot(hz,rt)*25.));
    // fold wiggle
    r=U(r,vec2(sh*0.7,M_CAPE));
  }
  return r;}

vec2 map(vec3 p){
  vec2 r=body(p);
  r=U(r,weapon(p));
  return r;}

vec3 calcN(vec3 p){vec2 e=vec2(0.0015,0.);return normalize(vec3(map(p+e.xyy).x-map(p-e.xyy).x,map(p+e.yxy).x-map(p-e.yxy).x,map(p+e.yyx).x-map(p-e.yyx).x));}

vec3 rotY(vec3 v,float a){float c=cos(a),s=sin(a);return vec3(v.x*c+v.z*s,v.y,-v.x*s+v.z*c);}

float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}

vec3 albedo(float m, vec3 p, vec3 n, out float spec, out float shin){
  spec=0.05; shin=8.;
  vec3 fw=normalize(BF), up=normalize(BU);
  if(m==M_SKIN){ return uHero==0?vec3(0.72,0.24,0.16):vec3(0.93,0.72,0.56);}
  if(m==M_ROBE){
    vec3 base=uHero==0?vec3(0.07,0.36,0.2):uHero==1?vec3(0.45,0.05,0.05):vec3(0.1,0.17,0.4);
    // folds
    float ang=atan(dot(p-PEL,cross(up,fw)),dot(p-PEL,fw));
    base*=0.85+0.15*sin(ang*9.+p.y*4.);
    // gold hem band
    float hy=dot(p-HEM,up);
    if(hy<0.06 && hy>0.025) return vec3(0.85,0.62,0.2);
    if(hy<0.02) return base*0.6;
    // cloud embroidery dots
    float e=sin(p.x*60.)*sin(p.y*60.)*sin(p.z*60.);
    if(e>0.55 && hy<0.4) base=mix(base,vec3(0.8,0.6,0.2),0.6);
    return base;}
  if(m==M_GOLD){spec=0.9;shin=30.;return uHero==2?vec3(0.82,0.85,0.9):vec3(0.9,0.64,0.2);}
  if(m==M_SCALE){spec=0.7;shin=24.;
    vec2 uv=vec2(p.x+p.z*0.5,p.y)*vec2(17.,20.);
    float row=floor(uv.y); uv.x+=mod(row,2.)*0.5;
    vec2 f=fract(uv)-vec2(.5,.75);
    float d=length(f*vec2(1.,1.3));
    float edge=smoothstep(uHero==1?0.44:0.35,0.55,d);
    vec3 gc=uHero==0?vec3(0.78,0.56,0.18):uHero==1?vec3(0.42,0.1,0.09):vec3(0.72,0.76,0.82);
    vec3 ec=uHero==1?vec3(0.85,0.6,0.2):gc*0.45;
    return mix(gc,ec,edge);}
  if(m==M_HAIR){ return vec3(0.04,0.035,0.035)*(0.7+0.6*hash(floor(p*180.)));}
  if(m==M_BOOT){return vec3(0.12,0.08,0.06);}
  if(m==M_STEEL){spec=1.2;shin=50.; return vec3(0.75,0.8,0.85);}
  if(m==M_WOOD){spec=0.4;shin=20.; return uHero==0?vec3(0.25,0.07,0.04):uHero==1?vec3(0.35,0.05,0.05):vec3(0.8,0.82,0.86);}
  if(m==M_RED){float hy=dot(p-HEM,vec3(0,1,0)); if(hy<0.05&&hy>0.02) return vec3(0.85,0.62,0.2); return vec3(0.45,0.05,0.05)*(0.85+0.15*sin(atan(p.x,p.z)*9.));}
  if(m==M_CAPE){vec3 cc=uHero==0?vec3(0.06,0.3,0.16):uHero==1?vec3(0.5,0.05,0.05):vec3(0.72,0.77,0.86); float hy=dot(p-HEM,vec3(0,1,0)); if(hy<-0.02&&hy>-0.2) cc=mix(cc,uHero==2?vec3(0.2,0.35,0.7):vec3(0.85,0.62,0.2),0.0); return cc;}
  if(m==M_GEM){spec=1.2;shin=60.;return uHero==0?vec3(0.1,0.7,0.4):uHero==1?vec3(0.55,0.15,0.85):vec3(0.2,0.5,1.);}
  if(m==M_FEATH){
    float k=length(p-J[32]);
    float k2=length(p-J[40]);
    float t=min(k,k2);
    float band=step(0.5,fract(t*14.));
    return mix(vec3(0.85,0.75,0.5),vec3(0.25,0.15,0.08),band);}
  if(m==M_DARKCLOTH){return uHero==0?vec3(0.05,0.18,0.1):uHero==1?vec3(0.2,0.04,0.04):vec3(0.06,0.09,0.2);}
  if(m==M_HAT){return vec3(0.06,0.4,0.22);}
  if(m==M_TASSEL){return vec3(0.75,0.08,0.06)*(0.75+0.4*hash(floor(p*150.)));}
  return vec3(1,0,1);}

void main(){
  vec2 fc=gl_FragCoord.xy;
  vec2 sp=(fc-uRes*0.5)/uPPU + uCenter;
  float pc=cos(uPitch), ps=sin(uPitch);
  vec3 fwd=vec3(0.,-ps,-pc);
  vec3 rightV=vec3(1.,0.,0.), upV=vec3(0.,pc,-ps);
  vec3 ro=rightV*sp.x+upV*sp.y-fwd*6.;
  vec3 rl=rotY(ro,-uYaw), rd=rotY(fwd,-uYaw);
  float t=0.; vec2 h; bool hit=false;
  for(int i=0;i<160;i++){
    h=map(rl+rd*t);
    if(h.x<0.0008){hit=true;break;}
    t+=h.x*0.9;
    if(t>14.)break;}
  if(!hit){outC=vec4(0.);return;}
  vec3 p=rl+rd*t;
  vec3 nl=calcN(p);
  vec3 n=rotY(nl,uYaw);
  float spec,shin; vec3 alb=albedo(h.y,p,nl,spec,shin);
  if(h.y==M_SKIN && uHero>=0){
    // face features
    vec3 up=normalize(BU), hf=normalize(HF), hr=normalize(cross(up,hf));
    vec3 hq=p-HEA; vec3 hl=vec3(dot(hq,hr),dot(hq,up),dot(hq,hf))/1.1;
    if(hl.z>0.04){
      float ex=abs(hl.x)-0.036, ey=hl.y-0.012;
      float eye=length(vec2(ex*0.7,ey*1.6));
      if(eye<0.011) alb=vec3(0.05);
      float brow=abs(hl.y-0.03-abs(hl.x)*0.25*(uHero==0?1.:-0.2));
      if(brow<0.008 && abs(hl.x)<0.06 && abs(hl.x)>0.012) alb=vec3(0.04);
      if(abs(hl.y+0.05)<0.004 && abs(hl.x)<0.02) alb*=0.6;
    }
  }
  vec3 L=normalize(vec3(-0.55,0.85,0.55));
  vec3 L2=normalize(vec3(0.7,0.3,-0.4));
  vec3 V=-fwd;
  float dif=max(dot(n,L),0.);
  // soft shadow
  float sh=1.;
  {vec3 Ll=rotY(L,-uYaw); float tt=0.02; for(int i=0;i<40;i++){float d=map(p+Ll*tt).x; sh=min(sh,10.*d/tt); tt+=clamp(d,0.01,0.1); if(sh<0.02||tt>2.5)break;} sh=clamp(sh,0.,1.);}
  // ao
  float ao=0.; for(int i=1;i<=4;i++){float hh=0.025*float(i); ao+=(hh-map(p+nl*hh).x)/hh;} ao=clamp(1.-ao*0.22,0.,1.);
  float hemi=0.5+0.5*n.y;
  vec3 col=alb*(0.22*hemi*vec3(0.95,0.95,1.1)*ao + 1.35*dif*mix(0.3,1.,sh)*vec3(1.05,0.98,0.88) + 0.3*max(dot(n,L2),0.)*vec3(0.6,0.7,1.));
  vec3 Hh=normalize(L+V);
  col+=spec*pow(max(dot(n,Hh),0.),shin)*vec3(1.,0.95,0.8)*sh;
  float rim=pow(1.-max(dot(n,V),0.),3.);
  col+=rim*0.18*alb*ao;
  col=pow(col,vec3(0.92));
  outC=vec4(clamp(col,0.,1.),1.);
}
