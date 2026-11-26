# 從 shader.glsl 產生 class.glsl：職業角色（uHero 3..10 = 男騎/女騎/男妖/女妖/男法/女法/男黑妖/女黑妖）
s=open('shader.glsl').read()
def rep(a,b,c=1):
    global s
    assert s.count(a)==c,(a[:70],s.count(a)); s=s.replace(a,b)
rep('out vec4 outC;\n','''out vec4 outC;
int CL(){return uHero>=3?(uHero-3)/2:-1;}           // 0 騎士 1 妖精 2 法師 3 黑妖
bool FEM(){return uHero>=3&&((uHero-3)-(uHero-3)/2*2)==1;}
vec3 cRobe(){int c=CL();return c==0?vec3(0.36,0.05,0.05):c==1?vec3(0.12,0.32,0.12):c==2?vec3(0.13,0.15,0.45):vec3(0.13,0.09,0.17);}
vec3 cArmor(){int c=CL();return c==0?vec3(0.6,0.63,0.68):c==1?vec3(0.45,0.3,0.15):c==2?vec3(0.22,0.22,0.55):vec3(0.17,0.15,0.2);}
vec3 cTrim(){int c=CL();return c==0?vec3(0.78,0.8,0.84):c==3?vec3(0.6,0.6,0.68):vec3(0.88,0.68,0.28);}
vec3 cCape(){int c=CL();return c==0?vec3(0.5,0.05,0.05):c==1?vec3(0.1,0.36,0.15):c==2?vec3(0.1,0.12,0.42):vec3(0.2,0.08,0.24);}
vec3 cPants(){int c=CL();return c==0?vec3(0.12,0.12,0.14):c==1?vec3(0.27,0.19,0.1):c==2?vec3(0.08,0.08,0.22):vec3(0.07,0.06,0.09);}
vec3 cHair(){int c=CL();bool f=FEM();return c==0?vec3(0.32,0.19,0.08):c==1?vec3(0.92,0.8,0.46):c==2?(f?vec3(0.55,0.28,0.12):vec3(0.24,0.15,0.08)):vec3(0.9,0.9,0.96);}
vec3 cGem(){int c=CL();return c==0?vec3(0.8,0.1,0.1):c==1?vec3(0.1,0.8,0.35):c==2?vec3(0.25,0.55,1.):vec3(0.65,0.2,0.9);}
''')
# ---- weapon per class
rep('vec2 weapon(vec3 p){\n  vec3 u=normalize(WT-WB); vec3 n=normalize(WNV-u*dot(WNV,u)); vec3 v=cross(n,u);\n','''vec2 weapon(vec3 p){
  vec3 u=normalize(WT-WB); vec3 n=normalize(WNV-u*dot(WNV,u)); vec3 v=cross(n,u);
  if(uHero>=3){int c=CL();
    if(c==2){ // 法杖
      vec3 A=HAR-u*0.55, B=HAR+u*0.9, O=HAR+u*0.99;
      vec2 r=vec2(sdCap(p,A,B,0.02),M_WOOD);
      r=U(r,vec2(length(p-O)-0.055,M_GEM));
      vec3 oq=p-(O-u*0.04); r=U(r,vec2(sdTorus(vec3(dot(oq,v),dot(oq,u),dot(oq,n)).xzy,0.055,0.012),M_GOLD));
      r=U(r,vec2(length(p-A)-0.026,M_GOLD));
      return r;}
    float gL=c==0?0.42:c==1?0.1:0.08, bL=c==0?1.13:c==1?0.9:0.55, wd=c==0?0.05:c==1?0.032:0.03, gw=c==0?0.13:c==1?0.09:0.06;
    vec3 P0=HAR-u*(c==0?0.1:0.08), G0=HAR+u*gL, T0=G0+u*bL;
    vec2 r=vec2(sdCap(p,P0,G0,0.02),M_WOOD);
    r=U(r,vec2(length(p-P0)-0.032,M_GOLD));
    r=U(r,vec2(sdCap(p,G0-v*gw,G0+v*gw,0.02),M_GOLD));
    vec3 q=p-G0; float y=dot(q,u), x=dot(q,v)+(c==3?0.06*y*y:0.), z=dot(q,n); float L=bL;
    float w=wd*(1.-smoothstep(L*0.75,L,y))+0.004;
    float bd=max(max(abs(x)-w,abs(z)-0.009*(1.-abs(x)/max(w,0.001))-0.002),max(-y,y-L));
    r=U(r,vec2(bd*0.8,M_STEEL));
    return r;}
''')
# ---- head
rep('  } else if(uHero==2){\n    // silver helmet','''  } else if(uHero>=5){
    int c=CL(); bool f=FEM();
    // 頭髮（頭頂與後腦）
    float hair=sdEll(hl-vec3(0.,0.022,-0.018),vec3(0.097,0.102,0.102));
    hair=max(hair,-(hl.z-0.035-hl.y*0.7));
    if(c==2&&!f){ // 男法師：兜帽
      float hd=sdEll(hl-vec3(0.,0.03,-0.01),vec3(0.118,0.128,0.122));
      hd=max(hd,-(hl.z-0.02-hl.y*0.55)); hd=max(hd,-sdEll(hl-vec3(0.,0.02,0.0),vec3(0.1,0.11,0.105)));
      r=U(r,vec2(min(hd,sdRC(p,HEA-hf*0.1+up*0.06,HEA-hf*0.17-up*0.06,0.05,0.02)),M_ROBE));
      r=U(r,vec2(hair+0.004,M_HAIR));
    } else r=U(r,vec2(hair,M_HAIR));
    // 耳朵（妖精、黑妖）
    if(c==1||c==3) for(int s2=-1;s2<=1;s2+=2){float fs=float(s2);
      r=U(r,vec2(sdRC(hl,vec3(fs*0.085,0.0,0.0),vec3(fs*0.15,0.055,-0.035),0.02,0.004),M_SKIN));}
    // 頭飾：妖精、女法師金頭環；黑妖頭帶
    if(c==1||(c==2&&f)||c==3){
      float band=sdEll(hl-vec3(0.,0.045,0.0),vec3(0.1,0.018,0.106)); band=max(band,abs(hl.y-0.045)-0.01);
      r=U(r,vec2(band,M_GOLD));
      r=U(r,vec2(sdEll(hl-vec3(0.,0.05,0.104),vec3(0.014)),M_GEM));}
    // 長髮（女性；男妖精、男黑妖到肩）
    bool lng=f||c==1||c==3;
    if(lng){ float ln=f?0.36:0.16;
      vec3 a=HEA-hf*0.06+up*0.04; vec3 b=HEA-hf*0.11-up*ln+CAPEV*0.6*ln;
      r=U(r,vec2(sdRC(p,a,b,0.085,f?0.06:0.07),M_HAIR));}
    if(f) for(int s2=-1;s2<=1;s2+=2){float fs=float(s2);
      vec3 a=HEA+hr*fs*0.085+up*0.01+hf*0.01; vec3 b=HEA+hr*fs*0.13+hf*0.04-up*0.3+CAPEV*0.2;
      r=U(r,vec2(sdRC(p,a,b,0.038,0.03),M_HAIR));}
  } else if(uHero==2||uHero==3||uHero==4){
    // silver helmet''')
