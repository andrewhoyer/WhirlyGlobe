/*
 *  VectorObject
 *  com.mousebirdconsulting.maply
 *
 *  Created by Steve Gifford on 12/30/13.
 *  Copyright 2013 mousebird consulting
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

package com.mousebirdconsulting.maply;

import java.util.Map;

/**
 * The Maply VectorObject represents a group of vector features.  There can be a single point in here,
 * multiple points, or even a combination of points, areals, and linears.
 * <p>
 * You can create these yourself, but they are typically read from data files, such as GeoJSON or
 * Shapefiles.
 * <p>
 * The VectorObject is meant to be somewhat opaque (but not as opaque as originally planned).  If you
 * need to do a lot of manipulation of your vector data, it's best ot do it elsewhere and then convert
 * to a VectorObject.
 * 
 * @author sjg
 *
 */
public class VectorObject implements Iterable<VectorObject>
{
	/**
	 * Construct empty.
	 */
	public VectorObject()
	{
		initialise();
	}
	
	/**
	 * Return attributes for the feature.  If there are multiple features, we get the first one.
	 */
	public native AttrDictionary getAttributes();
	
	/**
	 * Add a single point
	 */
	public native void addPoint(Point2d pt);

	/**
	 *  Add a linear feature
	 */
	public native void addLinear(Point2d pts[]);
	
	/**
	 *  Add an areal feature with one external loop.
	 */
	public native void addAreal(Point2d pts[]);
//	public native void addAreal(Point2d ext[],Point2d holes[][]);
	
	public void finalize()
	{
		dispose();
	}
	
	/**
	 * Vector objects can be made of lots of smaller objects.  If you need to access
	 * each of this individually, this iterator will handle that efficiently.
	 */
	@Override
	public VectorIterator iterator() 
	{
		return new VectorIterator(this);
	}	
	
	/**
	 * Load vector objects from a GeoJSON string.
	 * @param json The GeoSJON string, presumably read from a file or over the network
	 * @return false if we were unable to parse the GeoJSON
	 */
	public native boolean fromGeoJSON(String json);
	
	/**
	 * Load vector objects from a GeoJSON assembly, which is just a bunch of GeoJSON stuck together.
	 * @param json
	 * @return
	 */
	static public native Map<String,VectorObject> FromGeoJSONAssembly(String json);
	
	/**
	 * Read vector objects from a binary file.  This is fairly efficient and a good way to
	 * cache data.
	 * @param fileName The file to read vector data from.
	 * @return true on success, false otherwise.
	 */
	public native boolean readFromFile(String fileName);
	
	/**
	 * Write a vector object to a binary file.  This is fairly efficient for caching data,
	 * but not to be used for much else.
	 * @param fileName The file to write data to.
	 * @return true on success, false otherwise.
	 */
	public native boolean writeToFile(String fileName);
		
	static
	{
		nativeInit();
	}
	private static native void nativeInit();
	native void initialise();
	native void dispose();

	private long nativeHandle;
}