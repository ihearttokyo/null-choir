"""Compact native-v5 pixel/registration contract. Pure Python; no renderer imports."""
import hashlib,struct,zlib
POSES=('idle','fire','recover')
SOURCE_SHA='39f4b3c4d9298f4c923de72b248fbceca76b0020bb1885cb6bbb2646342e17b4'
HELPER_SHA='07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a'
PROOF_SHA='0f7647473dfc96fb9c9b188a31afd05389ab47cef2df1b50ce6500d77233ad34'
RUNTIME={'atlas':[960,200],'cell_size':[320,200],'columns':3,'frames':list(POSES),'alpha':[0,255],'origin_px':[160,200],'muzzle_px':[140,62],'neutral_vanishing_point_px':[140,37],'hud_destination':[180,143,320,200],'filter':'nearest'}
def sha(data):return hashlib.sha256(data).hexdigest()
def same(a,b):
 if type(a) is not type(b):return False
 if isinstance(b,dict):return a.keys()==b.keys() and all(same(a[k],v) for k,v in b.items())
 if isinstance(b,list):return len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
 return a==b
def png(path,w,h,data):
 assert len(data)==w*h*4
 def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
 raw=b''.join(b'\0'+data[y*w*4:(y+1)*w*4] for y in range(h))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
def rgba(data,dimensions):
 assert data[:8]==b'\x89PNG\r\n\x1a\n' and len(data)<4*1024**2;o=8;packed=bytearray();header=None;ended=False
 while o<len(data):
  assert o+12<=len(data);n=int.from_bytes(data[o:o+4],'big');k=data[o+4:o+8];assert o+12+n<=len(data);v=data[o+8:o+8+n]
  assert zlib.crc32(k+v)&0xffffffff==int.from_bytes(data[o+8+n:o+12+n],'big');o+=12+n
  if k==b'IHDR':assert header is None;header=struct.unpack('>IIBBBBB',v)
  elif k==b'IDAT':packed.extend(v)
  elif k==b'IEND':ended=True;break
 w,h=dimensions;assert ended and o==len(data) and header==(w,h,8,6,0,0,0)
 maximum=h*(w*4+1);d=zlib.decompressobj();raw=d.decompress(packed,maximum+1);assert len(raw)==maximum and d.eof and not d.unused_data and not d.unconsumed_tail
 rows=bytearray();prior=bytearray(w*4)
 for y in range(h):
  mode=raw[y*(w*4+1)];assert mode in range(5);row=bytearray(raw[y*(w*4+1)+1:(y+1)*(w*4+1)])
  for i in range(w*4):
   a=row[i-4] if i>=4 else 0;b=prior[i];c=prior[i-4] if i>=4 else 0
   p=a+b-c;dist=[abs(p-a),abs(p-b),abs(p-c)]
   predictor=(0,a,b,(a+b)//2,(a,b,c)[dist.index(min(dist))])[mode];row[i]=(row[i]+predictor)&255
  rows.extend(row);prior=row
 return rows
def quantize(raw):
 result=bytearray(len(raw))
 for i in range(0,len(raw),4):
  if raw[i+3]>=128:result[i:i+4]=bytes([min(255,round(v/255*31)*8) for v in raw[i:i+3]]+[255])
 return result
def compile_cells(cells):
 assert len(cells)==3 and all(len(c)==320*200*4 and set(c[3::4])=={0,255} for c in cells)
 assert len({bytes(c) for c in cells})==3,'Actual three stored poses must differ'
 result=bytearray(960*200*4)
 for f,c in enumerate(cells):
  for y in range(200):result[(y*960+f*320)*4:(y*960+(f+1)*320)*4]=c[y*1280:(y+1)*1280]
 return result
