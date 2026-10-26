"""V07 structural material finish. All scattered wear/blob/ink programs removed.

The qualified packed UV machinery is retained. Geometry, pose, lighting and alpha
are frozen; only designed shell face/load/back and pressure-direction relationships
change. Dark is reserved for actual structural recess/metal, never painted pits.
"""
from dataclasses import dataclass
import hashlib
import json
import math

ATTRIBUTE = 'RitualSurfaceUV'
TILE = 32
GUTTER = 1
COLUMNS = 16
BONE = frozenset(('ivory','edge','ceramic_worn','ceramic_shade'))
METAL = frozenset(('iron','steel','brass','recess'))
TISSUE = frozenset(('flesh','scar','lumen','hot','ruby_shadow','tissue_ochre'))
COLORS = {
 'shell_face':(.72,.57,.35,1), 'shell_load':(.43,.31,.18,1),
 'shell_raw_back':(.30,.24,.17,1), 'real_bone_edge':(.88,.76,.55,1),
 'cast_petrol':(.10,.19,.20,1), 'working_steel':(.28,.40,.39,1),
 'seated_brass':(.50,.29,.10,1), 'actual_recess':(.045,.042,.038,1),
 'loaded_ruby':(.64,.075,.050,1), 'compressed_maroon':(.28,.025,.045,1),
 'modeled_vascular_flow':(.66,.14,.08,1), 'strained_hot_surface':(.77,.17,.11,1),
 'loaded_muscle':(.30,.105,.080,1), 'compressed_muscle':(.21,.065,.055,1)}


@dataclass(frozen=True)
class Finish:
    relationship: str
    slope: float=0
    boundary: float=.5
    axis: int=0


# One large edge-connected load face per accepted hero construction. These are
# construction-plane compositions, not disconnected wear patches or glyphs.
HERO_FINISH = {
 ('caster','Curved deep mantle -1'):Finish('shell',.25,.72),
 ('caster','Curved deep mantle 1'):Finish('shell',-.25,.42),
 ('guardian','Seated cast ceramic lantern lancet -1'):Finish('shell',-.18,.63),
 ('guardian','Seated cast ceramic lantern lancet 1'):Finish('shell',.18,.50),
 ('summoner','High integrated left production horn'):Finish('shell',.27,.70),
 ('summoner','Low integrated right jaw trough'):Finish('shell',-.22,.43)}


def finish_for(role,name,material):
    if role not in ('caster','guardian','summoner'):raise ValueError('Unknown role')
    if material=='recess':return Finish('recess')
    if material=='edge':return Finish('physical_edge')
    if material in BONE:return HERO_FINISH.get((role,name),Finish('shell_contact',0,.24))
    if material=='brass':return Finish('brass')
    if material=='steel':return Finish('steel')
    if material=='iron':return Finish('cast_contact',0,.28)
    if material in ('scar','hot'):return Finish('modeled_flow' if material=='scar' else 'hot')
    if material=='ruby_shadow':return Finish('compressed_lobe')
    if material=='lumen':return Finish('pressure',.12 if role!='summoner' else -.10,.42,0 if role!='summoner' else 2)
    if material in ('flesh','tissue_ochre'):return Finish('muscle',.08,.36)
    raise ValueError('Unclassified material')


def surface_color(profile,q):
    u,depth,v=q
    kind=profile.relationship
    if kind=='shell':
        if depth>.58:return COLORS['shell_raw_back']
        return COLORS['shell_load'] if u+profile.slope*v>profile.boundary else COLORS['shell_face']
    if kind=='shell_contact':
        if depth>.58:return COLORS['shell_raw_back']
        return COLORS['shell_load'] if v<profile.boundary else COLORS['shell_face']
    if kind=='physical_edge':return COLORS['real_bone_edge']
    if kind=='cast_contact':
        return COLORS['working_steel'] if depth<profile.boundary and v>.30 else COLORS['cast_petrol']
    if kind=='steel':return COLORS['working_steel']
    if kind=='brass':return COLORS['seated_brass']
    if kind=='recess':return COLORS['actual_recess']
    if kind=='pressure':
        along=v if profile.axis==0 else u
        across=u if profile.axis==0 else v
        # One continuous compressed flank follows the full pressure axis.
        flank=profile.boundary+profile.slope*math.sin(math.pi*along)
        return COLORS['compressed_maroon'] if across<flank else COLORS['loaded_ruby']
    if kind=='compressed_lobe':return COLORS['compressed_maroon']
    if kind=='modeled_flow':return COLORS['modeled_vascular_flow']
    if kind=='hot':return COLORS['strained_hot_surface']
    if kind=='muscle':
        return COLORS['compressed_muscle'] if u+profile.slope*v<profile.boundary else COLORS['loaded_muscle']
    raise ValueError('Unknown finish relationship')


