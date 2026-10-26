shader_type canvas_item;
render_mode unshaded;
uniform float phase=0.0;
uniform float aspect=1.0;
uniform float seed=0.0;
uniform float energy=0.0;
uniform int visual_style=0;
uniform int track_id=-1;
uniform vec3 audio_bands=vec3(0.0);

// Genuine bounded world-space surfaces. No TIME, textures or screen reads.
//72 primary steps,18-unit far bound; tetrahedral normal4, AO2, shadow8.
vec3 rotate_y(vec3 p,float a){float c=cos(a);float s=sin(a);return vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);}
vec3 rotate_z(vec3 p,float a){float c=cos(a);float s=sin(a);return vec3(c*p.x-s*p.y,s*p.x+c*p.y,p.z);}
float brick(vec3 p,vec3 b,float bevel){vec3 q=abs(p)-b;return length(max(q,vec3(0.0)))+min(max(q.x,max(q.y,q.z)),0.0)-bevel;}
float sphere(vec3 p,float r){return length(p)-r;}
float cylinder(vec3 p,float r,float h){vec2 q=vec2(length(p.xz)-r,abs(p.y)-h);return min(max(q.x,q.y),0.0)+length(max(q,vec2(0.0)));}
float torus(vec3 p,vec2 t){return length(vec2(length(p.xz)-t.x,p.y))-t.y;}
float ellipsoid(vec3 p,vec3 r){float k0=length(p/r);float k1=length(p/(r*r));return k0*(k0-1.0)/max(k1,0.0001);}
vec2 unite(vec2 a,vec2 b){return a.x<b.x?a:b;}
float archway(vec3 p){
 float wall=brick(p-vec3(0.0,2.1,0.0),vec3(2.4,2.1,0.23),0.07);
 float opening=min(brick(p-vec3(0.0,0.9,0.0),vec3(1.45,1.2,0.7),0.0),cylinder(vec3(p.x,p.z,p.y-2.0),1.45,0.7));
 return max(wall,-opening);
}
vec2 focal(vec3 p,float chapter){
 vec3 q=p-vec3(0.0,1.25,0.0);
 vec3 bands=clamp(audio_bands,vec3(0.0),vec3(1.0));
 vec2 f=vec2(100.0,2.0);
 if(chapter<0.5){ // Intake: suspended open skin-bell, clapper and connected siphon receiver.
  float flare=0.28+0.48*clamp((1.2-q.y)/1.3,0.0,1.0);
  float outer=max((length(q.xz)-flare)*0.93,abs(q.y-0.55)-0.65);
  float cavity=max((length(q.xz)-(flare-0.085))*0.93,q.y-1.08);
  f=vec2(max(outer,-cavity),6.0);
  f=unite(f,vec2(torus(q-vec3(0.0,-0.10,0.0),vec2(0.76,0.055)),4.0));
  f=unite(f,vec2(cylinder(q-vec3(0.0,0.50,0.0),0.045,0.65),3.0));
  f=unite(f,vec2(ellipsoid(q-vec3(bands.x*0.055,-0.22,0.0),vec3(0.12,0.20,0.12)),4.0));
  f=unite(f,vec2(brick(vec3(abs(q.x)-1.07,q.y+0.05,q.z),vec3(0.10,1.13,0.18),0.025),2.0));
  f=unite(f,vec2(brick(q-vec3(0.0,1.25,0.0),vec3(1.18,0.13,0.18),0.03),3.0));
  f=unite(f,vec2(cylinder(q-vec3(0.0,1.15,0.0),0.09,0.15),3.0));
  float receiver=max(cylinder(q-vec3(0.0,-0.95,0.0),0.56,0.20),-cylinder(q-vec3(0.0,-0.85,0.0),0.43,0.20));
  f=unite(f,vec2(receiver,2.0));
  f=unite(f,vec2(ellipsoid(vec3(abs(q.x)-0.12,q.y+0.85,q.z-0.10),vec3(0.23,0.30,0.22)),6.0));
  f=unite(f,vec2(cylinder(q-vec3(0.70,-0.50,0.0),0.045,0.40),3.0));
  f=unite(f,vec2(brick(q-vec3(0.53,-0.90,0.0),vec3(0.18,0.045,0.045),0.01),3.0));
 }else if(chapter<1.5){ // Foundry: hollow crucible, glowing interior, heavy feet.
  float vessel=max(cylinder(q,0.95,0.67),-cylinder(q-vec3(0.0,0.25,0.0),0.70,0.7));
  vessel=max(vessel,-brick(q-vec3(0.0,-0.1,0.86),vec3(0.32,0.22,0.36),0.04));
  f=vec2(vessel,2.0);
  f=unite(f,vec2(brick(q-vec3(0.0,-0.16,0.67),vec3(0.3,0.20,0.06),0.0),5.0));
  f=unite(f,vec2(cylinder(q-vec3(0.0,1.17,-0.1),0.76,0.16),2.0));
  f=unite(f,vec2(cylinder(q-vec3(0.0,1.72,-0.1),0.24,0.46),3.0));
  for(int support=0;support<4;support++){
   float a=float(support)*1.570796+0.5;
   vec3 post=q-vec3(cos(a)*0.94,-0.55,sin(a)*0.94);
   f=unite(f,vec2(cylinder(post,0.075,0.70),3.0));
  }
  f=unite(f,vec2(cylinder(q-vec3(0.0,-0.23,0.0),0.69,0.05),5.0));
  f=unite(f,vec2(brick(q-vec3(0.0,-0.95,0.0),vec3(0.68,0.28,0.58),0.06),1.0));
  f=unite(f,vec2(torus(q-vec3(0.0,0.6,0.0),vec2(0.94,0.09)),3.0));
 }else if(chapter<2.5){ // Processional: walking bone-organ, hollow graduated pipes on living bellows.
  float pipe_index=clamp(floor(q.x/0.23+0.5),-3.0,3.0);
  float pipe_top=1.65-abs(pipe_index)*0.16;
  float half_pipe=(pipe_top+0.10)*0.5;
  vec3 pipe=q-vec3(pipe_index*0.23,(pipe_top-0.10)*0.5,-0.05);
  float tube=max(cylinder(pipe,0.112,half_pipe),-cylinder(pipe-vec3(0.0,0.04,0.0),0.074,half_pipe));
  tube=max(tube,-brick(pipe-vec3(0.0,half_pipe*0.52,0.105),vec3(0.042,0.105,0.08),0.008));
  f=vec2(tube,4.0);
  f=unite(f,vec2(torus(pipe-vec3(0.0,half_pipe-0.035,0.0),vec2(0.112,0.018)),3.0));
  f=unite(f,vec2(brick(q-vec3(0.0,-0.10,-0.05),vec3(0.83,0.08,0.26),0.035),3.0));
  f=unite(f,vec2(brick(q-vec3(0.0,-0.42,0.0),vec3(0.76,0.25,0.39+bands.y*0.045),0.065),6.0));
  vec3 fold=vec3(q.x,mod(q.y+0.67,0.10)-0.05,q.z-(0.405+bands.y*0.045));
  float ribs=max(brick(fold,vec3(0.76,0.012,0.035),0.006),abs(q.y+0.42)-0.23);
  f=unite(f,vec2(ribs,4.0));
  vec3 leg=vec3(abs(q.x)-0.58,q.y+0.87,abs(q.z)-0.30);
  f=unite(f,vec2(cylinder(leg,0.095,0.28),4.0));
  f=unite(f,vec2(brick(vec3(abs(q.x)-0.58,q.y+1.12,abs(q.z)-0.30),vec3(0.20,0.075,0.16),0.025),2.0));

}else if(chapter<3.5){ // Reliquary: Face Halo and open Memory Wheel in a supported catalogue.
  vec3 face=q-vec3(-0.43,0.49,0.12);
  // Carved volume, not a seal: negative sockets and mouth sit behind projecting features.
  float visage=ellipsoid(face,vec3(0.30,0.48,0.19));
  vec3 sockets=vec3(abs(face.x)-0.12,face.y-0.08,face.z-0.17);
  visage=max(visage,-sphere(sockets,0.085));
  visage=max(visage,-brick(face-vec3(0.0,-0.19,0.17),vec3(0.135,0.025,0.09),0.012));
  f=vec2(visage,4.0);
  f=unite(f,vec2(ellipsoid(face-vec3(0.0,0.20,0.12),vec3(0.29,0.075,0.12)),4.0));
  f=unite(f,vec2(ellipsoid(face-vec3(0.0,-0.015,0.19),vec3(0.060,0.15,0.13)),4.0));
  f=unite(f,vec2(ellipsoid(face-vec3(0.0,-0.33,0.025),vec3(0.17,0.12,0.14)),4.0));
  f=unite(f,vec2(torus(vec3(face.x,face.z+0.05,face.y),vec2(0.77,0.085)),3.0));
  f=unite(f,vec2(torus(vec3(face.x,face.z+0.10,face.y),vec2(0.86,0.035)),2.0));
  // Analytic eight-fold geometry: open air between physical spokes and relic cassettes.
  vec3 wheel=rotate_z(rotate_y(q-vec3(0.88,0.13,-0.28),0.30),0.17);
  f=unite(f,vec2(torus(vec3(wheel.x,wheel.z,wheel.y),vec2(0.70,0.075)),3.0));
  f=unite(f,vec2(torus(vec3(wheel.x,wheel.z,wheel.y),vec2(0.51,0.030)),2.0));
  f=unite(f,vec2(cylinder(vec3(wheel.x,wheel.z,wheel.y),0.14,0.16),3.0));
  float sector_angle=floor(atan(wheel.y,wheel.x)/0.7853981634+0.5)*0.7853981634;
  vec3 spoke=rotate_z(wheel,-sector_angle);
  f=unite(f,vec2(brick(spoke-vec3(0.34,0.0,0.0),vec3(0.23,0.026,0.055),0.009),3.0));
  f=unite(f,vec2(brick(spoke-vec3(0.58,0.0,0.0),vec3(0.095,0.080,0.10),0.018),4.0));
  f=unite(f,vec2(brick(spoke-vec3(0.58,0.0,0.105),vec3(0.11,0.022,0.018),0.006),3.0));
  // Recessed archive piers ground the mechanisms; repeated niches are clipped by the pier.
  vec3 pier=vec3(abs(q.x)-1.53,q.y,q.z+0.36);
  float archive=brick(pier,vec3(0.24,1.03,0.31),0.035);
  vec3 niche=vec3(pier.x,mod(pier.y+0.30,0.60)-0.30,pier.z-0.27);
  archive=max(archive,-brick(niche,vec3(0.16,0.17,0.16),0.025));
  f=unite(f,vec2(archive,1.0));
  float catalogue_relic=max(brick(niche-vec3(0.0,-0.035,-0.025),vec3(0.085,0.10,0.07),0.018),abs(pier.y)-0.88);
  f=unite(f,vec2(catalogue_relic,4.0));
  f=unite(f,vec2(brick(q-vec3(0.0,-1.07,-0.25),vec3(1.80,0.12,0.51),0.04),1.0));
  f=unite(f,vec2(cylinder(q-vec3(-0.43,-0.50,0.05),0.12,0.55),2.0));
  f=unite(f,vec2(brick(q-vec3(-1.27,0.49,0.02),vec3(0.27,0.065,0.10),0.018),3.0));
  f=unite(f,vec2(cylinder(vec3(q.y-0.13,q.x-1.15,q.z+0.28),0.11,0.42),2.0));
 }else if(chapter<4.5){ // Nursery: rounded translucent-looking cell, warm living core.
  f=vec2(ellipsoid(q,vec3(0.73,1.04,0.58)),6.0);
  for(int rib=0;rib<3;rib++){
   vec3 cell=q-vec3(0.0,(float(rib)-1.0)*0.56,0.0);
   f=unite(f,vec2(torus(cell,vec2(0.61,0.07)),3.0));
  }
  f=unite(f,vec2(cylinder(q-vec3(-0.84,-0.15,0.0),0.075,1.15),4.0));
  f=unite(f,vec2(cylinder(q-vec3(0.84,-0.15,0.0),0.075,1.15),4.0));
  f=unite(f,vec2(torus(rotate_z(q-vec3(0.0,1.0,0.0),1.570796),vec2(0.42,0.075)),3.0));
  f=unite(f,vec2(ellipsoid(q-vec3(0.0,-0.1,0.46),vec3(0.32,0.55,0.22)),4.0));
  f=unite(f,vec2(torus(q-vec3(0.0,-0.79,0.0),vec2(0.62,0.12)),4.0));
  f=unite(f,vec2(brick(q-vec3(0.0,-1.0,0.0),vec3(0.65,0.18,0.55),0.07),2.0));
 }else if(chapter<5.5){ // Ossuary: three spatial ribs carrying a lower crossing.
  for(int i=0;i<3;i++){
   vec3 rib=q-vec3(0.0,0.05,float(i)*0.48-0.48);
   f=unite(f,vec2(max(torus(vec3(rib.x,rib.z,rib.y),vec2(0.93,0.14)),-rib.y-0.35),4.0));
  }
  f=unite(f,vec2(brick(q-vec3(0.0,-0.62,0.0),vec3(1.1,0.12,0.85),0.04),1.0));
 }else if(chapter<6.5){ // Inversion: tilted gimbal with real thickness and restraint bed.
  q=rotate_z(q,0.53+sin(phase*0.09)*0.012);
  f=vec2(torus(vec3(q.x,q.z,q.y),vec2(1.0,0.12)),3.0);
  f=unite(f,vec2(torus(q,vec2(0.88,0.065)),2.0));
  f=unite(f,vec2(cylinder(vec3(q.y,q.x,q.z),0.16,1.14),3.0));
  f=unite(f,vec2(brick(q,vec3(0.74,0.14,0.38),0.1),2.0));
  f=unite(f,vec2(brick(vec3(abs(q.x)-0.48,q.y-0.18,q.z),vec3(0.065,0.25,0.45),0.03),4.0));
 }else{ // Heart: colossal anatomical mouth, open throat and anchored lateral restraints.
  vec3 mouth=q-vec3(0.0,0.22,0.0);
  float cheek=ellipsoid(mouth,vec3(0.96,1.15,0.56));
  float throat=ellipsoid(mouth-vec3(0.0,-0.02,0.36),vec3(0.61+bands.x*0.018,0.80+bands.x*0.018,0.58));
  f=vec2(max(cheek,-throat),6.0);
  float jaw=max(ellipsoid(q-vec3(0.0,-0.55,0.23),vec3(0.82,0.40,0.43)),-ellipsoid(q-vec3(0.0,-0.30,0.50),vec3(0.68,0.30,0.40)));
  f=unite(f,vec2(jaw,4.0));
  float tooth_index=clamp(floor(q.x/0.23+0.5),-2.0,2.0);
  vec3 tooth=vec3(q.x-tooth_index*0.23,abs(q.y-0.20)-0.62,q.z-0.47);
  f=unite(f,vec2(ellipsoid(tooth,vec3(0.065,0.19,0.10)),4.0));
  f=unite(f,vec2(ellipsoid(q-vec3(0.0,-0.95,0.0),vec3(0.50,0.30,0.35)),6.0));
  f=unite(f,vec2(brick(vec3(abs(q.x)-1.12,q.y+0.10,q.z+0.10),vec3(0.12,1.15,0.16),0.025),2.0));
  f=unite(f,vec2(brick(q-vec3(0.0,1.20,-0.35),vec3(1.24,0.12,0.15),0.025),2.0));
  vec3 clamp_point=vec3(abs(q.x)-0.82,abs(q.y-0.20)-0.65,q.z-0.10);
  f=unite(f,vec2(brick(clamp_point,vec3(0.26,0.07,0.40),0.025),3.0));
 }
 // Every hero is physically supported; bass moves the support collar only.
 if(!(chapter<0.5 || (chapter>1.5 && chapter<2.5) || chapter>6.5))
  f=unite(f,vec2(cylinder(p-vec3(0.0,0.13,0.0),1.1+bands.x*0.015,0.13),1.0));
 return f;
}
// These three signatures occupy chapter architecture, not a shared display pedestal.
bool chapter_space(float chapter){return chapter<0.5 || (chapter>1.5 && chapter<2.5) || chapter>6.5;}
vec3 chapter_practical(float chapter){
 if(chapter<0.5)return vec3(-1.55,2.6,1.0);
 if(chapter<2.5)return vec3(-1.8,2.7,0.5);
 return vec3(-1.8,2.3,-0.9);
}
vec3 chapter_cool(float chapter){
 if(chapter<0.5)return vec3(1.8,2.2,1.0);
 if(chapter<2.5)return rotate_y(vec3(2.15,2.5,1.0),-0.34);
 return vec3(2.0,2.6,-0.7);
}
vec2 occupied_space(vec3 p,float chapter){
 vec2 s=vec2(100.0,1.0);
 if(chapter<0.5){
  // Actual missing floor beneath the bell. The receiver rests on a transverse service member.
  float shaft=visual_style==1?cylinder(p-vec3(0.0,-1.0,-0.4),1.12,1.5):brick(p-vec3(0.0,-1.0,-0.4),vec3(0.90,1.5,1.8),0.0);
  s=vec2(max(p.y,-shaft),2.0);
  s=unite(s,vec2(brick(p-vec3(0.0,0.05,0.0),vec3(1.15,0.05,0.10),0.01),2.0));
  s=unite(s,vec2(brick(vec3(abs(p.x)-1.07,p.y-0.04,p.z),vec3(0.17,0.04,0.23),0.01),2.0));
  // Asymmetric deep service walls: no blank foreground pier cutting across the bell.
  float left=brick(p-vec3(-3.1,2.2,-3.8),vec3(0.25,2.3,6.8),0.04);
  float port=brick(vec3(p.x+2.95,p.y-1.6,mod(p.z+1.0,2.8)-1.4),vec3(0.4,0.85,0.75),0.08);
  s=unite(s,vec2(max(left,-port),1.0));
  s=unite(s,vec2(brick(p-vec3(3.0,2.5,-4.5),vec3(0.22,2.6,6.0),0.03),2.0));
  s=unite(s,vec2(brick(p-vec3(0.0,3.5,-5.5),vec3(3.0,0.15,0.24),0.02),2.0));
  // Sidewalk rail follows the shaft, interrupted before the occupied gantry.
  s=unite(s,vec2(cylinder(vec3(p.x-1.35,p.z+2.9,p.y-0.95),0.035,1.4),3.0));
  s=unite(s,vec2(brick(p-vec3(1.35,0.48,-4.2),vec3(0.045,0.48,0.045),0.0),2.0));
  if(visual_style==0)s=unite(s,vec2(max(abs(length(vec2(p.x,p.y-1.5))-3.0)-0.12,2.6-p.y),1.0));
  if(visual_style==1){s=unite(s,vec2(torus(p-vec3(0.0,3.1,-0.4),vec2(2.1,0.10)),2.0));s=unite(s,vec2(brick(p-vec3(0.0,3.1,-0.4),vec3(3.1,0.08,0.12),0.015),2.0));}
  if(visual_style==2)s=unite(s,vec2(brick(p-vec3(0.0,3.05,-2.8),vec3(3.0,0.16,0.35),0.02),1.0));
  s=unite(s,vec2(brick(p-vec3(-2.3,2.70,1.0),vec3(0.8,0.05,0.16),0.01),2.0));
  s=unite(s,vec2(brick(p-vec3(2.4,2.30,1.0),vec3(0.6,0.05,0.12),0.01),2.0));
  s=unite(s,focal(p,chapter));
 }else if(chapter<2.5){
  // Receding oblique transport route: raised walking gallery over open side channels.
  vec3 g=rotate_y(p,0.34);
  s=vec2(p.y+1.15,2.0);
  s=unite(s,vec2(brick(g-vec3(0.0,-0.13,-2.0),vec3(1.45,0.13,8.0),0.015),1.0));
  s=unite(s,vec2(brick(vec3(abs(g.x)-1.38,g.y+0.65,g.z+2.0),vec3(0.08,0.65,7.8),0.015),2.0));
  vec3 bay=vec3(abs(g.x)-2.35,g.y-1.325,mod(g.z+0.6,3.2)-1.6);
  float pier=max(brick(bay,vec3(0.18,2.475,0.22),0.03),abs(g.z+3.0)-6.0);
  s=unite(s,vec2(pier,2.0));
  s=unite(s,vec2(brick(g-vec3(-2.8,1.8,-3.5),vec3(0.18,2.95,7.0),0.03),1.0));
  if(visual_style==0)s=unite(s,vec2(max(brick(vec3(g.x,g.y-3.65,bay.z),vec3(2.5,0.12,0.18),0.04),abs(g.z+3.0)-6.0),4.0));
  if(visual_style==1){s=unite(s,vec2(torus(g-vec3(0.0,3.5,-2.5),vec2(2.45,0.13)),3.0));s=unite(s,vec2(brick(g-vec3(0.0,3.5,-2.5),vec3(2.8,0.08,0.18),0.015),2.0));}
  if(visual_style==2){
   float wall=brick(g-vec3(2.9,1.2,-4.0),vec3(0.3,2.35,6.0),0.02);
   float alcove=brick(vec3(g.x-2.7,g.y-1.9,bay.z),vec3(0.5,1.05,1.0),0.12);
   s=unite(s,vec2(max(wall,-alcove),1.0));
  }
  vec3 organ=rotate_y(p,0.34);
  s=unite(s,vec2(brick(vec3(abs(organ.x)-0.58,organ.y-0.015,abs(organ.z)-0.30),vec3(0.24,0.02,0.20),0.005),2.0));
  vec3 practical_g=rotate_y(chapter_practical(chapter),0.34);
  s=unite(s,vec2(brick(g-vec3((-2.8+practical_g.x)*0.5,practical_g.y+0.10,practical_g.z),vec3((practical_g.x+2.8)*0.5,0.05,0.14),0.01),2.0));
  s=unite(s,focal(organ,chapter));
 }else{
  // Terminal apse: quiet approach ends in rooted anatomy and lateral structural restraint.
  s=vec2(p.y,1.0);
  float back=brick(p-vec3(0.0,2.25,-3.0),vec3(3.5,2.35,0.45),0.04);
  float apse=ellipsoid(p-vec3(0.0,2.1,-2.35),vec3(2.15,2.5,1.1));
  s=unite(s,vec2(max(back,-apse),1.0));
  vec3 buttress=vec3(abs(p.x)-2.3,p.y-1.8,p.z+1.7);
  s=unite(s,vec2(brick(buttress,vec3(0.28,1.8,0.68),0.025),2.0));
  s=unite(s,vec2(brick(vec3(abs(p.x)-1.65,p.y-1.8,p.z+1.55),vec3(0.65,0.11,0.20),0.025),3.0));
  if(visual_style==0)s=unite(s,vec2(max(abs(length(vec2(p.x,p.y-1.3))-3.0)-0.15,2.5-p.y),1.0));
  if(visual_style==1)s=unite(s,vec2(torus(vec3(p.x,p.z+2.0,p.y-2.4),vec2(2.25,0.15)),2.0));
  if(visual_style==2)s=unite(s,vec2(brick(p-vec3(0.0,3.2,-2.6),vec3(3.1,0.25,0.5),0.03),1.0));
  s=unite(s,vec2(brick(p-vec3(-2.05,2.40,-0.9),vec3(0.35,0.05,0.16),0.01),2.0));
  s=unite(s,vec2(brick(p-vec3(2.05,2.70,-1.15),vec3(0.35,0.05,0.50),0.01),2.0));
  s=unite(s,focal(p-vec3(0.0,0.0,-1.5),chapter));
 }
 s=unite(s,vec2(sphere(p-chapter_practical(chapter),0.085),5.0));
 s=unite(s,vec2(brick(p-chapter_practical(chapter)-vec3(0.0,0.10,0.0),vec3(0.12,0.035,0.16),0.015),3.0));
 s=unite(s,vec2(sphere(p-chapter_cool(chapter),0.065),7.0));
 return s;
}
vec2 scene(vec3 p,float chapter){
 if(chapter_space(chapter))return occupied_space(p,chapter);
 vec2 s=vec2(p.y,1.0);
 // Camera is physically inside a closed monumental hall, never a skybox yard.
 float outer=brick(p-vec3(0.0,2.7,-2.8),vec3(3.9,2.8,9.3),0.0);
 float inner=brick(p-vec3(0.0,2.7,-2.8),vec3(3.65,2.7,9.05),0.0);
 s=unite(s,vec2(max(outer,-inner),1.0));
 vec3 repeated=p;repeated.z=mod(p.z+1.5,3.0)-1.5;
 if(visual_style==0){
  // Five visibledepth bays via one bounded analytic repetition.
  float vault=archway(repeated);
  vault=max(vault,abs(p.z+2.2)-7.2);
  s=unite(s,vec2(vault,1.0));
  float roof=abs(length(vec2(p.x,p.y-1.6))-3.65)-0.13;
  s=unite(s,vec2(max(max(roof,2.5-p.y),abs(p.z+2.5)-8.5),1.0));
  // Fluted paired engaged piers, capitals and a gallery on the far flank.
  vec3 column=vec3(abs(p.x)-2.7,p.y-1.7,repeated.z);
  s=unite(s,vec2(cylinder(column,0.19,1.7),4.0));
  s=unite(s,vec2(brick(column-vec3(0.0,1.5,0.0),vec3(0.3,0.12,0.34),0.04),4.0));
 }else if(visual_style==1){
  // Enclosed observatory: radial buttresses and a high drum/dome, with
  // a lower circular walkway wrapping the actual instrument.
  s=unite(s,vec2(torus(p-vec3(0.0,0.12,0.0),vec2(2.35,0.13)),3.0));
  for(int i=0;i<6;i++){
   float a=float(i)*1.047198+0.2;
   vec3 loc=vec3(cos(a)*3.0,2.2,sin(a)*3.0);
   s=unite(s,vec2(cylinder(p-loc,0.25,2.2),1.0));
  }
  s=unite(s,vec2(torus(p-vec3(0.0,4.1,0.0),vec2(3.0,0.16)),4.0));
  float dome=abs(length(p-vec3(0.0,2.0,0.0))-3.4)-0.15;
  s=unite(s,vec2(max(dome,3.6-p.y),1.0));
 }else{
  // Deep crypt: actual carved side recesses, low ceiling ribs and platforms.
  float sidewall=brick(p-vec3(-3.1,1.6,-2.0),vec3(0.4,1.6,7.5),0.08);
  float recess=brick(vec3(p.x+2.8,p.y-1.7,repeated.z),vec3(0.65,0.94,0.75),0.16);
  s=unite(s,vec2(max(sidewall,-recess),4.0));
  s=unite(s,vec2(brick(vec3(p.x,p.y-3.65,repeated.z),vec3(3.3,0.13,0.13),0.09),1.0));
  for(int i=0;i<3;i++){
   vec3 q=p-vec3(float(i)*1.65-1.65,1.35,-4.4);
   s=unite(s,vec2(brick(q,vec3(0.5,1.2,0.28),0.15),4.0));
   s=unite(s,vec2(brick(q-vec3(0.0,0.0,0.30),vec3(0.045,0.75,0.045),0.02),3.0));
  }
 }
 // Warm practicals are real geometric lamps anchored to each sidewall bay.
 vec3 lamp=vec3(abs(p.x)-2.8,p.y-2.3,repeated.z-0.9);
 s=unite(s,vec2(sphere(lamp,0.075),5.0));
 s=unite(s,vec2(brick(lamp-vec3(0.0,-0.12,0.0),vec3(0.12,0.04,0.13),0.02),3.0));
 // Real-scale service piping, handrail and narrow footsteps connect hero to hall.
 vec3 pipe=vec3(abs(p.x)-1.28,p.y-0.35,p.z);
 s=unite(s,vec2(cylinder(vec3(pipe.x,pipe.z,pipe.y),0.055,1.2),3.0));
 s=unite(s,vec2(brick(p-vec3(0.0,0.06,1.55),vec3(0.65,0.06,0.24),0.02),1.0));
 s=unite(s,vec2(brick(p-vec3(0.0,0.12,1.12),vec3(0.75,0.12,0.19),0.02),1.0));
 return unite(s,focal(p,chapter));
}

