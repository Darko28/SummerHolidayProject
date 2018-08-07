//
//  AMapViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/19.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit
import MapKit
import MAMapKit
import AMapSearchKit
import GoogleMaps


//enum Flow {
//    case createMarkerByLongPressAndShowDirection
//    case createMarkerByServerProvidedLocations
//}


class AMapViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var appleMap: MKMapView!
    @IBOutlet weak var googleMapCleanOutlet: UIBarButtonItem!
    
    let defaultZoomLabel: Float = 19.0
    let polylineStrokeWidth: CGFloat = 5.0
    
//    private var mapView: GMSMapView!
    private var amapView: MAMapView!
//    private var userLocationMarker: GMSMarker!
    private var userLocationAnnotation: MAAnnotationView!
//    private var polyline: GMSPolyline!
    private var maPolyline: MAPolyline!
//    private var dropLocationMarker: GMSMarker!
    private var dropLocationAnnotation = MAPointAnnotation()
    
    private var flow: Flow = .createMarkerByLongPressAndShowDirection
    private var paths: [[(Double, Double)]] = []
    var maPaths: [[(Double, Double)]] = []
    private var destination: (Double, Double) = (Double(), Double())
    var maDestination: (Double, Double) = (Double(), Double())
    
    var search: AMapSearchAPI!
    var startCoordinate: CLLocationCoordinate2D!
    var destinationCoordiante: CLLocationCoordinate2D!
    
    var naviRoute: MANaviRoute?
    var route: AMapRoute?
    var currentSearchType: AMapRoutePlanningType = AMapRoutePlanningType.Walk
    
    var customUserLocationView: MAAnnotationView!

    public static let sharedInstance: AMapViewController = {
        let instance = AMapViewController()
        return instance
    }()
    
    
    // MARK: View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        AMapServices.shared()?.apiKey = "99d78566e646d2c30d60635ebf9a04b8"
        
//        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
//        appDelegate.locationManager.delegate = self
        registerNotification()
        handleAMap()
        initSearch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
//        appDelegate.locationManager.startUpdatingLocation()
        reachabilityCheck()
        // handleAppleMap()