class PaintRegistry:
    def __init__(self,geometry,role):
        self.geometry,self.role=geometry,role;self.reference={};self.reference_pose={};self.cache={}
        # Stable canonical reference per named part, independent of requested pose
        # or view. A posed-only mouth/latch still gets one stable part reference.
        for pose in ('idle','attack','dead','windup','recovery','walk_a','walk_b'):
            for part in geometry.build(role,pose).parts:
                if part.name not in self.reference:
                    self.reference[part.name]=part;self.reference_pose[part.name]=pose

    def coordinates(self,part):
        reference=self.reference[part.name]
        if len(reference.vertices)!=len(part.vertices) or reference.faces!=part.faces:
            raise ValueError('Paint topology/vertex identity mismatch: '+part.name)
        low=[min(v[i] for v in reference.vertices) for i in range(3)]
        size=[max(v[i] for v in reference.vertices)-low[i] for i in range(3)]
        if min(size)<=0:raise ValueError('Degenerate paint reference bounds')
        return tuple(tuple((v[i]-low[i])/size[i] for i in range(3)) for v in reference.vertices)



def chart_point(chart,u,v):
    # Six local geometric box charts, never eight runtime views. Charts follow
    # the canonical part's own face normal, not its posed/world/camera bearing.
    if chart==0:return (1,1-u,v) # +X
    if chart==1:return (0,u,v)   # -X
    if chart==2:return (u,1,v)   # +Y
    if chart==3:return (1-u,0,v) # -Y
    if chart==4:return (u,1-v,1) # +Z
    if chart==5:return (u,v,0)   # -Z
    raise ValueError('Unknown local chart')


def point_uv(chart,q):
    x,y,z=q
    return ((1-y,z),(y,z),(x,z),(1-x,z),(x,1-y),(x,y))[chart]


def paint_texel(geometry,role,name,material,q):
    color=surface_color(finish_for(role,name,material),q)
    return bytes(round(max(0,min(1,c))*255) for c in color)


def dominant_chart(vertices,face):
    a,b,c=(vertices[i] for i in face[:3])
    ab=tuple(y-x for x,y in zip(a,b));ac=tuple(y-x for x,y in zip(a,c))
    normal=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
    axis=max(range(3),key=lambda i:abs(normal[i]))
    if abs(normal[axis])<1e-12:raise ValueError('Degenerate UV reference face')
    return axis*2+(normal[axis]<0)


