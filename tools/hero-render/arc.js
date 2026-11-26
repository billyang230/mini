const {ATK}=require('./pose.js');const HS=(process.env.HEROES||'0,1,2').split(',').map(Number),DIR=process.env.DIR||'full';const fs=require('fs');
const M=JSON.parse(fs.readFileSync(DIR+'/meta.json'));
const PITCH=30*Math.PI/180,WW=5.4,WH=4.1,CX=0,CY=1.05;
const YAW={front:Math.PI/4,back:3*Math.PI/4};
const nrm=a=>{const l=Math.hypot(...a);return a.map(v=>v/l)};
for(const hero of HS)for(const view of ['front','back'])for(let f=1;f<6;f++){
 const pts=[];const A=ATK[f-1],B=ATK[f];
 for(let s=0;s<=10;s++){const k=s/10;const G=A.G.map((v,i)=>v+(B.G[i]-v)*k);const U=nrm(nrm(A.U).map((v,i)=>v+(nrm(B.U)[i]-v)*k));
  // match pose(): twist/lean don't affect G/U (they are in local space already)
  const CLL=[1.38,0.83,0.82,0.46];const L=hero>=3?CLL[(hero-3)>>1]:1.05+(hero===0?0.55:0.5);const q=G.map((v,i)=>v+U[i]*L);
  const y=YAW[view],w=[q[0]*Math.cos(y)+q[2]*Math.sin(y),q[1],-q[0]*Math.sin(y)+q[2]*Math.cos(y)];
  const sx=w[0],sy=w[1]*Math.cos(PITCH)-w[2]*Math.sin(PITCH);pts.push([(sx-CX)*72+WW*72/2,WH*72/2-(sy-CY)*72]);}
 M[`h${hero}_${view}_attack_${f}`].arc=pts;}
fs.writeFileSync(DIR+'/meta.json',JSON.stringify(M));
