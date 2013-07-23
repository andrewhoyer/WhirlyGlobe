/*
 *  VectorManager.mm
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 1/26/11.
 *  Copyright 2011-2013 mousebird consulting
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

#import "VectorManager.h"
#import "WhirlyGeometry.h"
#import "NSDictionary+Stuff.h"
#import "UIColor+Stuff.h"
#import "Tesselator.h"

using namespace Eigen;
using namespace WhirlyKit;

// Used to describe the drawable we'll construct for a given vector
@interface VectorInfo : NSObject
{
@public
    // For creation request, the shapes
    ShapeSet                    shapes;
    BOOL                        enable;
    float                         drawOffset;
    UIColor                     *color;
    int                         priority;
    float                       minVis,maxVis;
    float                       fade;
    float                       lineWidth;
    BOOL                        filled;
    float                       sample;
}

@property (nonatomic) UIColor *color;
@property (nonatomic,assign) float fade;
@property (nonatomic,assign) float lineWidth;

- (void)parseDict:(NSDictionary *)dict;

@end

@implementation VectorInfo

@synthesize color;
@synthesize fade;
@synthesize lineWidth;

- (id)initWithShapes:(ShapeSet *)inShapes desc:(NSDictionary *)dict
{
    if ((self = [super init]))
    {
        if (inShapes)
            shapes = *inShapes;
        [self parseDict:dict];
    }
    
    return self;
}

- (id)initWithDesc:(NSDictionary *)dict
{
    if ((self = [super init]))
    {
        [self parseDict:dict];
    }
    
    return self;
}

- (void)parseDict:(NSDictionary *)dict
{
    enable = [dict boolForKey:@"enable" default:YES];
    drawOffset = [dict floatForKey:@"drawOffset" default:0];
    self.color = [dict objectForKey:@"color" checkType:[UIColor class] default:[UIColor whiteColor]];
    priority = [dict intForKey:@"drawPriority" default:0];
    // This looks like an old bug
    priority = [dict intForKey:@"priority" default:priority];
    minVis = [dict floatForKey:@"minVis" default:DrawVisibleInvalid];
    maxVis = [dict floatForKey:@"maxVis" default:DrawVisibleInvalid];
    fade = [dict floatForKey:@"fade" default:0.0];
    lineWidth = [dict floatForKey:@"width" default:1.0];
    filled = [dict boolForKey:@"filled" default:false];
    sample = [dict floatForKey:@"sample" default:false];
}

@end

namespace WhirlyKit
{
    
void VectorSceneRep::clear(ChangeSet &changes)
{
    for (SimpleIDSet::iterator it = drawIDs.begin(); it != drawIDs.end(); ++it)
        changes.push_back(new RemDrawableReq(*it));
}

/* Drawable Builder
 Used to construct drawables with multiple shapes in them.
 Eventually, we'll move this out to be a more generic object.
 */
class VectorDrawableBuilder
{
public:
    VectorDrawableBuilder(Scene *scene,ChangeSet &changeRequests,VectorSceneRep *sceneRep,
                          VectorInfo *vecInfo,bool linesOrPoints)
    : changeRequests(changeRequests), scene(scene), sceneRep(sceneRep), vecInfo(vecInfo), drawable(NULL)
    {
        primType = (linesOrPoints ? GL_LINES : GL_POINTS);
    }
    
    ~VectorDrawableBuilder()
    {
        flush();
    }
    