rep('    // plume (red tassel spike)\n    vec3 pt=HEA+up*0.14*1.1;','''    if(uHero>=3){
      float vis=sdEll(hl-vec3(0.,-0.01,0.03),vec3(0.098,0.112,0.088));
      r=U(r,vec2(vis,M_GOLD));
      r=U(r,vec2(sdCap(hl,vec3(-0.06,0.015,0.112),vec3(0.06,0.015,0.112),0.007),M_BOOT));
      vec3 pt2=HEA+up*0.12;
      r=U(r,vec2(sdRC(p,pt2,pt2+up*0.05-HF*0.1+CAPEV*0.4,0.03,0.045)*0.9,M_TASSEL));
      if(FEM()){vec3 a=HEA-HF*0.1+up*0.02; r=U(r,vec2(sdRC(p,a,a-HF*0.06-up*0.3+CAPEV*0.5,0.05,0.035),M_HAIR));
        vec3 hr2=normalize(cross(up,normalize(HF)));
        for(int s2=-1;s2<=1;s2+=2){float fs=float(s2); vec3 a2=HEA+hr2*fs*0.1-up*0.04+HF*0.02; r=U(r,vec2(sdRC(p,a2,a2+hr2*fs*0.03+HF*0.03-up*0.24,0.032,0.025),M_HAIR));}}
    } else {
    vec3 pt=HEA+up*0.14*1.1;''')
