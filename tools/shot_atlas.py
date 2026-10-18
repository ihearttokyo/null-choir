"""Strict native-shot coverage contract shared by builder and fixtures."""

def validate(pixels):
    assert len(pixels) == 256*256*4, 'Atlas must be 256x256 RGBA'
    assert set(pixels[3::4]) == {0,255}, 'Alpha must be binary and nonempty'
    frames=[]
    for row in range(4):
        for column in range(4):
            occupied=[(x,y) for y in range(64) for x in range(64)
                      if pixels[((row*64+y)*256+column*64+x)*4+3]]
            assert len(occupied) >= 80, 'Empty or unreadably sparse frame'
            assert all(4 <= x < 60 and 4 <= y < 60 for x,y in occupied), 'Clipped frame/gutter bleed'
            if row == 3:
                assert not any(24 <= x < 40 and 24 <= y < 40 for x,y in occupied), 'Pressure-pulse void filled'
            frames.append({'row':row,'column':column,'alpha_pixels':len(occupied),
                           'bounds_xy_inclusive':[min(x for x,y in occupied),min(y for x,y in occupied),
                                                  max(x for x,y in occupied),max(y for x,y in occupied)]})
    return frames