    void addPoints(VectorRing &pts,bool closed)
    {
        CoordSystemDisplayAdapter *coordAdapter = scene->getCoordAdapter();
        
        // Decide if we'll appending to an existing drawable or
        //  create a new one
        int ptCount = 2*(pts.size()+1);
        if (!drawable || (drawable->getNumPoints()+ptCount > MaxDrawablePoints))
        {
            // We're done with it, toss it to the scene
            if (drawable)
                flush();
            
            drawable = new BasicDrawable("Vector Layer");
            drawMbr.reset();
            drawable->setType(primType);
            // Adjust according to the vector info
            drawable->setOnOff(vecInfo->enable);
            drawable->setDrawOffset(vecInfo->drawOffset);
            drawable->setColor([vecInfo.color asRGBAColor]);
            drawable->setLineWidth(vecInfo.lineWidth);
            drawable->setDrawPriority(vecInfo->priority);
            drawable->setVisibleRange(vecInfo->minVis,vecInfo->maxVis);
        }
        drawMbr.addPoints(pts);
        
        Point3f prevPt,prevNorm,firstPt,firstNorm;
        for (unsigned int jj=0;jj<pts.size();jj++)
        {
            // Convert to real world coordinates and offset from the globe
            Point2f &geoPt = pts[jj];
            GeoCoord geoCoord = GeoCoord(geoPt.x(),geoPt.y());
            Point3f localPt = coordAdapter->getCoordSystem()->geographicToLocal(geoCoord);
            Point3f norm = coordAdapter->normalForLocal(localPt);
            Point3f pt = coordAdapter->localToDisplay(localPt);
            
            // Add to drawable
            // Depending on the type, we do this differently
            if (primType == GL_POINTS)
            {
                drawable->addPoint(pt);
                drawable->addNormal(norm);
            } else {
                if (jj > 0)
                {
                    drawable->addPoint(prevPt);
                    drawable->addPoint(pt);
                    drawable->addNormal(prevNorm);
                    drawable->addNormal(norm);
                } else {
                    firstPt = pt;
                    firstNorm = norm;
                }
                prevPt = pt;
                prevNorm = norm;
            }
        }
        
        // Close the loop
        if (closed && primType == GL_LINES)
        {
            drawable->addPoint(prevPt);
            drawable->addPoint(firstPt);
            drawable->addNormal(prevNorm);
            drawable->addNormal(firstNorm);
        }
    }
    
    void flush()
    {
        if (drawable)
        {
            if (drawable->getNumPoints() > 0)
            {
                drawable->setLocalMbr(drawMbr);
                sceneRep->drawIDs.insert(drawable->getId());
                
                if (vecInfo.fade > 0.0)
                {
                    NSTimeInterval curTime = CFAbsoluteTimeGetCurrent();
                    drawable->setFade(curTime,curTime+vecInfo.fade);
                }
                changeRequests.push_back(new AddDrawableReq(drawable));
            } else
                delete drawable;
            drawable = NULL;
        }
    }
    
protected:
    Scene *scene;
    ChangeSet &changeRequests;
    VectorSceneRep *sceneRep;
    Mbr drawMbr;
    BasicDrawable *drawable;
    VectorInfo *vecInfo;
    GLenum primType;
};

/* Drawable Builder (Triangle version)
 Used to construct drawables with multiple shapes in them.
 Eventually, we'll move this out to be a more generic object.
 */
class VectorDrawableBuilderTri
{
public:
    VectorDrawableBuilderTri(Scene *scene,ChangeSet &changeRequests,VectorSceneRep *sceneRep,
                             VectorInfo *vecInfo)
    : changeRequests(changeRequests), scene(scene), sceneRep(sceneRep), vecInfo(vecInfo), drawable(NULL)
    {
    }
    
    ~VectorDrawableBuilderTri()
    {
        flush();
    }
    
    void addPoints(VectorRing &inRing)
    {
        if (inRing.size() < 3)
            return;
        
        CoordSystemDisplayAdapter *coordAdapter = scene->getCoordAdapter();
        
        std::vector<VectorRing> rings;
        TesselateRing(inRing,rings);
        
        for (unsigned int ir=0;ir<rings.size();ir++)
        {
            VectorRing &pts = rings[ir];
            // Decide if we'll appending to an existing drawable or
            //  create a new one
            int ptCount = pts.size();
            int triCount = pts.size()-2;
            if (!drawable ||
                (drawable->getNumPoints()+ptCount > MaxDrawablePoints) ||
                (drawable->getNumTris()+triCount > MaxDrawableTriangles))
            {
                // We're done with it, toss it to the scene
                if (drawable)
                    flush();
                
                drawable = new BasicDrawable("Vector Layer");
                drawMbr.reset();
                drawable->setType(GL_TRIANGLES);
                // Adjust according to the vector info
                drawable->setOnOff(vecInfo->enable);
                drawable->setDrawOffset(vecInfo->drawOffset);
                drawable->setColor([vecInfo.color asRGBAColor]);
                drawable->setDrawPriority(vecInfo->priority);
                drawable->setVisibleRange(vecInfo->minVis,vecInfo->maxVis);
                //                drawable->setForceZBufferOn(true);
            }
            int baseVert = drawable->getNumPoints();
            drawMbr.addPoints(pts);
            
            // Add the points
            for (unsigned int jj=0;jj<pts.size();jj++)
            {
                // Convert to real world coordinates and offset from the globe
                Point2f &geoPt = pts[jj];
                GeoCoord geoCoord = GeoCoord(geoPt.x(),geoPt.y());
                Point3f localPt = coordAdapter->getCoordSystem()->geographicToLocal(geoCoord);
                Point3f norm = coordAdapter->normalForLocal(localPt);
                Point3f pt = coordAdapter->localToDisplay(localPt);
                
                drawable->addPoint(pt);
                drawable->addNormal(norm);
            }
            
            // Add the triangles
            // Note: Should be reusing vertex indices
            if (pts.size() == 3)
                drawable->addTriangle(BasicDrawable::Triangle(0+baseVert,2+baseVert,1+baseVert));
        }
    }
    
