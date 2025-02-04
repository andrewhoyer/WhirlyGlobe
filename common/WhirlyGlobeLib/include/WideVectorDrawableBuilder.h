/*
 *  WideVectorDrawable.h
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 5/29/14.
 *  Copyright 2011-2019 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import "BasicDrawableBuilder.h"
#import "Program.h"
#import "BaseInfo.h"

namespace WhirlyKit
{
    
// Modifies the uniform values of a given shader right
//  before the wide vector drawables are rendered
class WideVectorTweaker : public DrawableTweaker
{
public:
    // Called right before the drawable is drawn
    virtual void tweakForFrame(Drawable *inDraw,RendererFrameInfo *frameInfo) = 0;
    
    bool realWidthSet;
    float realWidth;
    float edgeSize;
    float lineWidth;
    float texRepeat;
    RGBAColor color;
};
    
// Used to debug the wide vectors
//#define WIDEVECDEBUG 1

/** This drawable adds convenience functions for wide vectors.
  */
class WideVectorDrawableBuilder : virtual public BasicDrawableBuilder
{
public:
    EIGEN_MAKE_ALIGNED_OPERATOR_NEW;

    WideVectorDrawableBuilder();
    virtual ~WideVectorDrawableBuilder();

    virtual void Init(unsigned int numVert,unsigned int numTri,bool globeMode);
    
    virtual unsigned int addPoint(const Point3f &pt);
    // Next point, for calculating p1 - p0
    void add_p1(const Point3f &vec);
    // Texture calculation parameters
    void add_texInfo(float texX,float texYmin,float texYmax,float texOffset);
    // Vector for 90 deg from line
    void add_n0(const Point3f &vec);
    // Complex constant we multiply by width for t
    void add_c0(float c);
    // Optional normal
    void addNormal(const Point3f &norm);
    void addNormal(const Point3d &norm);
    
    // We set color globally
    void setColor(RGBAColor inColor);
    
    // Line width for vectors is a bit different
    void setLineWidth(float inWidth);
    
    /// How often the texture repeats
    void setTexRepeat(float inTexRepeat);
    
    /// Number of pixels to interpolate at the edges
    void setEdgeSize(float inEdgeSize);
    
    /// Fix the width to a real world value, rather than letting it change
    void setRealWorldWidth(double width);
    
    // Apply a width expression
    void setWidthExpression(FloatExpressionInfoRef widthExp);
    
    // The tweaker sets up uniforms before a given drawable draws
    void setupTweaker(BasicDrawable *theDraw);
    
    // We need slightly different tweakers for the rendering variants
    virtual WideVectorTweaker *makeTweaker() = 0;

protected:
    float lineWidth;
    RGBAColor color;
    bool globeMode;
    bool realWidthSet;
    double realWidth;
    bool snapTex;
    float texRepeat;
    float edgeSize;
    int p1_index;
    int n0_index;
    int c0_index;
    int tex_index;
    
    FloatExpressionInfoRef widthExp;
    
#ifdef WIDEVECDEBUG
    Point3fVector locPts;
    Point3fVector p1;
    Point2fVector t0_limits;
    Point3fVector n0;
    std::vector<float> c0;
#endif
};
    
typedef std::shared_ptr<WideVectorDrawableBuilder> WideVectorDrawableBuilderRef;
    
}
