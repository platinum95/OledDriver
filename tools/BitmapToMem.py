#!/usr/bin/env python3

from PIL import Image

import numpy as np
im = Image.open( "./bitmap.bmp" )
p = np.array( im )

assert ( p.shape == ( 32, 128 ) )

numCols = 128
numRows = 32 // 8

binStr = ""

for rowIdx in range( numRows ):
    rowOffset = rowIdx * 8
    for colIdx in range( numCols ):
        for i in range( 8 ):
            bitOffset = 7 - i
            pixel = p[ rowIdx + bitOffset ][ colIdx ]
            binStr += '1' if pixel > 0 else '0'
        binStr += '\n'

print( binStr )

with open( 'bitmap.mem', 'w' ) as outputFile:
    outputFile.write( binStr )