vec3 surface_normal(vec3 p,float chapter){
 vec2 e=vec2(0.0015,-0.0015);
 return normalize(e.xyy*scene(p+e.xyy,chapter).x+e.yyx*scene(p+e.yyx,chapter).x+e.yxy*scene(p+e.yxy,chapter).x+e.xxx*scene(p+e.xxx,chapter).x);
}
void fragment(){
 float chapter=mod(track_id<0?max(seed-1.0,0.0):float(track_id),8.0);
 vec2 uv=(UV-0.5)*2.0;uv.x*=aspect;uv.y=-uv.y;
 vec3 eye=vec3(1.45,1.48,4.55);
 if(visual_style==1)eye=vec3(-1.0,1.65,4.8); // Between radial supports, not on their axis.
 if(visual_style==2)eye=vec3(1.65,1.42,4.7);
 vec3 target=vec3(-0.15,1.8,-1.25);
 if(chapter<0.5){eye=vec3(2.3,1.65,3.6);target=vec3(-0.05,1.0,-0.7);if(visual_style==1)eye=vec3(-2.0,1.9,3.8);if(visual_style==2)eye=vec3(1.8,1.6,3.6);}
 else if(chapter>1.5 && chapter<2.5){eye=vec3(2.15,1.55,4.7);target=vec3(-0.5,1.5,-1.4);if(visual_style==1)eye=vec3(-1.6,1.75,4.4);if(visual_style==2)eye=vec3(1.8,1.6,4.2);}
 else if(chapter>6.5){eye=vec3(1.0,1.5,3.4);target=vec3(0.0,1.6,-1.6);if(visual_style==1)eye=vec3(1.8,1.8,3.8);if(visual_style==2)eye=vec3(-1.4,1.4,3.8);}
 vec3 forward=normalize(target-eye);vec3 right=normalize(cross(forward,vec3(0.0,1.0,0.0)));vec3 up=cross(right,forward);
 vec3 ray=normalize(forward*1.85+right*uv.x+up*uv.y);
 float distance_travelled=0.0;vec2 hit=vec2(0.0);bool found=false;
 for(int step_index=0;step_index<72;step_index++){
  hit=scene(eye+ray*distance_travelled,chapter);
  if(hit.x<0.0015){found=true;break;}
  distance_travelled+=max(hit.x*0.78,0.001);
  if(distance_travelled>18.0)break;
 }
 vec3 fog=vec3(0.025,0.046,0.063);if(chapter_space(chapter))fog=vec3(0.012,0.025,0.040);vec3 color=fog;
 if(found){
  vec3 p=eye+ray*distance_travelled;vec3 n=surface_normal(p,chapter);
  vec3 base=vec3(0.43,0.40,0.32);float rough=0.85;float metallic=0.0;
  if(hit.y>1.5 && hit.y<2.5){base=vec3(0.23,0.29,0.30);rough=0.49;metallic=0.5;}
  if(hit.y>2.5 && hit.y<3.5){base=vec3(0.55,0.30,0.11);rough=0.29;metallic=0.8;}
  if(hit.y>3.5 && hit.y<4.5){base=vec3(0.76,0.68,0.48);rough=0.65;}
  if(hit.y>5.5){base=vec3(0.49,0.14,0.085);rough=0.62;}
  if(chapter_space(chapter)){
   base=vec3(0.19,0.22,0.23);rough=0.90;
   if(hit.y>1.5 && hit.y<2.5){base=vec3(0.075,0.13,0.15);rough=0.42;metallic=0.65;}
   if(hit.y>2.5 && hit.y<3.5){base=vec3(0.36,0.21,0.095);rough=0.34;metallic=0.8;}
   if(hit.y>3.5 && hit.y<4.5){base=vec3(0.68,0.63,0.48);rough=0.72;}
   if(hit.y>5.5){base=vec3(0.30,0.065,0.045);rough=0.55;}
   if(hit.y>6.5){base=vec3(0.08,0.23,0.32);rough=0.2;}
  }
  // Material detail is evaluated only after a hit, never inside the march.
  float grain=sin(p.x*35.0+sin(p.z*19.0))*sin(p.y*29.0+p.z*11.0);
  base*=1.0+grain*(hit.y<1.5?0.018:0.025);
  if(p.y<0.025){base=vec3(0.18,0.19,0.17);rough=0.98;}
  vec3 lightpos=vec3(-1.5,3.7,2.2);if(chapter_space(chapter))lightpos=chapter_practical(chapter);vec3 l=normalize(lightpos-p);vec3 v=-ray;
  float shadow=1.0;float t=0.08;
  for(int shadow_index=0;shadow_index<8;shadow_index++){
   if(chapter_space(chapter) && t>=length(lightpos-p)-0.12)break; // Never shadow a point light with geometry behind its emitter.
   float d=scene(p+n*0.025+l*t,chapter).x;
   shadow=min(shadow,clamp(7.0*d/t,0.16,1.0));t+=clamp(d,0.12,0.65);
  }
  float ao=1.0;
  for(int ao_index=0;ao_index<2;ao_index++){
   float h=0.09+float(ao_index)*0.19;
   ao-=max(0.0,h-scene(p+n*h,chapter).x)*0.65;
  }
  ao=clamp(ao,0.40,1.0);
  float diffuse=max(dot(n,l),0.0);
  float spec=pow(max(dot(n,normalize(l+v)),0.0),mix(68.0,9.0,rough));
  float sky=0.17+0.14*max(n.y,0.0)+0.12*max(n.x,0.0);
  color=base*(vec3(0.48,0.66,0.78)*sky*ao+vec3(1.0,0.76,0.47)*diffuse*shadow*1.25);
  color+=mix(vec3(0.13),base,metallic)*spec*shadow*(0.7+clamp(audio_bands.z,0.0,1.0)*0.12);
  color+=base*vec3(0.20,0.11,0.055)*max(0.0,-n.y)*0.4;
  vec3 lampdelta=vec3(abs(p.x)-2.8,p.y-2.3,mod(p.z+1.5,3.0)-2.4);
  color+=base*vec3(1.0,0.43,0.13)*0.48/(0.5+dot(lampdelta,lampdelta));
  if(hit.y>4.5 && hit.y<5.5)color=vec3(1.0,0.43,0.09)*(1.1+clamp(audio_bands.x,0.0,1.0)*0.12);
  if(hit.y>5.5)color+=vec3(0.24,0.07,0.025)*(0.9+clamp(audio_bands.y,0.0,1.0)*0.12);
  if(chapter_space(chapter)){
   vec3 keydelta=lightpos-p;float attenuation=7.0/(1.0+dot(keydelta,keydelta));
   vec3 cooldelta=chapter_cool(chapter)-p;vec3 cooldir=normalize(cooldelta);
   float coolpower=8.0*max(dot(n,cooldir),0.0)/(1.0+dot(cooldelta,cooldelta));
   color=base*(vec3(0.34,0.43,0.50)*(0.28+0.16*max(n.y,0.0))*ao+vec3(1.0,0.65,0.33)*diffuse*shadow*attenuation+vec3(0.58,0.75,0.86)*coolpower*ao);
   color+=mix(vec3(0.06),base,metallic)*spec*shadow*attenuation;
   if(hit.y>4.5 && hit.y<5.5)color=vec3(1.0,0.46,0.16)*1.15;
   if(hit.y>6.5)color=vec3(0.18,0.50,0.85)*0.95;
  }
  color=mix(color,fog,1.0-exp(-distance_travelled*0.035));
 }
 color=vec3(1.0)-exp(-color*1.35);
 COLOR=vec4(pow(max(color,vec3(0.0)),vec3(0.88)),1.0);
}