    void flush()
    {
        if (drawable)
        {            
            if (drawable->getNumPoints() > 0)
            {
                drawable->setLocalMbr(drawMbr);
                sceneRep->drawIDs.insert(drawable->getId());
                
                if (vecInfo.fade > 0.0)
                {
                    NSTimeInterval curTime = CFAbsoluteTimeGetCurrent();
                    drawable->setFade(curTime,curTime+vecInfo.fade);
                }
                changeRequests.push_back(new AddDrawableReq(drawable));
            } else
                delete drawable;
            drawable = NULL;
        }
    }
    
protected:   
    Scene *scene;
    ChangeSet &changeRequests;
    VectorSceneRep *sceneRep;
    Mbr drawMbr;
    BasicDrawable *drawable;
    VectorInfo *vecInfo;
};

VectorManager::VectorManager()
{
    pthread_mutex_init(&vectorLock, NULL);
}

VectorManager::~VectorManager()
{
    for (VectorSceneRepSet::iterator it = vectorReps.begin();
         it != vectorReps.end(); ++it)
        delete *it;
    vectorReps.clear();

    pthread_mutex_destroy(&vectorLock);
}

SimpleIdentity VectorManager::addVectors(ShapeSet *shapes, NSDictionary *desc, ChangeSet &changes)
{
    VectorInfo *vecInfo = [[VectorInfo alloc] initWithShapes:shapes desc:desc];

    // All the shape types should be the same
    ShapeSet::iterator first = vecInfo->shapes.begin();
    if (first == vecInfo->shapes.end())
        return EmptyIdentity;
    
    VectorSceneRep *sceneRep = new VectorSceneRep();
    sceneRep->fade = vecInfo.fade;
    
    VectorPointsRef thePoints = boost::dynamic_pointer_cast<VectorPoints>(*first);
    bool linesOrPoints = (thePoints.get() ? false : true);
    
    // Used to toss out drawables as we go
    // Its destructor will flush out the last drawable
    VectorDrawableBuilder drawBuild(scene,changes,sceneRep,vecInfo,linesOrPoints);
    VectorDrawableBuilderTri drawBuildTri(scene,changes,sceneRep,vecInfo);
        
    for (ShapeSet::iterator it = vecInfo->shapes.begin();
         it != vecInfo->shapes.end(); ++it)
    {
        VectorArealRef theAreal = boost::dynamic_pointer_cast<VectorAreal>(*it);
        if (theAreal.get())
        {
            if (vecInfo->filled)
            {
                // Triangulate the outside
                drawBuildTri.addPoints(theAreal->loops[0]);
            } else {
                // Work through the loops
                for (unsigned int ri=0;ri<theAreal->loops.size();ri++)
                {
                    VectorRing &ring = theAreal->loops[ri];
                    
                    // Break the edges around the globe (presumably)
                    if (vecInfo->sample > 0.0)
                    {
                        VectorRing newPts;
                        SubdivideEdges(ring, newPts, false, vecInfo->sample);
                        drawBuild.addPoints(newPts,true);
                    } else
                        drawBuild.addPoints(ring,true);
                }
            }
        } else {
            VectorLinearRef theLinear = boost::dynamic_pointer_cast<VectorLinear>(*it);
            if (vecInfo->filled)
            {
                // Triangulate the outside
                drawBuildTri.addPoints(theLinear->pts);
            } else {
                if (theLinear.get())
                {
                    if (vecInfo->sample > 0.0)
                    {
                        VectorRing newPts;
                        SubdivideEdges(theLinear->pts, newPts, false, vecInfo->sample);
                        drawBuild.addPoints(newPts,false);
                    } else
                        drawBuild.addPoints(theLinear->pts,false);
                } else {
                    VectorPointsRef thePoints = boost::dynamic_pointer_cast<VectorPoints>(*it);
                    if (thePoints.get())
                    {
                        drawBuild.addPoints(thePoints->pts,false);
                    }
                }
            }
        }
    }
    
    drawBuild.flush();
    drawBuildTri.flush();
    
    SimpleIdentity vecID = sceneRep->getId();
    pthread_mutex_lock(&vectorLock);
    vectorReps.insert(sceneRep);
    pthread_mutex_unlock(&vectorLock);
    
    return vecID;
}

