/*
 *  DynamicDrawableAtlas.mm
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 3/6/13.
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

#import "DynamicDrawableAtlas.h"
#import "Scene.h"

namespace WhirlyKit
{
    
DynamicDrawableAtlas::DynamicDrawableAtlas(const std::string &name,int singleElementSize,int numVertexBytes,int numElementBytes,OpenGLMemManager *memManager,BigDrawable *(*newBigDrawable)(BasicDrawable *draw,int singleElementSize,int numVertexBytes,int numElementBytes),
                                           SimpleIdentity shaderId)
    : name(name), singleVertexSize(0), singleElementSize(singleElementSize), numVertexBytes(numVertexBytes), numElementBytes(numElementBytes), memManager(memManager), newBigDrawable(newBigDrawable), shaderId(shaderId)
{
}
    
DynamicDrawableAtlas::~DynamicDrawableAtlas()
{
    for (unsigned int ii=0;ii<swapChanges.size();ii++)
        delete swapChanges[ii];
    swapChanges.clear();
}
    
bool DynamicDrawableAtlas::addDrawable(BasicDrawable *draw,ChangeSet &changes,bool enabled)
{
    // See if we're already representing it
    {
        DrawRepresent represent(draw->getId());
        if (drawables.find(represent) != drawables.end())
        {
            return true;
        }
    }
    
    // Only doing triangles at the moment
    if (draw->getType() != GL_TRIANGLES)
        return false;
    
    // If this is the first one we've seen, we'll configure ourselves to match it
    const std::vector<VertexAttribute *> &drawVertexAttributes = draw->getVertexAttributes();
    if (singleVertexSize == 0)
    {
        singleVertexSize = draw->singleVertexSize();
        vertexAttributes.clear();
        for (unsigned int ii=0;ii<drawVertexAttributes.size();ii++)
        {
            vertexAttributes.push_back(drawVertexAttributes[ii]->templateCopy());
        }
    }

    if (singleVertexSize != draw->singleVertexSize() || vertexAttributes.size() != drawVertexAttributes.size() || shaderId != draw->getProgram())
    {
        NSLog(@"DynamicDrawableAtlas::addDrawable(): Drawable mismatch.  Punting drawable.");
        return false;
    }
    for (unsigned int ii=0;ii<drawVertexAttributes.size();ii++)
        // Note: Comparison could be more comprehensive
        if (vertexAttributes[ii].getDataType() != drawVertexAttributes[ii]->getDataType())
        {
            NSLog(@"DynamicDrawableAtlas::addDrawable(): Drawable mismatch.  Punting drawable.");
            return false;
        }

    // Turn the vertex and element data in to NSData objects
    NSMutableData *vertData = nil, *elementData = nil;
    draw->asVertexAndElementData(&vertData,&elementData,singleElementSize);
    if (!vertData || !elementData)
        return false;
    
    // Look for a big drawable that uses the same texture
    BigDrawable *foundBigDraw = nil;
    DrawRepresent represent(draw->getId());
    for (BigDrawableSet::iterator it = bigDrawables.begin(); it != bigDrawables.end(); ++it)
    {
        BigDrawable *bigDraw = *it;
        if (bigDraw->isCompatible(draw))
        {
            if ((represent.elementChunkId = bigDraw->addRegion(vertData, represent.vertexPos, elementData,enabled)) != EmptyIdentity)
            {
                represent.vertexSize = [vertData length];
                represent.bigDrawId = bigDraw->getId();
                foundBigDraw = bigDraw;
                break;
            }
        }
    }
    
    // Didn't find one, so create one
    if (!foundBigDraw)
    {
        BigDrawable *newBigDraw = NULL;
        if (newBigDrawable)
            newBigDraw = (*newBigDrawable)(draw,singleElementSize,numVertexBytes,numElementBytes);
        else
            newBigDraw = new BigDrawable(name,singleVertexSize,vertexAttributes,singleElementSize,numVertexBytes,numElementBytes);
        newBigDraw->setProgram(shaderId);

        newBigDraw->setModes(draw);
        newBigDraw->setupGL(NULL, memManager);
        changes.push_back(new AddDrawableReq(newBigDraw));
        bigDrawables.insert(newBigDraw);
        represent.bigDrawId = newBigDraw->getId();
        if ((represent.elementChunkId = newBigDraw->addRegion(vertData, represent.vertexPos, elementData,enabled)) != EmptyIdentity)
        {
            represent.vertexSize = [vertData length];
            represent.bigDrawId = newBigDraw->getId();
            foundBigDraw = newBigDraw;
        }
    }
    
    // This drawable is probably too big.  Punt
    if (!foundBigDraw)
        return false;

    // This tracks the region by drawable ID so we can get to it later
    drawables.insert(represent);

    return true;
}

void DynamicDrawableAtlas::setEnableDrawable(SimpleIdentity drawId,bool enabled)
{
    // Look for the representation
    DrawRepresent represent(drawId);

    // Find it
    DrawRepresentSet::iterator it = drawables.find(represent);
    if (it == drawables.end())
        return;
    represent = *it;
    
    // Find the big drawable enable/disable it in there
    BigDrawable *bigDraw = NULL;
    BigDrawableSet::iterator bit;
    for (bit = bigDrawables.begin(); bit != bigDrawables.end(); ++bit)
    {
        if ((*bit)->getId() == represent.bigDrawId)
        {
            bigDraw = *bit;
            break;
        }
    }

    if (bigDraw)
        bigDraw->setEnableRegion(represent.elementChunkId,enabled);
}

bool DynamicDrawableAtlas::removeDrawable(SimpleIdentity drawId,ChangeSet &changes)
{
    // Look for the representation
    DrawRepresent represent(drawId);
    
    // Find it and remove it
    DrawRepresentSet::iterator it = drawables.find(represent);
    if (it == drawables.end())
        return false;
    represent = *it;
    drawables.erase(it);
    
    // Find the big drawable and remove it from that
    BigDrawable *bigDraw = NULL;
    BigDrawableSet::iterator bit;
    for (bit = bigDrawables.begin(); bit != bigDrawables.end(); ++bit)
    {
        if ((*bit)->getId() == represent.bigDrawId)
        {
            bigDraw = *bit;
            break;
        }
    }
    
    if (!bigDraw)
        return false;
    
    // Set up the requests to clear the region
    bigDraw->clearRegion(represent.vertexPos, represent.vertexSize, represent.elementChunkId);
    
    // And if there's nothing in that drawable, get rid of it
    if (bigDraw->empty())
    {
        changes.push_back(new RemDrawableReq(bigDraw->getId()));
        bigDrawables.erase(bit);
    }
    
    return true;
}
    
    
bool DynamicDrawableAtlas::hasUpdates()
{
    for (BigDrawableSet::iterator it = bigDrawables.begin(); it != bigDrawables.end(); ++it)
    {
        BigDrawable *bigDraw = *it;
        if (bigDraw->hasChanges())
            return true;
    }
    
    return false;
}
    
void DynamicDrawableAtlas::swap(ChangeSet &changes,NSObject * __weak target,SEL sel)
{
    BigDrawableSwap *swapRequest = new BigDrawableSwap(target,sel);
    changes.push_back(swapRequest);

    // Toss in the other changes we've been waiting on
    changes.insert(changes.end(), swapChanges.begin(), swapChanges.end());
    swapChanges.clear();
    
    // Note: We could keep a list of changed ones if these get to be more than a few
    for (BigDrawableSet::iterator it = bigDrawables.begin(); it != bigDrawables.end(); ++it)
    {
        BigDrawable *bigDraw = *it;
        bigDraw->swap(changes,swapRequest);
    }
}
    
bool DynamicDrawableAtlas::waitingOnSwap()
{
    for (BigDrawableSet::iterator it = bigDrawables.begin(); it != bigDrawables.end(); ++it)
        if ((*it)->isWaitingOnSwap())
            return true;
    
    return false;
}
    
void DynamicDrawableAtlas::addSwapChanges(const ChangeSet &inSwapChanges)
{
    swapChanges.insert(swapChanges.end(), inSwapChanges.begin(), inSwapChanges.end());
}
    
void DynamicDrawableAtlas::shutdown(ChangeSet &changes)
{
    for (BigDrawableSet::iterator it = bigDrawables.begin(); it != bigDrawables.end(); ++it)
        changes.push_back(new RemDrawableReq((*it)->getId()));
    
    bigDrawables.clear();
    drawables.clear();
}
    
void DynamicDrawableAtlas::log()
{
    NSLog(@"Drawable Atlas: Big Drawables: %ld (%ld MB)\tRepresented Drawables:%ld",bigDrawables.size(),bigDrawables.size()*(numVertexBytes+numElementBytes)/(1024*1024),
          drawables.size());
}
    
}
