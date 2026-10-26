shader_type canvas_item;
render_mode unshaded;

// PIXEL MUSIC GARDEN v02: one shared drum-pipe / spring-pass / bird-catch performance.
// No image sampler/TIME. Host owns real playback phase and actual audio values.
uniform float phase = 0.0;
uniform float aspect = 1.0;
uniform float seed = 0.0;
uniform float energy = 0.0;
uniform int visual_style = 0;
uniform vec3 audio_bands = vec3(0.0);

// Exactly sixteen opaque RGB colors. Every pixel selects ONE entry, no blend.
vec3 palette(int i) {
 if(i==0) return vec3(16.0,21.0,47.0)/255.0;
 if(i==1) return vec3(32.0,40.0,76.0)/255.0;
 if(i==2) return vec3(51.0,70.0,110.0)/255.0;
 if(i==3) return vec3(87.0,115.0,153.0)/255.0;
 if(i==4) return vec3(135.0,153.0,173.0)/255.0;
 if(i==5) return vec3(255.0,240.0,192.0)/255.0;
 if(i==6) return vec3(34.0,101.0,87.0)/255.0;
 if(i==7) return vec3(105.0,206.0,155.0)/255.0;
 if(i==8) return vec3(183.0,230.0,176.0)/255.0;
 if(i==9) return vec3(123.0,73.0,44.0)/255.0;
 if(i==10) return vec3(231.0,163.0,63.0)/255.0;
 if(i==11) return vec3(255.0,214.0,109.0)/255.0;
 if(i==12) return vec3(153.0,61.0,80.0)/255.0;
 if(i==13) return vec3(239.0,120.0,116.0)/255.0;
 if(i==14) return vec3(255.0,182.0,160.0)/255.0;
 return vec3(112.0,212.0,218.0)/255.0;
}
bool rect(vec2 p,vec2 a,vec2 b) { return all(greaterThanEqual(p,a)) && all(lessThanEqual(p,b)); }
bool oval(vec2 p,vec2 c,vec2 r) { vec2 q=(p-c)/r;return dot(q,q)<=1.0; }
bool stick(vec2 p,vec2 a,vec2 b,float width) {
 vec2 v=b-a;float t=clamp(dot(p-a,v)/max(dot(v,v),1.0),0.0,1.0);
 vec2 d=p-a-v*t;return dot(d,d)<=width*width;
}
float hash(float n) { return fract(sin(n*127.1+seed*31.7)*43758.5453); }

int beetle(vec2 q,float pose,float peak,float low) {
 int c=-1;
 // Sixteen-tick authored decorative performance, not an inferred audio beat.
 bool windup=pose>=1.0 && pose<4.0;
 bool strike=pose>=4.0 && pose<6.0;
 q.x-=windup?-2.0:(strike?2.0:0.0);
 q.y-=strike?2.0:0.0;
 float step_a=windup?3.0:(strike?1.0:0.0);
 // Three pairs of sturdy feet, then the shell: no texture or sprite atlas.
 for(int leg=0;leg<3;leg++) {
  float x=-10.0+float(leg)*10.0;
  float foot=mod(float(leg)+pose,2.0)<1.0?step_a:0.0;
  if(stick(q,vec2(x,-7.0),vec2(x-3.0,-2.0-foot),1.0)) c=9;
  if(rect(q,vec2(x-5.0,-2.0-foot),vec2(x-1.0,-foot))) c=10;
 }
 if(oval(q,vec2(-1.0,-10.0),vec2(14.0,9.0))) c=9;
 if(oval(q,vec2(-1.0,-12.0),vec2(12.0,7.0))) c=10;
 if(oval(q,vec2(-3.0,-14.0),vec2(9.0,4.0))) c=11;
 if(rect(q,vec2(-12.0,-11.0),vec2(8.0,-9.0))) c=9;
 // Drum head physically moves by measured low tier, mallets by peak tier.
 float cap=-19.0-low;
 if(oval(q,vec2(-2.0,cap+2.0),vec2(12.0,4.0))) c=9;
 if(oval(q,vec2(-2.0,cap),vec2(11.0,3.0))) c=11;
 if(oval(q,vec2(-2.0,cap-1.0),vec2(9.0,2.0))) c=5;
 vec2 left=windup?vec2(-18.0,-31.0-peak):vec2(-16.0,-24.0);
 vec2 right=windup?vec2(14.0,-33.0-peak):vec2(12.0,-25.0);
 if(strike) { left=vec2(-7.0,cap-2.0);right=vec2(4.0,cap-2.0); }
 if(pose==6.0) { left=vec2(-14.0,-27.0);right=vec2(10.0,-28.0); }
 if(stick(q,vec2(-11.0,-12.0),left,0.7)||stick(q,vec2(10.0,-12.0),right,0.7)) c=9;
 if(rect(q,left-vec2(2.0),left+vec2(2.0))||rect(q,right-vec2(2.0),right+vec2(2.0))) c=10;
 if(rect(q,left-vec2(1.0),left+vec2(1.0))||rect(q,right-vec2(1.0),right+vec2(1.0))) c=11;
 // Front-facing smiling mask, framed by the shell rather than random dots.
 if(oval(q,vec2(6.0,-8.0),vec2(8.0,6.0))) c=10;
 if(rect(q,vec2(1.0,-11.0),vec2(3.0,-7.0))||rect(q,vec2(9.0,-11.0),vec2(11.0,-7.0))) c=0;
 if(q==vec2(2.0,-10.0)||q==vec2(10.0,-10.0)) c=5;
 if(rect(q,vec2(5.0,-5.0),vec2(7.0,-4.0))) c=12;
 return c;
}

