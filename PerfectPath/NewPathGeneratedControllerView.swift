//
//  NewPathGeneratedControllerView.swift
//  PerfectPath
//
//  Created by Kasey Clark on 3/2/17.
//  Copyright © 2017 PerfectPath. All rights reserved.
//

import UIKit
import MapKit
import Firebase
import WatchConnectivity
import Alamofire


class NewPathGeneratedControllerView: UIViewController, MKMapViewDelegate {
    
    var crimes = [Crime]()
    var crimesRef: FIRDatabaseReference!
    
    var pathInformation: [String : Any?] = [:]
    var waypoints = [MKMapItem]()
    let numWaypoints = 3
    var path : Path?
    var activityIndicator: UIActivityIndicatorView?
    var watchPath : WatchPath?
    var crimescore = 0;
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceLabel: UILabel!        
    @IBOutlet weak var guardianEnabledLabel: UILabel!
    
    //for watch communication
    var lastMessage: CFAbsoluteTime = 0
    
    //load view of route and metrics
    override func viewDidLoad() {
        
        super.viewDidLoad()
        setupFirebaseObservers()
        mapView.delegate = self
        addActivityIndicator()
        waypoints.append(MKMapItem(placemark: MKPlacemark(placemark: (path?.startingLocation)!)))
        self.getCrimeScore((path?.startingLocation)!)
        let prefferedDistanceMeters = path?.prefferedDistanceMeters
        let waypointDistance = prefferedDistanceMeters! / Double(numWaypoints+1)
        let initialBearing = Double(arc4random_uniform(360))
        findPath(index: 1, initialBearing: initialBearing, waypointDistance: waypointDistance)
        //addGuardianLabel()
    }
    
    func getCrimeScore(_ placemark: CLPlacemark) {
        if let lat = placemark.location?.coordinate.latitude, let long = placemark.location?.coordinate.longitude {

            let parameters: Parameters = [
                "lat":"\(String(describing: lat))",
                "lon":"\(String(describing: long))"
            ]
        
            let headers: HTTPHeaders = [
                "X-Mashape-Key": "00W4vnBdAmmshYx6BIm2EQD2ewMlp1QZSxTjsn0vykoMSjpAzc",
                "Accept" :"application/json"
            ]
        
            Alamofire.request("https://crimescore.p.mashape.com/crimescore?f=json",parameters: parameters, headers: headers).responseJSON { response in
                guard let responseJSON = response.result.value as? [String: Any] else {
                    print("Couldn't retreive crimescore")
                    return
                }
                //print("\(String(describing: responseJSON["score"]))")
                guard let scoreString = responseJSON["score"] as? String else {
                    print("Couldn't interprate score")
                    return
                }
                let score = Int(scoreString)
                //print("\(String(describing: score))")
                self.crimescore += score!
                //print("\(self.crimescore)")
                
            }
        }
    }
    
    func setupFirebaseObservers() {
        let firebaseRef = FIRDatabase.database().reference()
        crimesRef = firebaseRef.child("crimes")
        crimes.removeAll()
        
        crimesRef.observe(.childAdded, with: { (snapshot) in
            //print("childAdded")
            let addedCrime = Crime(snapshot: snapshot)
            //print(addedCrime.getSnapshotValue())
            self.crimes.insert(addedCrime, at: 0)
        })
    }

    @IBAction func didTapStartPath(_ sender: Any) {
        print("Entering didTapStartPath...")
        if WCSession.default().isReachable == true {
            print("Session is reachable on iOS")

            let requestValues = ["command" : "startPathNow","data" : "pathString" as Any]
            let session = WCSession.default()
            
            session.sendMessage(requestValues, replyHandler: { (reply) -> Void in
                print("sent command: " + String(describing: requestValues["command"]))
                print("sent data: " + String(describing: requestValues["data"]))
                print("rec command: " + String(describing: reply["command"]))
                print("rec data: " + String(describing: reply["data"]))
            }, errorHandler: { error in
                print("error: \(error)")
            })
        }
        
        
    }

