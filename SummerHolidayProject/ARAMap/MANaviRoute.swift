//
//  MANaviRoute.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/26.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import MAMapKit
import AMapSearchKit


let kMANaviRouteReplenishPolylineFilter = 5.0


enum MANaviAnnotationType: Int {
    case Drive = 0
    case Walking = 1
    case Bus = 2
    case Riding = 3
}

enum AMapRoutePlanningType: Int {
    case Drive = 0
    case Walk
    case Bus
    case BusCrossCity
    case Riding
    case Truck
}

class MANaviRoute: NSObject {
    
    var annotationVisible: Bool // Invalid if showing traffic is true
//    static var routePolylines: [MANaviPolyline] {
//        get {
//            return self.routePolylines
//        }
//        set {
//            self.routePolylines = newValue
//        }
//    }
//    static var naviAnnotations: [MANaviAnnotation] {
//        get {
//            return self.naviAnnotations
//        }
//        set {
//            self.naviAnnotations = newValue
//        }
//    }
    
    var routePolylines: [MANaviPolyline] = []
    var naviAnnotations: [MANaviAnnotation] = []
    
    var routeColor: UIColor
    var walkingColor: UIColor
    var multiPolylineColors: [UIColor] = []
    
    var mapView: MAMapView!
    var trafficColors: [[UIColor]]
    
    var polylines: [MAPolyline] = []
    
    
    override init() {
//        super.init()
        
        self.annotationVisible = true
        self.routeColor = UIColor.blue
        self.walkingColor = UIColor.cyan
        self.trafficColors = [[UIColor.green], [UIColor.green], [UIColor.yellow], [UIColor.red]]
        super.init()
    }
    
//    init(transit: AMapTransit, startPoint start: AMapGeoPoint, endPoint end: AMapGeoPoint) {
//
//    }
    
    convenience init(for path: AMapPath, naviType type: MANaviAnnotationType, showTraffic: Bool, startPoint start: AMapGeoPoint, endPoint end: AMapGeoPoint) {
        
        self.init()
        
        print("init for path called")
        
        //        var polylines: [MAPolyline] = []
        var naviAnnotations: [MANaviAnnotation] = []
        
        if (showTraffic && (type == MANaviAnnotationType.Drive)) {
            print("type == .Drive")
        } else {
            
            for i in 0..<path.steps.count {
                
                let step = path.steps[i]
                let stepPolyline: MAPolyline? = polylineForStep(step: step)
                
                if (stepPolyline != nil) {
                    
                    print("init for path")
                    let naviPolyline: MANaviPolyline = MANaviPolyline(polyline: stepPolyline!)
                    naviPolyline.type = type
                    
                    polylines.append(naviPolyline.polyline)
                    
                    if (i > 0) {
                        let annotation: MANaviAnnotation = MANaviAnnotation()
                        annotation.coordinate = MACoordinateForMapPoint(stepPolyline!.points[0])
                        annotation.type = type
                        annotation.title = step.instruction
                        naviAnnotations.append(annotation)
                    }
                    
                    if i > 0 {
                        // fullfill the space between step and step
                        replenishPolylinesForPathWith(stepPolyline: stepPolyline!, lastPolyline: polylineForStep(step: path.steps[i-1])!, polylines: (polylines as! [LineDashPolyline]))
                    }
                }
            }
        }
        
        replenishPolylinesForStartPoint(start: start, endPoint: end, polylines: polylines.map { (polyline) -> MANaviPolyline in
            MANaviPolyline(polyline: polyline)
        })
        
        self.routePolylines = polylines.map { (polyline) -> MANaviPolyline in
            MANaviPolyline(polyline: polyline)
        }
        self.naviAnnotations = naviAnnotations
    }

//    init(polylines: [MAPolyline], andAnnotations annotations: [MAAnnotation]) {
//
//    }
    
    func polylineForStep(step: AMapStep?) -> MAPolyline? {
        
        print("polyline for step")
        
        if step == nil {
            return nil
        }
        
        return MANaviRoute.polylineForCoordinateString(coodinateString: step!.polyline)
    }
    
    class func polylineForCoordinateString(coodinateString: String) -> MAPolyline? {
        
        print("polyline for coordinate string")
        
        if coodinateString.count == 0 {
            return nil
        }
        
