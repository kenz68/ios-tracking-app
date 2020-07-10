import UIKit
import MapKit

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    var locations: [CLLocation] = []
    var backgroundLocations: [CLLocation] = []

    var logger = LocationLogger()
    var currentPolyline: MKPolyline?
    var currentBackgroundPolyline: MKPolyline?

    var circles: [MKCircle] = []
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var localizeMeButton: LocalizeMeButton!
    
    lazy var localizeMeManager: TrackingHeadingLocationManager = {
       return TrackingHeadingLocationManager()
    }()
    
    override func viewDidLoad() {
        mapView.delegate = self
        super.viewDidLoad()
        
        BackgroundDebug().print()
        
        setUpLocalizeMeButton()
    }
    
    @IBAction func start(_ sender: Any) {
        startTracking()
    }
    
    var appDelagete = {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    @IBAction func stop(_ sender: Any) {
        appDelagete().locationManager.stop()
        appDelagete().backgroundLocationManager.stop()
        statusLabel.text = "stop"
    }
    
    @IBAction func clear(_ sender: Any) {
        if let polyline = currentPolyline {
            mapView.removeOverlay(polyline)
        }
        if let polyline = currentBackgroundPolyline {
            mapView.removeOverlay(polyline)
        }
    }
    
    
    @IBAction func readLog(_ sender: Any) {
        if let locations = logger.readLocation() {
            drawLocation(locations: locations)
            mapView.centerCamera(to: locations.last)
        }
        
        if let locationString = logger.getLog() {
            let alertVC = UIAlertController(title: "Logs", message: locationString, preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alertVC.addAction(ok)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    @IBAction func clearLog(_ sender: Any) {
        logger.removeLogFile()
    }
    
    
    func startTracking() {
        statusLabel.text = "start tracking location"
        drawRegions()
        appDelagete().backgroundLocationManager.start() { [unowned self] result in
            if case let .Success(location) = result {
                self.updateBackgroundLocation(location: location)
            }
        }
        
        appDelagete().locationManager.manager(for: .always, completion: { result in
            if case let .Success(manager) = result {
                manager.startUpdatingLocation(isHeadingEnabled: true) { [weak self] result in
                    if case let .Success(locationHeading) = result, let location = locationHeading.location {
                        self?.updateLocation(location: location)
                    }
                }
            }
        })
        
    }

    
    
    private func updateBackgroundLocation(location: CLLocation) {
        print("updateBackgroundLocation:\(location.debugDescription)")
        statusLabel.text = "update background location: \(location.debugDescription)"
        backgroundLocations.append(location)
        
        if let polyline = currentBackgroundPolyline {
            mapView.removeOverlay(polyline)
        }
        
        currentBackgroundPolyline = ViewController.polyline(locations: backgroundLocations, title: "regions")
        mapView.addOverlay(currentBackgroundPolyline!)
        
        logger.writeLocationToFile(location: location)
        
    }
    
    private func updateLocation(location: CLLocation) {
        print("update Location:\(location.debugDescription)")
        statusLabel.text = "update location: \(location.debugDescription)"
        locations.append(location)
        
        if let polyline = currentPolyline {
            mapView.removeOverlay(polyline)
        }

        drawLocation(locations: locations)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.statusLabel.text = "traking..."
        }
    }
    
    func drawLocation(locations: [CLLocation]) {
        currentPolyline = ViewController.polyline(locations: locations, title: "location")
        mapView.addOverlay(currentPolyline!)
    }
    
    
    static func polyline(locations: [CLLocation], title:String) -> MKPolyline {
        var coords = [CLLocationCoordinate2D]()
        
        for location in locations {
            coords.append(CLLocationCoordinate2D(latitude: location.coordinate.latitude,
                                                 longitude: location.coordinate.longitude))
        }
        
        let polyline = MKPolyline(coordinates: &coords, count: locations.count)
        polyline.title = title
        
        return polyline
    }
    
    func drawRegions() {
        appDelagete().backgroundLocationManager.addedRegionsListener = { result in
            
            if case let .Success(locations) = result {
                
                self.circles.forEach({ circle in
                    self.mapView.removeOverlay(circle)
                })
                
                locations.forEach({ location in
                    let circle = MKCircle(center: location.coordinate, radius: self.appDelagete().backgroundLocationManager.regionConfig.regionRadius)
                    circle.title = "regionPlanned"
                    self.mapView.addOverlay(circle)
                    self.circles.append(circle)
                })
                
                
            }
        }

    }

}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            let isRegion = circle.title ?? "" == "regionPlanned"
            renderer.fillColor = isRegion ? UIColor.blue.withAlphaComponent(0.2) : UIColor.red.withAlphaComponent(0.2)
            return renderer
        }
        
        
        let isRegion = overlay.title ?? "" == "regions"
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = isRegion ? UIColor.red.withAlphaComponent(0.8) : UIColor.blue.withAlphaComponent(0.8)
        renderer.lineWidth = isRegion ? 8.0 : 2.0
        
        return renderer
    }
    

}