int spring_blob(vec2 q,float pose,float mid) {
 int c=-1;
 bool compress=pose>=6.0 && pose<8.0;
 bool launch=pose>=8.0 && pose<11.0;
 float lift=compress?4.0:(launch?17.0:8.0);
 lift+=mid*2.0;
 // Spring geometry expands in discrete measured mid tiers, not a fake beat.
 for(int coil=0;coil<3;coil++) {
  float y=-2.0-float(coil)*lift/3.0;
  if(stick(q,vec2(-5.0,y),vec2(5.0,y-lift/6.0),0.8)) c=3;
  if(stick(q,vec2(5.0,y-lift/6.0),vec2(-5.0,y-lift/3.0),0.8)) c=4;
 }
 float cy=-lift-7.0;
 vec2 body=vec2(0.0,cy);
 float squash=compress?3.0:(launch?-1.0:0.0);
 if(oval(q,body,vec2(11.0+squash,7.0-squash))) c=6;
 if(oval(q,body-vec2(1.0,2.0),vec2(9.0+squash,5.0-squash))) c=7;
 if(rect(q,body+vec2(-6.0,-5.0),body+vec2(-2.0,-4.0))) c=8;
 // Eye stalks carry big eyes; both neutral and animated poses stay legible.
 if(stick(q,body+vec2(-5.0,-4.0),body+vec2(-7.0,-10.0),1.0)||stick(q,body+vec2(5.0,-4.0),body+vec2(7.0,-10.0),1.0)) c=6;
 for(int eye=0;eye<2;eye++) {
  vec2 ec=body+vec2(-7.0+float(eye)*14.0,-11.0);
  if(oval(q,ec,vec2(4.0,4.0))) c=8;
  if(oval(q,ec+vec2(1.0,-1.0),vec2(3.0,3.0))) c=5;
  if(oval(q,ec+vec2(2.0,-1.0),vec2(1.5,2.0))) c=0;
 }
 if(rect(q,body+vec2(-2.0,0.0),body+vec2(3.0,2.0))) c=0;
 if(rect(q,body+vec2(0.0,2.0),body+vec2(2.0,3.0))) c=13;
 vec2 left_hand=launch?vec2(-13.0,-13.0):vec2(-14.0,-3.0);
 vec2 right_hand=launch?vec2(15.0,-12.0):vec2(14.0,-3.0);
 if(compress) { left_hand=vec2(-14.0,3.0);right_hand=vec2(14.0,3.0); }
 if(stick(q,body+vec2(-9.0,-1.0),body+left_hand,1.0)) c=7;
 if(stick(q,body+vec2(9.0,-1.0),body+right_hand,1.0)) c=7;
 return c;
}