        // Wrong implementation     Needs `inout` keyword argument
        var count: Int? = 0
        var coordinates: [CLLocationCoordinate2D] = self.coordinatesForString(string: coodinateString, coordinateCount: &count, parseToken: ";")!
        
        let polyline: MAPolyline = MAPolyline(coordinates: &coordinates, count: UInt(count!))
        
        return polyline
    }
    
    class func coordinatesForString(string: String?, coordinateCount: inout Int?, parseToken token: String?) -> [CLLocationCoordinate2D]? {
        
        if string == nil {
            return nil
        }
        
        var token = token
        if token == nil {
            token = ","
        }
        
        var str = ""
        
        if !(token! == ",") {
            str = string!.replacingOccurrences(of: token!, with: ",")
        } else {
            str = string!
        }
        
        var components = str.components(separatedBy: ",")
        let count = Int(components.count / 2)
        if coordinateCount != nil {
            coordinateCount = count
        }
        
        var coordinates: [CLLocationCoordinate2D] = Array(repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0), count: count)
        
        for i in 0..<count {
            coordinates[i].longitude = Double(components[2*i])!
            coordinates[i].latitude = Double(components[2*i+1])!
        }
        
        return coordinates
    }
    
//    class func naviRouteForPath(path: AMapPath, withNaviType type: MANaviAnnotationType, showTraffic: Bool, startPoint start: AMapGeoPoint, endPoint end: AMapGeoPoint) {
//
//        var polylines: [MAPolyline] = []
//        var naviAnnotations: [MANaviAnnotation] = []
//
//        if (showTraffic && (type == MANaviAnnotationType.Drive)) {
//
//        } else {
//
//            for i in 0..<path.steps.count {
//
//                var step = path.steps[i]
//                var stepPolyline: MAPolyline? = MANaviRoute.polylineForStep(step: step)
//
//                if (stepPolyline != nil) {
//                    var naviPolyline: MANaviPolyline = MANaviPolyline(polyline: stepPolyline!)
//                    naviPolyline.type = type
//
//                    polylines.append(naviPolyline)
//
//                    if (i > 0) {
//                        var annotation: MANaviAnnotation = MANaviAnnotation()
//                        annotation.coordinate = MACoordinateForMapPoint(stepPolyline!.points[0])
//                        annotation.type = type
//                        annotation.title = step.instruction
//                        naviAnnotations.append(annotation)
//                    }
//
//                    if i > 0 {
//                        // fullfill the space between step and step
//                        MANaviRoute.replenishPolylinesForPathWith(stepPolyline: stepPolyline!, lastPolyline: MANaviRoute.polylineForStep(step: path.steps[i-1])!, polylines: (polylines as! [LineDashPolyline]))
//                    }
//                }
//            }
//        }
//
//        MANaviRoute.replenishPolylinesForStartPoint(start: start, endPoint: end, polylines: &(polylines as! [MANaviPolyline]))
//
//        self.routePolylines = polylines as! [MANaviPolyline]
//        self.naviAnnotations = naviAnnotations
//    }
    
    /// replenish the space between the start point and the end point
    func replenishPolylinesForStartPoint(start: AMapGeoPoint?, endPoint end: AMapGeoPoint?, polylines: [MANaviPolyline]) {
        
        if polylines.count < 1 {
            return
        }
        
        var startDashPolyline: LineDashPolyline?
        var endDashPolyline: LineDashPolyline?
        
        if start != nil {
            
            let startCoord1 = CLLocationCoordinate2DMake(CLLocationDegrees(start!.latitude), CLLocationDegrees(start!.longitude))
            var endCoord1 = startCoord1
            
            let naviPolyline = polylines.first
            var polyline: MAPolyline?
            
            if naviPolyline!.isKind(of: MANaviPolyline.self) {
                polyline = naviPolyline!.polyline
            } else if naviPolyline!.isKind(of: MAPolyline.self) {
                polyline = naviPolyline!.polyline
            }
            
            if polyline != nil {
                polyline?.getCoordinates(&endCoord1, range: NSMakeRange(0, 1))
                startDashPolyline = self.replenishPolylineWithStart(startCoord: startCoord1, end: endCoord1)
            }
        }
        
        if end != nil {
            
            var startCoord2: CLLocationCoordinate2D = CLLocationCoordinate2D()
            var endCoord2: CLLocationCoordinate2D = CLLocationCoordinate2D()
            
            let naviPolyline = polylines.last
            var polyline: MAPolyline?
            
            if naviPolyline!.isKind(of: MANaviPolyline.self) {
                polyline = naviPolyline!.polyline
            } else if naviPolyline!.isKind(of: MAPolyline.self) {
                polyline = naviPolyline!.polyline
            }
            
            if polyline != nil {
                polyline?.getCoordinates(&startCoord2, range: NSMakeRange(Int(polyline!.pointCount) - 1, 1))
                endCoord2 = CLLocationCoordinate2DMake(Double(end!.latitude), Double(end!.longitude))
                
                endDashPolyline = self.replenishPolylineWithStart(startCoord: startCoord2, end: endCoord2)
            }
        }
        
        if startDashPolyline != nil {
            self.polylines.append(startDashPolyline!.polyline)
        }
        if endDashPolyline != nil {
            self.polylines.append(endDashPolyline!.polyline)
        }
    }
    
    func replenishPolylineWithStart(startCoord: CLLocationCoordinate2D, end endCoord: CLLocationCoordinate2D) -> LineDashPolyline? {
        
        if (!CLLocationCoordinate2DIsValid(startCoord) || !CLLocationCoordinate2DIsValid(endCoord)) {
            return nil
        }
        
        let distance: Double = MAMetersBetweenMapPoints(MAMapPointForCoordinate(startCoord), MAMapPointForCoordinate(endCoord))
        
        var dashPolyline: LineDashPolyline?
        
        // Filter beforehand, if the distance is small then do not need to add dash line
        if distance > kMANaviRouteReplenishPolylineFilter {
            
            var points: [CLLocationCoordinate2D] = []
//            points[0] = startCoord
//            points[1] = endCoord
            points.append(startCoord)
            points.append(endCoord)
            
            let polyline: MAPolyline = MAPolyline(coordinates: &points, count: 2)
            dashPolyline = LineDashPolyline(polyline: polyline)
        }
        
        return dashPolyline
    }
    
    func replenishPolylinesForPathWith(stepPolyline: MAPolyline, lastPolyline: MAPolyline, polylines: [LineDashPolyline]) {
        
        var startCoord: CLLocationCoordinate2D = CLLocationCoordinate2D()
        var endCoord: CLLocationCoordinate2D = CLLocationCoordinate2D()
        
        stepPolyline.getCoordinates(&endCoord, range: NSMakeRange(0, 1))
        lastPolyline.getCoordinates(&startCoord, range: NSMakeRange(Int(lastPolyline.pointCount) - 1, 1))
        
        if (endCoord.latitude != startCoord.latitude || endCoord.longitude != startCoord.longitude) {
            
            let dashPolyline: LineDashPolyline? = self.replenishPolylineWithStart(startCoord: startCoord, end: endCoord)
            if dashPolyline != nil {
                self.polylines.append(dashPolyline!.polyline)
            }
        }
    }
    
    class func naviRouteForTransit(transit: AMapTransit, startPoint start: AMapGeoPoint, endPoint end: AMapGeoPoint) {
        
    }
    
    class func naviRouteForPolylines(polylines: [MAPolyline], andAnnotations annotation: [MAAnnotation]) {
        
    }
    
    public func addToMapView(mapView: MAMapView) {
        
        self.mapView = mapView
        
        if self.routePolylines.count > 0 {
            
            print("Adding overlays to mapView")
            
//            mapView.addOverlays(self.routePolylines.map { (polyline) -> MAPolyline in
//                polyline.polyline
//            })
            
            mapView.addOverlays(self.routePolylines)

        }
        
        if (self.annotationVisible && self.naviAnnotations.count > 0) {
            mapView.addAnnotations(self.naviAnnotations)
        }
    }
    
    private func removeFromMapView() {
        
        if self.mapView == nil {
            return
        }
        
        if self.routePolylines.count > 0 {
            self.mapView.removeOverlays(self.routePolylines)
        }
        
        if self.annotationVisible && self.naviAnnotations.count > 0 {
            self.mapView.removeAnnotations(self.naviAnnotations)
        }
        
        self.mapView = nil
    }
    
    private func setNaviAnnotationVisibility(visible: Bool) {
        
    }
}