class UVPaintAtlas:
    def __init__(self,geometry,role):
        self.geometry,self.role=geometry,role
        self.registry=PaintRegistry(geometry,role)
        self.assignments={};self.patterns=[];pattern_index={}
        # Identical minor material programs share a texture chart. All named hero
        # compositions remain distinct; no stamp comes from an actor-view image.
        for name,part in self.registry.reference.items():
            for material in dict.fromkeys(part.face_materials or (part.material,)):
                profile=finish_for(role,name,material)
                for chart in range(6):
                    key=(material,profile,chart)
                    if key not in pattern_index:
                        pattern_index[key]=len(self.patterns)
                        self.patterns.append((name,material,chart))
                    self.assignments[name,material,chart]=pattern_index[key]
        self.width=COLUMNS*TILE
        rows=(len(self.patterns)+COLUMNS-1)//COLUMNS
        self.height=1<<max(5,(rows*TILE-1).bit_length())
        self.pixels=bytearray(bytes((0,0,0,255))*(self.width*self.height))
        self.tiles=[];self.cache={}
        for index,(name,material,chart) in enumerate(self.patterns):
            x0,y0=(index%COLUMNS)*TILE,(index//COLUMNS)*TILE
            colors=[]
            for y in range(TILE):
                v=max(0,min(1,(y-GUTTER+.5)/(TILE-2*GUTTER)))
                for x in range(TILE):
                    u=max(0,min(1,(x-GUTTER+.5)/(TILE-2*GUTTER)))
                    color=paint_texel(geometry,role,name,material,chart_point(chart,u,v))
                    offset=((y0+y)*self.width+x0+x)*4
                    self.pixels[offset:offset+4]=color;colors.append(color)
            self.tiles.append({'index':index,'part_program':name,'material':material,'local_chart':chart,
                               'distinct_colors':len(set(colors))})

    def uvs(self,part):
        materials=part.face_materials or (part.material,)*len(part.faces)
        key=part.name,part.faces,materials
        if key in self.cache:return self.cache[key]
        coordinates=self.registry.coordinates(part)
        reference=self.registry.reference[part.name]
        values=[]
        for face,material in zip(reference.faces,materials):
            chart=dominant_chart(reference.vertices,face)
            tile=self.assignments[part.name,material,chart]
            x0,y0=(tile%COLUMNS)*TILE,(tile//COLUMNS)*TILE
            for index in face:
                u,v=point_uv(chart,coordinates[index])
                # Stay inside the duplicated edge gutter; Closest sampling only.
                values.append(((x0+GUTTER+.5+u*(TILE-2*GUTTER-1))/self.width,
                               (y0+GUTTER+.5+v*(TILE-2*GUTTER-1))/self.height))
        info={'attribute':ATTRIBUTE,'role':self.role,'part':part.name,'reference_pose':self.registry.reference_pose[part.name],
              'corners':len(values),'uv_sha256':hashlib.sha256(json.dumps(values,separators=(',',':')).encode()).hexdigest(),
              'anchor':'canonical local face-chart / vertex identity; independent of runtime camera and pose'}
        self.cache[key]=tuple(values),info
        return self.cache[key]

    def sample(self,uv):
        x=max(0,min(self.width-1,int(uv[0]*self.width)))
        y=max(0,min(self.height-1,int(uv[1]*self.height)))
        i=(y*self.width+x)*4
        return bytes(self.pixels[i:i+4])

    def tile_pixels(self,name,material,chart):
        index=self.assignments[name,material,chart];x0,y0=(index%COLUMNS)*TILE,(index//COLUMNS)*TILE
        return b''.join(self.pixels[((y0+y)*self.width+x0)*4:((y0+y)*self.width+x0+TILE)*4] for y in range(TILE))

    def summary(self):
        return {'attribute':ATTRIBUTE,'role':self.role,'size':[self.width,self.height],
                'rgba_bottom_up_sha256':hashlib.sha256(self.pixels).hexdigest(),
                'local_charts':6,'tile_size':TILE,'gutter':GUTTER,'unique_pattern_tiles':len(self.patterns),
                'part_material_chart_assignments':len(self.assignments),'canonical_named_parts':len(self.registry.reference),
                'opaque':all(a==255 for a in self.pixels[3::4]),'sampling':'Closest',
                'coordinate_system':'six canonical geometric face charts, not runtime view/atlas coordinates'}


def png_bytes(width,height,rgba_bottom_up):
    """Portable RGBA paint source; native PNG data, not a rendered actor image."""
    import struct,zlib
    if len(rgba_bottom_up)!=width*height*4:raise ValueError('Invalid paint dimensions')
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    scan=b''.join(b'\0'+rgba_bottom_up[y*width*4:(y+1)*width*4] for y in reversed(range(height)))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,9))+chunk(b'IEND',b'')


def decode_png(data):
    """Strict complete8bit RGB/RGBA decoder for native packed paint audit."""
    import struct,zlib
    if data[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Packed paint is not PNG')
    pos=8;compressed=bytearray();size=None;ended=False
    while pos<len(data):
        length,=struct.unpack_from('>I',data,pos);kind=data[pos+4:pos+8];body=data[pos+8:pos+8+length]
        crc,=struct.unpack_from('>I',data,pos+8+length)
        if zlib.crc32(kind+body)&0xffffffff!=crc:raise ValueError('Paint PNG CRC mismatch')
        if kind==b'IHDR':
            w,h,depth,color,comp,filt,interlace=struct.unpack('>IIBBBBB',body)
            if depth!=8 or color not in (2,6) or comp or filt or interlace or w*h>1024**2:raise ValueError('Unsupported paint PNG')
            size=(w,h);channels=3 if color==2 else 4
        elif kind==b'IDAT':compressed.extend(body)
        elif kind==b'IEND':
            if length or pos+12!=len(data):raise ValueError('Nonterminal paint PNG')
            ended=True
        pos+=12+length
    if not ended or not size:raise ValueError('Incomplete paint PNG')
    raw=zlib.decompress(compressed);stride=w*channels
    if len(raw)!=(stride+1)*h:raise ValueError('Paint scanline size mismatch')
    rows=[];prev=bytearray(stride)
    for y in range(h):
        method=raw[y*(stride+1)];row=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        if method>4:raise ValueError('Invalid paint PNG filter')
        for x in range(stride):
            a=row[x-channels] if x>=channels else 0;b=prev[x];c=prev[x-channels] if x>=channels else 0
            if method==1:predict=a
            elif method==2:predict=b
            elif method==3:predict=(a+b)//2
            elif method==4:
                p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                predict=a if pa<=pb and pa<=pc else b if pb<=pc else c
            else:predict=0
            row[x]=(row[x]+predict)&255
        rows.append(row);prev=row
    result=bytearray()
    for row in reversed(rows):
        if channels==4:result.extend(row)
        else:
            for x in range(w):result.extend(row[x*3:x*3+3]+b'\xff')
    return size,bytes(result)