void VectorManager::changeVectors(SimpleIdentity vecID,NSDictionary *desc,ChangeSet &changes)
{
    VectorInfo *vecInfo = [[VectorInfo alloc] initWithDesc:desc];

    pthread_mutex_lock(&vectorLock);
    
    VectorSceneRep dummyRep(vecID);
    VectorSceneRepSet::iterator it = vectorReps.find(&dummyRep);
    
    if (it != vectorReps.end())
    {
        VectorSceneRep *sceneRep = *it;
        for (SimpleIDSet::iterator idIt = sceneRep->drawIDs.begin();
             idIt != sceneRep->drawIDs.end(); ++idIt)
        {
            // Turned it on or off
            changes.push_back(new OnOffChangeRequest(*idIt, vecInfo->enable));
            
            // Changed color
            RGBAColor newColor = [vecInfo.color asRGBAColor];
            changes.push_back(new ColorChangeRequest(*idIt, newColor));
            
            // Changed visibility
            changes.push_back(new VisibilityChangeRequest(*idIt, vecInfo->minVis, vecInfo->maxVis));
            
            // Changed line width
            changes.push_back(new LineWidthChangeRequest(*idIt, vecInfo->lineWidth));
            
            // Changed draw priority
            changes.push_back(new DrawPriorityChangeRequest(*idIt, vecInfo->priority));
        }        
    }
    
    pthread_mutex_unlock(&vectorLock);
}

void VectorManager::removeVectors(SimpleIDSet &vecIDs,ChangeSet &changes)
{
    pthread_mutex_lock(&vectorLock);
    
    for (SimpleIDSet::iterator vit = vecIDs.begin(); vit != vecIDs.end(); ++vit)
    {
        VectorSceneRep dummyRep(*vit);
        VectorSceneRepSet::iterator it = vectorReps.find(&dummyRep);
        
        NSTimeInterval curTime = CFAbsoluteTimeGetCurrent();
        if (it != vectorReps.end())
        {
            VectorSceneRep *sceneRep = *it;
            
            if (sceneRep->fade > 0.0)
            {
                for (SimpleIDSet::iterator idIt = sceneRep->drawIDs.begin();
                     idIt != sceneRep->drawIDs.end(); ++idIt)
                    changes.push_back(new FadeChangeRequest(*idIt, curTime, curTime+sceneRep->fade));
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, sceneRep->fade * NSEC_PER_SEC),
                               scene->getDispatchQueue(),
                               ^{
                                   SimpleIDSet theIDs;
                                   theIDs.insert(sceneRep->getId());
                                   ChangeSet delChanges;
                                   removeVectors(theIDs, delChanges);
                                   scene->addChangeRequests(delChanges);
                               }
                               );
                sceneRep->fade = 0.0;
            } else {
                for (SimpleIDSet::iterator idIt = sceneRep->drawIDs.begin();
                     idIt != sceneRep->drawIDs.end(); ++idIt)
                    changes.push_back(new RemDrawableReq(*idIt));
                vectorReps.erase(it);
                
                delete sceneRep;
            }
        }
    }
    
    pthread_mutex_unlock(&vectorLock);
}
    
void VectorManager::enableVector(SimpleIdentity vecID,bool enable,ChangeSet &changes)
{
    pthread_mutex_lock(&vectorLock);
    
    VectorSceneRep dummyRep(vecID);
    VectorSceneRepSet::iterator it = vectorReps.find(&dummyRep);
    if (it != vectorReps.end())
    {
        VectorSceneRep *sceneRep = *it;
        
        for (SimpleIDSet::iterator idIt = sceneRep->drawIDs.begin();
             idIt != sceneRep->drawIDs.end(); ++idIt)
            changes.push_back(new OnOffChangeRequest(*idIt,enable));
    }
    
    pthread_mutex_unlock(&vectorLock);    
}

}
