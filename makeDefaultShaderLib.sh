#!/bin/bash

xcrun -sdk iphoneos metal -c Sources/LiquidMetal2D/Shaders.metal -o Shaders.air
xcrun -sdk iphoneos metallib Shaders.air -o Shaders.metallib