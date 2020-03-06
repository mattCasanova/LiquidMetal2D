#!/bin/bash

cd Sources/LiquidMetal2D/shaders

for f in *.metal 
do
  xcrun -sdk iphoneos metal -c ${f} -o ${f%.*}.air
done


xcrun -sdk iphoneos metallib *.air -o ShaderLib.metallib

rm *.air