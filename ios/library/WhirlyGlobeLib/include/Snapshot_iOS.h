/*
 *  SceneRenderereES_iOS.h
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 6/12/19.
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

#import <UIKit/UIKit.h>

/// Fill this in to get a view snapshot on the next draw
@protocol WhirlyKitSnapshot

/// Returns true if we really want a snapshot
- (bool)needSnapshot:(NSTimeInterval)now;

/// Return the render target to snapshot.  EmptyIdentity for the screen.
- (WhirlyKit::SimpleIdentity)renderTargetID;

/// If we just want a subset, this is it
- (CGRect)snapshotRect;

/// Called with the raw image data
- (void)snapshotData:(NSData *)data;

@end