rep('    r=U(r,vec2(sdEll(hl-vec3(0.,0.065,0.11),vec3(0.016)),M_GEM));\n  } else {',
    '    r=U(r,vec2(sdEll(hl-vec3(0.,0.065,0.11),vec3(0.016)),M_GEM));\n    }\n  } else {')
# 法師沒有大肩甲：肩甲改小
rep('    float pd=sdEll(p-pc,vec3(0.125,0.095,0.125));','    float psz=(CL()==2?0.75:CL()==1||CL()==3?0.85:1.)*(FEM()?0.82:1.);\n    float pd=sdEll(p-pc,vec3(0.125,0.095,0.125)*psz);')
# cape length
rep('float bot=uHero==0?1.3:1.25;','float bot=uHero>=3?0.7:uHero==0?1.3:1.25;')
# ---- colors
rep('if(m==M_SKIN){ return uHero==0?','if(m==M_SKIN){ if(CL()==3) return vec3(0.55,0.47,0.62); return uHero==0?')
rep('vec3 base=uHero==0?vec3(0.07,0.36,0.2):uHero==1?vec3(0.45,0.05,0.05):vec3(0.1,0.17,0.4);',
    'vec3 base=uHero>=3?cRobe():uHero==0?vec3(0.07,0.36,0.2):uHero==1?vec3(0.45,0.05,0.05):vec3(0.1,0.17,0.4);')
rep('if(hy<0.06 && hy>0.025) return vec3(0.85,0.62,0.2);','if(hy<0.06 && hy>0.025) return uHero>=3?cTrim()*0.85:vec3(0.85,0.62,0.2);')
rep('if(e>0.55 && hy<0.4) base=mix(base,vec3(0.8,0.6,0.2),0.6);','if(e>0.55 && hy<0.4 && uHero<3) base=mix(base,vec3(0.8,0.6,0.2),0.6);')
rep('return uHero==2?vec3(0.82,0.85,0.9):vec3(0.9,0.64,0.2);}','return uHero>=3?cTrim():uHero==2?vec3(0.82,0.85,0.9):vec3(0.9,0.64,0.2);}')
rep('if(m==M_SCALE){spec=0.7;shin=24.;','if(m==M_SCALE){spec=0.7;shin=24.; if(uHero>=3&&CL()!=0){spec=0.25;shin=12.;return cArmor()*(0.9+0.1*sin(p.y*40.));}')
rep('vec3 gc=uHero==0?vec3(0.78,0.56,0.18):uHero==1?vec3(0.42,0.1,0.09):vec3(0.72,0.76,0.82);',
    'vec3 gc=uHero>=3?cArmor():uHero==0?vec3(0.78,0.56,0.18):uHero==1?vec3(0.42,0.1,0.09):vec3(0.72,0.76,0.82);')
rep('if(m==M_HAIR){ return','if(m==M_HAIR){ if(uHero>=3) return cHair()*(0.75+0.4*hash(floor(p*160.))); return')
rep('if(m==M_WOOD){spec=0.4;shin=20.; return','if(m==M_WOOD){spec=0.4;shin=20.; if(uHero>=3){int c=CL();return c==2?vec3(0.42,0.26,0.12):c==3?vec3(0.08,0.07,0.09):vec3(0.2,0.12,0.06);} return')
rep('if(m==M_CAPE){vec3 cc=uHero==0?','if(m==M_CAPE){if(uHero>=3) return cCape()*(0.85+0.15*sin(atan(p.x,p.z)*7.)); vec3 cc=uHero==0?')
rep('if(m==M_GEM){spec=1.2;shin=60.;return','if(m==M_GEM){spec=1.2;shin=60.;if(uHero>=3) return cGem(); return')
rep('if(m==M_DARKCLOTH){return','if(m==M_DARKCLOTH){if(uHero>=3) return cPants(); return')
rep('if(m==M_BOOT){return vec3(0.12,0.08,0.06);}','if(m==M_BOOT){return CL()==3?vec3(0.06,0.05,0.07):vec3(0.12,0.08,0.06);}')
open('class.glsl','w').write(s)
print('ok')