int antenna_bird(vec2 q,float pose,float high) {
 int c=-1;
 float hop=pose==9.0?4.0:((pose>=10.0 && pose<12.0)?8.0:((pose>=12.0 && pose<14.0)?4.0:0.0));
 q.y+=hop; // Move the entire bird silhouette, not just its tiny feet.
 float footstep=hop>0.0?2.0:0.0;
 if(stick(q,vec2(-2.0,-5.0),vec2(-4.0,-footstep),0.8)||stick(q,vec2(4.0,-5.0),vec2(7.0,-2.0+footstep),0.8)) c=10;
 if(rect(q,vec2(-5.0,-footstep),vec2(-1.0,1.0-footstep))||rect(q,vec2(6.0,-2.0+footstep),vec2(9.0,-1.0+footstep))) c=11;
 if(oval(q,vec2(0.0,-11.0),vec2(9.0,9.0))) c=12;
 if(oval(q,vec2(1.0,-13.0),vec2(8.0,7.0))) c=13;
 if(oval(q,vec2(0.0,-16.0),vec2(5.0,3.0))) c=14;
 // Tail/wing poses use source geometry and the high-band tier.
 bool flap=pose>=9.0 && pose<13.0;
 if(flap) {
  if(stick(q,vec2(-5.0,-10.0),vec2(-16.0,-22.0),2.0)) c=12;
  if(stick(q,vec2(-6.0,-13.0),vec2(-15.0,-23.0),1.0)) c=13;
  if(rect(q,vec2(-17.0,-25.0),vec2(-14.0,-22.0))) c=14;
 } else {
  if(oval(q,vec2(-7.0,-10.0),vec2(6.0,3.0))) c=12;
  if(rect(q,vec2(-12.0,-12.0),vec2(-7.0,-11.0))) c=13;
 }
 if(q.x>=8.0 && q.x<=13.0 && abs(q.y+12.0)<=floor((14.0-q.x)/2.0)) c=11;
 if(oval(q,vec2(5.0,-15.0),vec2(3.0,4.0))) c=5;
 if(rect(q,vec2(5.0,-17.0),vec2(6.0,-14.0))) c=0;
 float antenna=high+mod(pose,2.0);
 vec2 a=vec2(-8.0-antenna,-27.0-high);
 vec2 b=vec2(2.0+antenna,-28.0-high);
 if(stick(q,vec2(-4.0,-19.0),a,0.7)||stick(q,vec2(2.0,-20.0),b,0.7)) c=12;
 if(rect(q,a-vec2(1.0),a+vec2(1.0))||rect(q,b-vec2(1.0),b+vec2(1.0))) c=13;
 if(q==a||q==b) c=14;
 return c;
}