//        handleGoogleMap()
//        handleAMap()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.locationManager.stopUpdatingLocation()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func reachabilityCheck() {
        if !NetworkReachability.isInternetAvailable() {
            let alert = UIAlertController(title: "No Internet", message: "Please connect to Internet", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .default) { (button) in
                alert.dismiss(animated: true, completion: nil)
            }
            alert.addAction(okButton)
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func registerNotification() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            self?.reachabilityCheck()
        }
    }
    
    private func initSearch() {
        search = AMapSearchAPI()
        AMapServices.shared()?.enableHTTPS = true
        search.delegate = self
    }
        
    private func createRegion(coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.appleMap.setRegion(region, animated: true)
    }
    
    private func createAMapRegion(coordinate: CLLocationCoordinate2D) {
        let span = MACoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let region = MACoordinateRegion(center: coordinate, span: span)
        self.amapView.setRegion(region, animated: true)
    }
    
    private func createAnnotation(location: CLLocationCoordinate2D, title: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        annotation.title = title
        self.appleMap.addAnnotation(annotation)
    }
    
    // MARK: - Open AR view
    
    @IBAction func openARView(_ sender: UIBarButtonItem) {
        if let arVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ARAMapViewController") as? UINavigationController {
            if let vc = arVC.visibleViewController as? ARAMapViewController {
                vc.sectionCoordinates = maPaths
                vc.carLocation = maDestination
            }
            self.present(arVC, animated: true, completion: nil)
        }
    }
    
    private func handleAMap() {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if let userLocation = appDelegate.locationManager.location?.coordinate {
            print("Using user location")
            amapSetUp(location: userLocation)
        } else {
            print("userLocation is nil")
//            amapSetUp(location: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946))
        }
        
        if flow == .createMarkerByLongPressAndShowDirection {
            if amapView != nil {
                amapView.delegate = self
            }
            title = "Tap On Map"
        } else if flow == .createMarkerByServerProvidedLocations {
            
            if amapView != nil {
                amapView.delegate = self
            }
            let fromLocation = CLLocationCoordinate2D(latitude: GPXFile.nuistPath.first?.0 ?? 0, longitude: GPXFile.cherryHillPath.first?.1 ?? 0)
            let cabLocation = CLLocationCoordinate2D(latitude: GPXFile.nuistPath.last?.0 ?? 0, longitude: GPXFile.cherryHillPath.last?.1 ?? 0)
//            let _ = createMAAnnotation(location: fromLocation, mapView: amapView, annotationTitle: "From Location", subtitle: "")
//            let _ = createMAAnnotation(location: fromLocation, mapView: amapView, annotationTitle: "Cab Location", subtitle: "Waiting...")
            drawMAPath(map: amapView, pathArray: GPXFile.nuistPath)
        }
    }
    
    private func amapSetUp(location: CLLocationCoordinate2D) {
        
        amapView = MAMapView(frame: self.view.bounds)
        amapView.delegate = self
        amapView.showsUserLocation = true
        amapView.userTrackingMode = .followWithHeading
        amapView.isUserInteractionEnabled = true
        
//        let userHeading = MAUserLocationRepresentation()
//        userHeading.showsHeadingIndicator = true
//        userHeading.showsAccuracyRing = true
//
//        amapView.update(userHeading)
        
        amapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(amapView)
        createAMapRegion(coordinate: AMapCoordinateConvert(location, .GPS))
    }
    
    private func drawMAPath(map: MAMapView, pathArray: [(Double, Double)]) {
        
        var path: [CLLocationCoordinate2D] = []
        for each in pathArray {
            path.append(CLLocationCoordinate2D(latitude: each.0, longitude: each.1))
        }
        let polyline = MAPolyline(coordinates: &path, count: UInt(path.count))
        let polyOverlay = MAPolylineRenderer(polyline: polyline!)
        polyOverlay?.strokeColor = UIColor.green
        polyOverlay?.lineWidth = polylineStrokeWidth
    }
}


//extension AMapViewController: CLLocationManagerDelegate {
//
//    private func sameLocation(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Bool {
//        return location1.latitude == location2.latitude && location1.longitude == location2.longitude
//    }
//
//    // Getting a new heading
//    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        let rotation = newHeading.magneticHeading * Double.pi / 180.0
//        print("rotation: \(rotation)")
//    }
//
//    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
//        switch status {
//        case .notDetermined:
//            // If the status has not yet been determined, ask for authorization
//            manager.requestWhenInUseAuthorization()
//            break
//        case .authorizedWhenInUse:
//            // If authorized when in use
//            manager.startUpdatingLocation()
//            break
//        case .authorizedAlways:
//            // If always authorized
//            manager.startUpdatingLocation()
//            break
//        case .restricted:
//            // If restricted by e.g. parental controls. User can't enable Location Services
//            break
//        case .denied:
//            // If user denied your app access to Location Services, but can grant access from Settings.app
//            break
//        }
//    }
//}


extension AMapViewController: MAMapViewDelegate, AMapSearchDelegate {
    
    func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
        