    func findPath(index: Int, initialBearing: Double, waypointDistance: Double) {
        let lastMKPoint = waypoints[index-1]
        let lastCoords = lastMKPoint.placemark.coordinate
        let bearing = (initialBearing + (90 * (Double(index)-1))).truncatingRemainder(dividingBy: 360)
        let newCoords = locationWithBearing(bearing: bearing, distanceMeters: waypointDistance, origin: lastCoords)
        let newPoint = CLLocation(latitude: newCoords.latitude, longitude: newCoords.longitude)
        CLGeocoder().reverseGeocodeLocation(newPoint, completionHandler: {(placemarks: [CLPlacemark]?, error: Error?) -> Void in
            if let placemarks = placemarks {
                self.getCrimeScore(placemarks.last!)
                let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemarks.last!))
                
                self.waypoints.append(mapItem)
                //print("point resolved, signaling semaphore")
                //semaphore.signal()
                //print("point resolved, semaphore signaleds")
                if index < self.numWaypoints {
                    self.findPath(index: index + 1, initialBearing: initialBearing, waypointDistance: waypointDistance)
                } else {
                    self.calculateSegmentDirections(index: 0, time: 0, routes: [])
                }
            } else if let _ = error {
                print("Error: \(error)")
            }
        })
    }
    
    func calculateSegmentDirections(index: Int, time: TimeInterval, routes: [MKRoute]) {
        let request: MKDirectionsRequest = MKDirectionsRequest()
        if index < waypoints.count-1 {
            request.source = waypoints[index]
            request.destination = waypoints[index + 1]
            request.transportType = .walking
        } else {
            request.source = waypoints[index]
            request.destination = waypoints[0]
            request.transportType = .walking
        }
        let directions = MKDirections(request: request)
        directions.calculate(completionHandler: {(response: MKDirectionsResponse?, error: Error?) in
            if let routeResponse = response?.routes {
                let routeForSegment: MKRoute = routeResponse.sorted(by: {$0.expectedTravelTime < $1.expectedTravelTime})[0]
                var timeVar = time
                var routeVar = routes
                routeVar.append(routeForSegment)
                timeVar += routeForSegment.expectedTravelTime
                if index + 1 < self.waypoints.count {
                    self.calculateSegmentDirections(index: index+1, time: timeVar, routes: routeVar)
                } else {
                    self.hideActivityIndicator()
                    //print(self.crimescore)
                    self.crimescore = self.crimescore/4
                    //print(self.crimescore)
                    self.addGuardianLabel()
                    self.path?.routes = routeVar
                    self.path?.mapItemWaypoints = self.waypoints
                    self.showRoute(routes: routeVar)
                    var distance = 0.0
                    for i in 0..<routes.count {
                        let temp = routeVar[i]
                        distance += temp.distance
                    }
                    distance = distance/1609.34
                    self.path?.actualDistance = distance
                    let distString = String(format: "%.1f",distance)
                    self.distanceLabel.text = "Distance: \(distString) mi"
                }
            } else if let _ = error {
                let alert = UIAlertController(title: nil, message: "Directions not available.", preferredStyle: .alert)
                let okButton = UIAlertAction(title: "OK", style: .cancel) {(alert) -> Void in
                    self.navigationController?.popViewController(animated: true)
                }
                alert.addAction(okButton)
                self.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    func showRoute(routes: [MKRoute]) {
        for i in 0..<routes.count {
            plotPolyline(route: routes[i])
        }
        createAnnotations()
    }
    
    //TODO pull actual crime locations, types, and time
    func createAnnotations() {
        
        for crime in crimes {
            let annotation: MKPointAnnotation = MKPointAnnotation()
            let culcCoordinates: CLLocationCoordinate2D = CLLocationCoordinate2DMake(crime.y_coord as CLLocationDegrees, crime.x_coord as CLLocationDegrees)
            annotation.coordinate = culcCoordinates
            annotation.title = crime.crimetype+"-"+crime.dateof
            annotation.subtitle = crime.shift+"-"+crime.location
            self.mapView.addAnnotation(annotation)
        }
    }
    
    func plotPolyline(route: MKRoute) {
        mapView.add(route.polyline)
        if mapView.overlays.count == 1 {
            mapView.setVisibleMapRect(route.polyline.boundingMapRect,
                                      edgePadding: UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0), animated: false)
        } else {
            let polylinesBoundingRect = MKMapRectUnion(mapView.visibleMapRect, route.polyline.boundingMapRect)
            mapView.setVisibleMapRect(polylinesBoundingRect, edgePadding: UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0), animated: false)
        }
    }
    
    func locationWithBearing(bearing: Double, distanceMeters:Double, origin: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let distRadians = distanceMeters / (6372797.6) //earth radius in meters
        let lat1 = origin.latitude * M_PI / 180
        let lon1 = origin.longitude * M_PI / 180
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180 / M_PI, longitude: lon2 * 180 / M_PI)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blue
            polylineRenderer.lineWidth = 4
            polylineRenderer.lineDashPattern = [5, 10, 5, 10]
            return polylineRenderer
        }
        return nil
    }
    
    @IBAction func generateNewPath() {
        waypoints.removeAll()
        mapView.removeOverlays(mapView.overlays)
        addActivityIndicator()
        waypoints.append(MKMapItem(placemark: MKPlacemark(placemark: (path?.startingLocation)! as! CLPlacemark)))
        let prefferedDistanceMeters = path?.prefferedDistanceMeters
        let waypointDistance = prefferedDistanceMeters! / Double(numWaypoints+1)
        let initialBearing = Double(arc4random_uniform(360))
        crimescore = 0;
        getCrimeScore((path?.startingLocation)!)
        findPath(index: 1, initialBearing: initialBearing, waypointDistance: waypointDistance)
    }
    
    func addActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(frame: UIScreen.main.bounds)
        activityIndicator?.activityIndicatorViewStyle = .whiteLarge
        activityIndicator?.backgroundColor = UIColor.darkGray
        activityIndicator?.startAnimating()
        view.addSubview(activityIndicator!)
    }
    
    func hideActivityIndicator() {
        if activityIndicator != nil {
            activityIndicator?.removeFromSuperview()
            activityIndicator = nil
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destViewController : PathNavigationViewController = segue.destination as! PathNavigationViewController
        //destViewController.pathInformation = pathInformation
        destViewController.path = path
    }
    
    func addGuardianLabel() {
        if (path?.guardianPathEnabled)! {
            guardianEnabledLabel.text = "Guardian SafeScore: \(crimescore)"
        } else {
            guardianEnabledLabel.text = "Guardian Enabled: No"
        }
    }
    
    
}