void fragment() {
 // Derivatives measure the actual panel ONLY; never used for edge AA.
 // ceil guarantees base height<=80; integer blocks leave a tiny ink border.
 vec2 panel=max(round(vec2(1.0)/max(fwidth(UV),vec2(0.00001))),vec2(1.0));
 float block=max(1.0,ceil(panel.y/80.0));
 vec2 grid=max(floor(panel/block),vec2(1.0));
 vec2 margin=floor((panel-grid*block)*0.5);
 vec2 p=floor((UV*panel-margin)/block);
 float ticks=floor(max(phase,0.0)*(10.0/0.45)); // Actual shipping phase=seconds*.45.
 float pose=mod(ticks,16.0);
 float level=floor(clamp(energy,0.0,1.0)*3.999);
 vec3 tiers=floor(clamp(audio_bands,vec3(0.0),vec3(1.0))*3.999);
 int style=clamp(visual_style,0,2);
 int c=0;
 // Sparse seeded background stars; only one-pixel color tiers, no glow.
 for(int star=0;star<22;star++) {
  float n=float(star);
  vec2 s=floor(vec2(hash(n+3.0)*grid.x,hash(n+53.0)*grid.y*0.65));
  if(p==s) c=mod(n+floor(ticks/6.0),5.0)==0.0?5:3;
  if(mod(n,7.0)==0.0 && (p==s+vec2(1.0,0.0)||p==s-vec2(1.0,0.0)||p==s+vec2(0.0,1.0)||p==s-vec2(0.0,1.0))) c=15;
 }
 // A moon, a little hanging planter and a stepped observatory make a
 // deliberately asymmetric backdrop, not repeated miniature plinths.
 vec2 moon=floor(vec2(grid.x*(0.10+float(style)*0.025),grid.y*0.18));
 if(oval(p,moon,vec2(9.0,9.0))) c=1;
 if(oval(p,moon-vec2(2.0,2.0),vec2(7.0,7.0))) c=2;
 if(rect(p,moon+vec2(-4.0,-5.0),moon+vec2(-2.0,-3.0))) c=3;
 vec2 planter=floor(vec2(grid.x*(0.37+float(style)*0.015),grid.y*0.29));
 if(stick(p,planter+vec2(0.0,-7.0),planter,0.5)) c=3;
 if(rect(p,planter+vec2(-5.0,0.0),planter+vec2(5.0,3.0))) c=6;
 if(rect(p,planter+vec2(-3.0,3.0),planter+vec2(3.0,5.0))) c=2;
 if(stick(p,planter-vec2(3.0,0.0),planter+vec2(-6.0,-4.0),0.7)||stick(p,planter+vec2(3.0,0.0),planter+vec2(6.0,-4.0),0.7)) c=7;
 vec2 observatory=floor(vec2(grid.x*(0.89-float(style)*0.025),grid.y*0.18));
 if(rect(p,observatory+vec2(-7.0,1.0),observatory+vec2(7.0,3.0))) c=2;
 if(oval(p,observatory,vec2(5.0,5.0)) && p.y<=observatory.y) c=3;
 if(rect(p,observatory+vec2(-2.0,0.0),observatory+vec2(2.0,1.0))) c=11;
 float ground=floor(grid.y*0.78);
 vec2 left_stage=floor(vec2(max(grid.x*0.18,23.0),ground));
 vec2 mid_stage=floor(vec2(grid.x*0.50,ground));
 vec2 right_stage=floor(vec2(grid.x*0.82,ground));
 // One continuous U-shaped musical pipe: drum pressure passes its visible
 // amber windows, drives the spring seat, then reaches a flowering perch.
 float pipe_top=ground+5.0;
 float pipe_bottom=ground+12.0;
 if(rect(p,vec2(0.0,pipe_top),vec2(grid.x-1.0,pipe_bottom))) c=1;
 if(rect(p,vec2(0.0,pipe_top+1.0),vec2(grid.x-1.0,pipe_top+2.0))) c=3;
 if(rect(p,vec2(0.0,pipe_bottom),vec2(grid.x-1.0,pipe_bottom))) c=2;
 for(int window=0;window<9;window++) {
  float x=floor(grid.x*(0.05+float(window)*0.11));
  if(rect(p,vec2(x,pipe_top+3.0),vec2(x+4.0,pipe_top+5.0))) c=9;
  if(rect(p,vec2(x+1.0,pipe_top+3.0),vec2(x+3.0,pipe_top+4.0))) c=10;
 }
 // Different functional seats: drum bellows, spring socket, arched bird perch.
 if(rect(p,left_stage+vec2(-17.0,0.0),left_stage+vec2(17.0,3.0))) c=6;
 if(rect(p,left_stage+vec2(-16.0,-2.0),left_stage+vec2(16.0,0.0))) c=7;
 for(int bellows=0;bellows<3;bellows++) {
  float y=ground+4.0+float(bellows)*2.0;
  if(rect(p,vec2(left_stage.x-12.0,y),vec2(left_stage.x+12.0,y))) c=9;
 }
 if(oval(p,mid_stage+vec2(0.0,4.0),vec2(11.0,5.0))) c=2;
 if(oval(p,mid_stage+vec2(0.0,2.0),vec2(9.0,3.0))) c=3;
 if(rect(p,mid_stage+vec2(-8.0,-2.0),mid_stage+vec2(8.0,0.0))) c=8;
 if(stick(p,right_stage+vec2(-15.0,2.0),right_stage+vec2(-9.0,8.0),2.0)||stick(p,right_stage+vec2(13.0,2.0),right_stage+vec2(8.0,8.0),2.0)) c=6;
 if(rect(p,right_stage+vec2(-16.0,-2.0),right_stage+vec2(15.0,0.0))) c=7;
 if(rect(p,right_stage+vec2(-10.0,-3.0),right_stage+vec2(11.0,-2.0))) c=8;
 // Hanging roots and broad fan leaves occupy foreground, without blank boxes.
 for(int root_id=0;root_id<5;root_id++) {
  float n=float(root_id);
  vec2 origin=floor(vec2(grid.x*(0.03+n*0.235),pipe_bottom));
  if(stick(p,origin,origin+vec2(2.0,9.0),0.8)) c=6;
  if(stick(p,origin+vec2(1.0,3.0),origin+vec2(-4.0,5.0),1.0)||stick(p,origin+vec2(1.0,5.0),origin+vec2(5.0,7.0),1.0)) c=7;
 }
 vec2 a=left_stage-vec2(0.0,3.0);
 vec2 b=floor(vec2(grid.x*0.50,ground-3.0));
 vec2 d=floor(vec2(grid.x*0.82,ground-3.0));
 int beetle_pixel=beetle(p-a,pose,level,tiers.x);if(beetle_pixel>=0)c=beetle_pixel;
 int blob_pixel=spring_blob(p-b,pose,tiers.y);if(blob_pixel>=0)c=blob_pixel;
 int bird_pixel=antenna_bird(p-d,pose,tiers.z);if(bird_pixel>=0)c=bird_pixel;
 // One passed block links the cast: ready on drum, through the shared pipe,
 // out of the stretched spring creature, then caught in the bird's open beak.
 vec2 token=vec2(a.x-2.0,ground-26.0);
 if(pose>=4.0 && pose<8.0) token=vec2(floor(a.x+(b.x-a.x)*(pose-4.0)/3.0),pipe_top+4.0);
 if(pose>=8.0 && pose<12.0) {
  float flight=(pose-8.0)/3.0;
  token=floor(vec2(b.x+(d.x+13.0-b.x)*flight,ground-28.0+flight*5.0-sin(flight*3.14159265)*10.0));
 }
 if(pose>=12.0) {
  float held_hop=pose<14.0?4.0:0.0;
  token=vec2(d.x+13.0,ground-15.0-held_hop);
 }
 if(rect(p,token-vec2(2.0),token+vec2(2.0))) c=9;
 if(rect(p,token-vec2(1.0),token+vec2(1.0))) c=11;
 if(any(lessThan(p,vec2(0.0)))||any(greaterThanEqual(p,grid))) c=0;
 COLOR=vec4(palette(c),1.0);
}