        if !updatingLocation && self.customUserLocationView != nil {
            
            UIView.animate(withDuration: 0.1) {
                let degree = userLocation.heading.trueHeading - Double(self.amapView.rotationDegree)
                let radian = (degree * Double.pi) / 180.0
                self.customUserLocationView.transform = CGAffineTransform(rotationAngle: CGFloat(radian))
            }
        }
    }
    
    func mapView(_ mapView: MAMapView!, didLongPressedAt coordinate: CLLocationCoordinate2D) {
        
//        self.dropLocationAnnotation = createMAAnnotation(location: coordinate, mapView: self.amapView, annotationTitle: "Destination", subtitle: "", image: UIImage(named: "drop-pin"))
        self.dropLocationAnnotation.coordinate = coordinate
        self.dropLocationAnnotation.title = "Long Press"
        amapView.addAnnotation(dropLocationAnnotation)
        
        reachabilityCheck()
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        if let userLocation = appDelegate.locationManager.location?.coordinate {
            
            if NetworkReachability.isInternetAvailable() {
                
                fetchMARoute(source: AMapCoordinateConvert(userLocation, .GPS), destination: coordinate) { [weak self] (polyline) in
                    
//                    print("fetchRoute Completion called")
                    
//                    if let polyline = polyline as? MAPolylineRenderer {
//
//                        // Add user location
//                        var path1: [CLLocationCoordinate2D] = []
//                        var path2: [MAMapPoint]
//                        var wholePath: MAPolyline
//                        if let userLocation = self?.userLocationAnnotation.annotation.coordinate {
//                            path1.append(userLocation)
//                        }
//
//                        // add rest of the coordinates
//                        if let polylinePath = self!.maPolyline.points, self!.maPolyline.pointCount > 0 {
//                            for i in 0..<Int(self!.maPolyline.pointCount) {
////                                path2.append(polylinePath.advanced(by: Int(i)))
//                                let coordinate = MACoordinateForMapPoint(polylinePath[Int(i)])
//                                path1.append(coordinate)
//                            }
//                        }
//
//                        wholePath = MAPolyline(coordinates: &path1, count: UInt(path1.count))
//
//
//                        let updatedPolyline = MAPolylineRenderer(polyline: wholePath)
//                        updatedPolyline?.strokeColor = UIColor.blue
//                        updatedPolyline?.lineWidth = self?.polylineStrokeWidth ?? 5.0
//
//                        self?.maPolyline = updatedPolyline?.polyline
//                        self?.amapView.add(self?.maPolyline)
//
//                        // update path and destination
//                        self?.maDestination = (coordinate.latitude, coordinate.longitude)
//
//                        if let path = updatedPolyline?.polyline.points {
//
//                            var polylinePath: [(Double, Double)] = []
//                            for i in 0..<Int(updatedPolyline!.polyline.pointCount) {
//                                let point = path1[i]
//                                polylinePath.append((point.latitude, point.longitude))
//                            }
//
//                            print("Appending maPaths")
//                            self?.maPaths = []
//                            self?.maPaths.append(polylinePath)
//                        }
//
//                    }
                }
            }
        }
    }
    
    private func fetchMARoute(source: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, completionHandler: ((Any) -> ())?) {
        
        print("Fetch MARoute")
        self.startCoordinate = source
        self.destinationCoordiante = destination
//        self.startCoordinate = GCJ02_WGS84.gcj02ToWGS84(lat: source.latitude, lon: source.longitude)
//        self.destinationCoordiante = GCJ02_WGS84.gcj02ToWGS84(lat: destination.latitude, lon: destination.longitude)
        
        let request = AMapWalkingRouteSearchRequest()
        request.origin = AMapGeoPoint.location(withLatitude: CGFloat(source.latitude), longitude: CGFloat(source.longitude))
        request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), longitude: CGFloat(destination.longitude))
        
        search.aMapWalkingRouteSearch(request)
        
    }
    
    // MARK: - AMapSearchDelegate
    
    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        let nsErr: NSError? = error as NSError
        print("Error: \(error) - \(nsErr?.code)")
    }
    
    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        
        amapView.removeAnnotations(amapView.annotations)
        amapView.removeOverlays(amapView.overlays)
        
        self.route = nil
        if response.count > 0 {
            self.route = response.route
            presentCurrentWalkingCourse()
        }
    }
    
    // Show current routing plan
    private func presentCurrentWalkingCourse() {
        
        let start = AMapGeoPoint.location(withLatitude: CGFloat(startCoordinate.latitude), longitude: CGFloat(startCoordinate.longitude))
        let end = AMapGeoPoint.location(withLatitude: CGFloat(destinationCoordiante.latitude), longitude: CGFloat(destinationCoordiante.longitude))
        
        if currentSearchType == AMapRoutePlanningType.Bus || currentSearchType == .BusCrossCity {
            //            naviRoute = MANaviRoute(transit: route!.transits.first!, startPoint: start!, endPoint: end!)
        } else {
            
            print("Present current course")

            let type = MANaviAnnotationType(rawValue: currentSearchType.rawValue)
            naviRoute = MANaviRoute(for: route!.paths.first!, naviType: type!, showTraffic: true, startPoint: start!, endPoint: end!)
        }
        
        naviRoute!.addToMapView(mapView: amapView)
        
        amapView.showOverlays(naviRoute!.routePolylines, edgePadding: UIEdgeInsetsMake(20, 20, 20, 20), animated: true)
        
        let completionHandler = { [weak self] (route: MANaviRoute?) in
            
            print("fetchRoute Completion called")
            
            if let route = route {
                
                // Add user location
                var coord: [CLLocationCoordinate2D] = []
//                coord.append(AMapCoordinateConvert(self!.startCoordinate, .GPS))
                coord.append(self!.startCoordinate)
                
                // add rest of the coordinates
                coord = coord + (route.routePolylines.map({ (naviPolyline) -> CLLocationCoordinate2D in
                    return naviPolyline.coordinate
                }))
                
                self!.maDestination = ((GCJ02_WGS84.gcj02ToWGS84(lat: self!.destinationCoordiante.latitude, lon: self!.destinationCoordiante.longitude)).latitude, (GCJ02_WGS84.gcj02ToWGS84(lat: self!.destinationCoordiante.latitude, lon: self!.destinationCoordiante.longitude)).longitude)
                
                let path = MAPolyline(coordinates: &coord, count: UInt(coord.count))
                
                //                let pathRender = MAPolylineRenderer(polyline: path)
                //                pathRender?.strokeColor = UIColor.green
                //                pathRender?.lineWidth = self?.polylineStrokeWidth ?? 5.0
                
                self?.amapView.add(path!)
                
                var sectionCoordinates: [(Double, Double)] = []
                var transformCoordinates: [(Double, Double)] = []
                for i in 0..<Int(path!.pointCount) {
                    sectionCoordinates.append((coord[i].latitude, coord[i].longitude))
                    transformCoordinates.append(((GCJ02_WGS84.gcj02ToWGS84(lat: coord[i].latitude, lon: coord[i].longitude)).latitude, (GCJ02_WGS84.gcj02ToWGS84(lat: coord[i].latitude, lon: coord[i].longitude)).longitude))
                }
                
                self?.maPaths.append(transformCoordinates)
                print("\(self!.maPaths)")
                
                //                // Add user location
                //                var path1: [CLLocationCoordinate2D] = []
                //                var path2: [MAMapPoint]
                //                var wholePath: MAPolyline
                //                if let userLocation = self?.userLocationAnnotation.annotation.coordinate {
                //                    path1.append(userLocation)
                //                }
                //
                //                // add rest of the coordinates
                //                if let polylinePath = self!.maPolyline.points, self!.maPolyline.pointCount > 0 {
                //                    for i in 0..<Int(self!.maPolyline.pointCount) {
                //                        //                                path2.append(polylinePath.advanced(by: Int(i)))
                //                        let coordinate = MACoordinateForMapPoint(polylinePath[Int(i)])
                //                        path1.append(coordinate)
                //                    }
                //                }
                //
                //                wholePath = MAPolyline(coordinates: &path1, count: UInt(path1.count))
                //
                //
                //                let updatedPolyline = MAPolylineRenderer(polyline: wholePath)
                //                updatedPolyline?.strokeColor = UIColor.blue
                //                updatedPolyline?.lineWidth = self?.polylineStrokeWidth ?? 5.0
                //
                //                self?.maPolyline = updatedPolyline?.polyline
                //                self?.amapView.add(self?.maPolyline)
                //
                //                // update path and destination
                //                self?.maDestination = (coordinate.latitude, coordinate.longitude)
                //
                //                if let path = updatedPolyline?.polyline.points {
                //
                //                    var polylinePath: [(Double, Double)] = []
                //                    for i in 0..<Int(updatedPolyline!.polyline.pointCount) {
                //                        let point = path1[i]
                //                        polylinePath.append((point.latitude, point.longitude))
                //                    }
                //                    self?.maPaths = []
                //                    self?.maPaths.append(polylinePath)
                //                }
                
            }
        }
        
        completionHandler(naviRoute)
    }
    
    // MARK: - MAMapViewDelegate
    
    func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
        
        print("Render for overlay called")
        
        if (overlay.isEqual(amapView.userLocationAccuracyCircle)) {
            
            let circleRender = MACircleRenderer(circle: amapView.userLocationAccuracyCircle)
            circleRender?.lineWidth = 2.0
//            circleRender?.strokeColor = UIColor.lightGray
//            circleRender?.fillColor = UIColor.red.withAlphaComponent(0.3)
            return circleRender
        }
        
        if overlay.isKind(of: LineDashPolyline.self) {
            
            print("Render overlay for lineDash Polyline")
            
            let naviPolyline: LineDashPolyline = overlay as! LineDashPolyline
            let renderer: MAPolylineRenderer = MAPolylineRenderer(overlay: naviPolyline.polyline)
            renderer.lineWidth = 8.0
            renderer.strokeColor = UIColor.red
            renderer.lineDashType = MALineDashType.square
            
            return renderer
        }
        
        if overlay.isKind(of: MANaviPolyline.self) {
            
            let naviPolyline: MANaviPolyline = overlay as! MANaviPolyline
            let renderer: MAPolylineRenderer = MAPolylineRenderer(overlay: naviPolyline.polyline)
            renderer.lineWidth = 8.0
            
            if naviPolyline.type == MANaviAnnotationType.Walking {
                
                print("Render overlay for naviPolyline")
                renderer.strokeColor = naviRoute?.walkingColor
            } else {
                renderer.strokeColor = naviRoute?.routeColor
            }
            
            return renderer
        }
        
        if overlay.isKind(of: MAMultiPolyline.self) {
            
            print("Render overlay for multiPolyline")
            
            let renderer: MAMultiColoredPolylineRenderer = MAMultiColoredPolylineRenderer(multiPolyline: overlay as! MAMultiPolyline!)
            renderer.lineWidth = 8.0
            renderer.strokeColors = naviRoute?.multiPolylineColors
            
            return renderer
        }
        
        return nil
    }
    
    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        
        if annotation.isKind(of: MAUserLocation.self) {
            
            print("MAUserLocation")
            
            let pointReuseIdentifier = "userLocationStyleReuseIdentifier"
            var annotationView = amapView.dequeueReusableAnnotationView(withIdentifier: pointReuseIdentifier)
            
            if annotationView == nil {
                annotationView = MAAnnotationView(annotation: annotation, reuseIdentifier: pointReuseIdentifier)
            }
            
            annotationView!.image = UIImage(named: "userPosition")
            
            self.customUserLocationView = annotationView
            return annotationView!
        } else if annotation.isKind(of: MAPointAnnotation.self) {
            
            let pointReuseIdentifier = "pointReuseIdentifier"
            var annotationView: MAAnnotationView? = amapView.dequeueReusableAnnotationView(withIdentifier: pointReuseIdentifier)
            
            if annotationView == nil {
                annotationView = MAAnnotationView(annotation: annotationView?.annotation, reuseIdentifier: pointReuseIdentifier)
                annotationView!.canShowCallout = true
                annotationView!.isDraggable = false
            }
            
            annotationView!.image = nil
            
            if annotation.isKind(of: MANaviAnnotation.self) {
                
                let naviAnno = annotation as! MANaviAnnotation
                
                switch naviAnno.type! {
                case MANaviAnnotationType.Drive:
                    annotationView!.image = UIImage(named: "car")
                    break
                case MANaviAnnotationType.Riding:
                    annotationView!.image = UIImage(named: "ride")
                    break
                case MANaviAnnotationType.Walking:
                    annotationView!.image = UIImage(named: "man")
                    break
                case MANaviAnnotationType.Bus:
                    annotationView!.image = UIImage(named: "bus")
                    break
                }
            } else {
                if annotation.title == "start" {
                    annotationView!.image = UIImage(named: "startPoint")
                } else if annotation.title == "destination" {
                    annotationView!.image = UIImage(named: "endPoint")
                }
            }
            
            return annotationView!
        }
        
        return nil
    }
}
